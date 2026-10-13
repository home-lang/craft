import CoreLocation
import Foundation
import HealthKit

/// A HealthKit read or write that did not happen: the message a page sees,
/// and the bridge's error code.
struct CraftHealthError: Error {
    let message: String
    var code: String = "CRAFT_ERROR"
}

/// Apple Health for the whole app: the web page's bridge (`craft.health` in
/// the hybrid's web view, CraftApp.swift) and native screens alike
/// (`Health` through CraftNativeActions), so a screen drawn natively reads
/// and writes Apple Health exactly as a page does. One HKHealthStore for the
/// process, as Apple asks. Every answer arrives through `completion`, on
/// whatever queue HealthKit answered on; each caller hops to its own.
final class CraftHealth {
    typealias Completion = (Result<Any, CraftHealthError>) -> Void

    static let shared = CraftHealth()

    /// Nil where Apple Health is not on this device (an iPad without it).
    let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil

    /// A native screen's call (`Health` in CraftNativeActions), by method and arguments as the bridge sends them.
    func perform(method: String, args: [Any], completion: @escaping Completion) {
        let options = { (index: Int) in args.count > index ? args[index] as? [String: Any] ?? [:] : [:] }
        switch method {
        case "requestAuthorization":
            requestAuthorization(types: args.first as? [String] ?? [], readOnly: options(1)["write"] as? Bool == false || options(1)["readOnly"] as? Bool == true, completion: completion)
        case "getData":
            guard let type = args.first as? String else { return completion(.failure(CraftHealthError(message: "getData needs a type", code: "INVALID_ARGUMENT"))) }
            getData(type: type, startDate: options(1)["startDate"] as? Double, endDate: options(1)["endDate"] as? Double, completion: completion)
        case "saveWorkout":
            saveWorkout(body: options(0), completion: completion)
        case "getWorkouts":
            getWorkouts(startDate: options(0)["startDate"] as? Double, endDate: options(0)["endDate"] as? Double, limit: options(0)["limit"] as? Int, completion: completion)
        case "getDailyStatistics":
            guard let type = args.first as? String else { return completion(.failure(CraftHealthError(message: "getDailyStatistics needs a type", code: "INVALID_ARGUMENT"))) }
            getDailyStatistics(type: type, startDate: options(1)["startDate"] as? Double, endDate: options(1)["endDate"] as? Double, completion: completion)
        case "getHeartRateSamples":
            getHeartRateSamples(startDate: options(0)["startDate"] as? Double, endDate: options(0)["endDate"] as? Double, limit: options(0)["limit"] as? Int, completion: completion)
        case "getSleepIntervals":
            getSleepIntervals(startDate: options(0)["startDate"] as? Double, endDate: options(0)["endDate"] as? Double, completion: completion)
        default:
            completion(.failure(CraftHealthError(message: "Unsupported Health method", code: "UNKNOWN_ACTION")))
        }
    }

    func requestAuthorization(types: [String], readOnly: Bool = false, completion: @escaping Completion) {
        guard let healthStore = healthStore else {
            completion(.failure(CraftHealthError(message: "HealthKit not available")))
            return
        }

        var readTypes: Set<HKObjectType> = []
        var shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let routeType = HKSeriesType.workoutRoute() as? HKSampleType {
            shareTypes.insert(routeType)
        }

        for type in types {
            switch type {
            case "steps":
                if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
                    readTypes.insert(stepType)
                }
            case "heartRate":
                if let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                    readTypes.insert(heartType)
                }
            case "activeEnergy":
                if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                    readTypes.insert(energyType)
                    shareTypes.insert(energyType)
                }
            case "distance":
                if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                    readTypes.insert(distanceType)
                    shareTypes.insert(distanceType)
                }
            case "workouts":
                readTypes.insert(HKObjectType.workoutType())
                // A workout's own heart rate and energy are read through
                // these; without them every workout comes back bare.
                if let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                    readTypes.insert(heartType)
                }
                if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                    readTypes.insert(energyType)
                }
            case "restingHeartRate":
                if let restingType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
                    readTypes.insert(restingType)
                }
            case "heartRateVariability":
                if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
                    readTypes.insert(hrvType)
                }
            case "bodyMass":
                if let massType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
                    readTypes.insert(massType)
                }
            case "sleep":
                if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
                    readTypes.insert(sleepType)
                }
            case "dietaryEnergy", "dietaryProtein", "dietaryCarbohydrates", "dietaryFat":
                // What a food log (MyFitnessPal, Lose It!, Cronometer...)
                // writes to Apple Health: read only, never written back.
                if let dietaryType = Self.healthQuantity(type)?.type {
                    readTypes.insert(dietaryType)
                }
            default:
                break
            }
        }

        // A page that only reads asks only to read: the sheet then says
        // "access", not "access and update".
        if readOnly { shareTypes.removeAll() }
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] success, error in
            if success {
                completion(.success(true))
            } else {
                completion(.failure(CraftHealthError(message: error?.localizedDescription ?? "Authorization failed")))
            }
        }
    }

    func getData(type: String, startDate: Double?, endDate: Double?, completion: @escaping Completion) {
        guard let healthStore = healthStore else {
            completion(.failure(CraftHealthError(message: "HealthKit not available")))
            return
        }

        guard let spec = Self.healthQuantity(type), let qType = spec.type else {
            completion(.failure(CraftHealthError(message: "Unknown health data type")))
            return
        }
        let qUnit = spec.unit

        let start = startDate != nil ? Date(timeIntervalSince1970: startDate! / 1000) : Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let end = endDate != nil ? Date(timeIntervalSince1970: endDate! / 1000) : Date()

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        // A discrete type (heart rate, weight) has no sum: HealthKit fails
        // the whole query when asked for one, which is what heart rate
        // used to do. Each type is asked for the statistic it has.
        let query = HKStatisticsQuery(quantityType: qType, quantitySamplePredicate: predicate, options: spec.options) { [weak self] _, result, error in
            if let error = error {
                // No samples in the range is an answer, not a failure.
                if (error as? HKError)?.code == .errorNoData {
                    completion(.success(["value": 0, "unit": qUnit.unitString]))
                    return
                }
                completion(.failure(CraftHealthError(message: error.localizedDescription)))
                return
            }

            let value = result.flatMap { Self.statisticValue($0, options: spec.options, unit: qUnit) } ?? 0
            completion(.success(["value": value, "unit": qUnit.unitString]))
        }

        healthStore.execute(query)
    }

    func saveWorkout(body: [String: Any], completion: @escaping Completion) {
        guard let healthStore = healthStore else {
            completion(.failure(CraftHealthError(message: "HealthKit not available")))
            return
        }
        guard let activityId = body["activityId"] as? String,
              let type = body["type"] as? String,
              let startValue = body["startDate"] as? Double,
              let endValue = body["endDate"] as? Double,
              endValue > startValue else {
            completion(.failure(CraftHealthError(message: "A valid activityId, type, startDate, and endDate are required")))
            return
        }

        let activityType: HKWorkoutActivityType
        switch type {
        case "running": activityType = .running
        case "walking": activityType = .walking
        case "hiking": activityType = .hiking
        case "cycling": activityType = .cycling
        default:
            completion(.failure(CraftHealthError(message: "Unsupported workout type")))
            return
        }

        let distance = (body["distanceMeters"] as? Double).flatMap { value in
            value > 0 ? HKQuantity(unit: .meter(), doubleValue: value) : nil
        }
        let energy = (body["activeEnergyCalories"] as? Double).flatMap { value in
            value > 0 ? HKQuantity(unit: .kilocalorie(), doubleValue: value) : nil
        }
        let start = Date(timeIntervalSince1970: startValue / 1000)
        let end = Date(timeIntervalSince1970: endValue / 1000)
        let workout = HKWorkout(
            activityType: activityType,
            start: start,
            end: end,
            workoutEvents: nil,
            totalEnergyBurned: energy,
            totalDistance: distance,
            metadata: [HKMetadataKeyExternalUUID: activityId, HKMetadataKeyIndoorWorkout: false]
        )

        healthStore.save(workout) { [weak self] success, error in
            guard let self = self else { return }
            guard success else {
                completion(.failure(CraftHealthError(message: error?.localizedDescription ?? "Workout could not be saved")))
                return
            }

            let locations = (body["locations"] as? [[String: Any]] ?? []).compactMap { item -> CLLocation? in
                guard let latitude = item["latitude"] as? Double,
                      let longitude = item["longitude"] as? Double,
                      let timestamp = item["timestamp"] as? Double else { return nil }
                return CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    altitude: item["altitude"] as? Double ?? 0,
                    horizontalAccuracy: item["accuracy"] as? Double ?? 10,
                    verticalAccuracy: -1,
                    timestamp: Date(timeIntervalSince1970: timestamp / 1000)
                )
            }.filter { $0.timestamp >= start && $0.timestamp <= end }

            guard !locations.isEmpty else {
                completion(.success(["id": workout.uuid.uuidString]))
                return
            }

            let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
            routeBuilder.insertRouteData(locations) { inserted, routeError in
                guard inserted else {
                    completion(.failure(CraftHealthError(message: routeError?.localizedDescription ?? "Workout route could not be saved")))
                    return
                }
                routeBuilder.finishRoute(with: workout, metadata: [HKMetadataKeyExternalUUID: activityId]) { route, finishError in
                    if let finishError = finishError {
                        completion(.failure(CraftHealthError(message: finishError.localizedDescription)))
                    } else {
                        completion(.success([
                            "id": workout.uuid.uuidString,
                            "routeId": route?.uuid.uuidString ?? ""
                        ]))
                    }
                }
            }
        }
    }

    /// The quantity behind each health data type, its unit, and the one
    /// statistic that type supports.
    private static func healthQuantity(_ type: String) -> (type: HKQuantityType?, unit: HKUnit, options: HKStatisticsOptions)? {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        switch type {
        case "steps": return (HKQuantityType.quantityType(forIdentifier: .stepCount), .count(), .cumulativeSum)
        case "activeEnergy": return (HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned), .kilocalorie(), .cumulativeSum)
        case "distance": return (HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning), .meter(), .cumulativeSum)
        case "heartRate": return (HKQuantityType.quantityType(forIdentifier: .heartRate), bpm, .discreteAverage)
        case "restingHeartRate": return (HKQuantityType.quantityType(forIdentifier: .restingHeartRate), bpm, .discreteAverage)
        case "heartRateVariability": return (HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN), .secondUnit(with: .milli), .discreteAverage)
        case "bodyMass": return (HKQuantityType.quantityType(forIdentifier: .bodyMass), .gramUnit(with: .kilo), .mostRecent)
        // A day's food, summed over every meal any app logged: kcal and grams.
        case "dietaryEnergy": return (HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed), .kilocalorie(), .cumulativeSum)
        case "dietaryProtein": return (HKQuantityType.quantityType(forIdentifier: .dietaryProtein), .gram(), .cumulativeSum)
        case "dietaryCarbohydrates": return (HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates), .gram(), .cumulativeSum)
        case "dietaryFat": return (HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal), .gram(), .cumulativeSum)
        default: return nil
        }
    }

    private static func statisticValue(_ statistics: HKStatistics, options: HKStatisticsOptions, unit: HKUnit) -> Double? {
        if options.contains(.cumulativeSum) { return statistics.sumQuantity()?.doubleValue(for: unit) }
        if options.contains(.mostRecent) { return statistics.mostRecentQuantity()?.doubleValue(for: unit) }
        return statistics.averageQuantity()?.doubleValue(for: unit)
    }

    private static let healthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// A stable name for a workout's activity, independent of the SDK's
    /// raw values, so a page can map it to its own sports.
    private static func workoutTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "running"
        case .cycling: return "cycling"
        case .walking: return "walking"
        case .hiking: return "hiking"
        case .swimming: return "swimming"
        case .rowing: return "rowing"
        case .elliptical: return "elliptical"
        case .stairClimbing, .stairs: return "stairClimbing"
        case .yoga: return "yoga"
        case .pilates: return "pilates"
        case .functionalStrengthTraining, .traditionalStrengthTraining, .coreTraining: return "strength"
        case .highIntensityIntervalTraining: return "hiit"
        case .crossTraining, .mixedCardio: return "crossTraining"
        case .crossCountrySkiing: return "crossCountrySkiing"
        case .downhillSkiing, .snowboarding: return "skiing"
        case .paddleSports: return "paddling"
        case .climbing: return "climbing"
        case .dance, .socialDance, .cardioDance: return "dance"
        case .cooldown, .flexibility, .mindAndBody: return "mobility"
        default: return "other"
        }
    }

    /// Workouts in Apple Health — the watch's, and every app's that
    /// writes there — newest first, with the numbers a training log needs.
    func getWorkouts(startDate: Double?, endDate: Double?, limit: Int?, completion: @escaping Completion) {
        guard let healthStore = healthStore else {
            completion(.failure(CraftHealthError(message: "HealthKit not available")))
            return
        }

        let start = startDate.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let end = endDate.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let newestFirst = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let cap = max(1, min(limit ?? 200, 1000))

        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: cap, sortDescriptors: [newestFirst]) { [weak self] _, samples, error in
            if let error = error, (error as? HKError)?.code != .errorNoData {
                completion(.failure(CraftHealthError(message: error.localizedDescription)))
                return
            }

            let bpm = HKUnit.count().unitDivided(by: .minute())
            let workouts: [[String: Any]] = (samples as? [HKWorkout] ?? []).map { workout in
                var item: [String: Any] = [
                    "id": workout.uuid.uuidString,
                    "type": Self.workoutTypeName(workout.workoutActivityType),
                    "startDate": workout.startDate.timeIntervalSince1970 * 1000,
                    "endDate": workout.endDate.timeIntervalSince1970 * 1000,
                    "durationSeconds": workout.duration,
                    "sourceName": workout.sourceRevision.source.name,
                    "indoor": (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false,
                ]
                if let meters = workout.totalDistance?.doubleValue(for: .meter()), meters > 0 {
                    item["distanceMeters"] = meters
                }
                if let ascent = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
                    item["elevationGainMeters"] = ascent.doubleValue(for: .meter())
                }
                if #available(iOS 16.0, *) {
                    if let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate),
                       let heart = workout.statistics(for: heartType) {
                        if let average = heart.averageQuantity()?.doubleValue(for: bpm) { item["averageHeartRate"] = average }
                        if let maximum = heart.maximumQuantity()?.doubleValue(for: bpm) { item["maxHeartRate"] = maximum }
                    }
                    if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
                       let calories = workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        item["activeEnergyCalories"] = calories
                    }
                } else if let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                    item["activeEnergyCalories"] = calories
                }
                return item
            }
            completion(.success(workouts))
        }
        healthStore.execute(query)
    }

    /// One value per local day: a sum for steps, energy and distance, an
    /// average for heart rate, resting heart rate and HRV, the latest
    /// weight, and hours asleep for sleep (counted on the day you woke).
    func getDailyStatistics(type: String, startDate: Double?, endDate: Double?, completion: @escaping Completion) {
        guard let healthStore = healthStore else {
            completion(.failure(CraftHealthError(message: "HealthKit not available")))
            return
        }

        let calendar = Calendar.current
        let end = endDate.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
        let start = calendar.startOfDay(for: startDate.map { Date(timeIntervalSince1970: $0 / 1000) } ?? calendar.date(byAdding: .day, value: -30, to: end)!)

        if type == "sleep" {
            guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
                completion(.failure(CraftHealthError(message: "Sleep data is unavailable")))
                return
            }
            // From the evening before the first day, so its night counts.
            let predicate = HKQuery.predicateForSamples(withStart: calendar.date(byAdding: .hour, value: -12, to: start), end: end, options: [])
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
                if let error = error, (error as? HKError)?.code != .errorNoData {
                    completion(.failure(CraftHealthError(message: error.localizedDescription)))
                    return
                }
                // Time in bed and time awake are not sleep; every asleep
                // stage (and the older single "asleep" value) is.
                let awake: Set<Int> = [HKCategoryValueSleepAnalysis.inBed.rawValue, HKCategoryValueSleepAnalysis.awake.rawValue]
                var secondsByDay: [String: Double] = [:]
                for sample in samples as? [HKCategorySample] ?? [] where !awake.contains(sample.value) {
                    let day = Self.healthDayFormatter.string(from: sample.endDate)
                    secondsByDay[day, default: 0] += sample.endDate.timeIntervalSince(sample.startDate)
                }
                let days = secondsByDay.keys.sorted().map { day -> [String: Any] in
                    ["date": day, "value": (secondsByDay[day]! / 3600 * 100).rounded() / 100, "unit": "hr"]
                }
                completion(.success(days))
            }
            healthStore.execute(query)
            return
        }

        guard let spec = Self.healthQuantity(type), let qType = spec.type else {
            completion(.failure(CraftHealthError(message: "Unknown health data type")))
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let query = HKStatisticsCollectionQuery(
            quantityType: qType,
            quantitySamplePredicate: predicate,
            options: spec.options,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        query.initialResultsHandler = { [weak self] _, collection, error in
            if let error = error, (error as? HKError)?.code != .errorNoData {
                completion(.failure(CraftHealthError(message: error.localizedDescription)))
                return
            }
            var days: [[String: Any]] = []
            collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                guard let value = Self.statisticValue(statistics, options: spec.options, unit: spec.unit) else { return }
                days.append([
                    "date": Self.healthDayFormatter.string(from: statistics.startDate),
                    "value": value,
                    "unit": spec.unit.unitString,
                ])
            }
            completion(.success(days))
        }
        healthStore.execute(query)
    }

    /// Every heart-rate reading between two instants, oldest first: the
    /// beats per minute, when it was taken, and the app and device that
    /// wrote it. A watch's workout readings can arrive as one series
    /// sample; those also carry their count, lowest and highest.
    func getHeartRateSamples(startDate: Double?, endDate: Double?, limit: Int?, completion: @escaping Completion) {
        guard let healthStore = healthStore else {
            completion(.failure(CraftHealthError(message: "HealthKit not available")))
            return
        }
        guard let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(.failure(CraftHealthError(message: "Heart rate is unavailable")))
            return
        }

        let end = endDate.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
        let start = startDate.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Calendar.current.date(byAdding: .day, value: -1, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let oldestFirst = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let cap = max(1, min(limit ?? 10_000, 50_000))

        let query = HKSampleQuery(sampleType: heartType, predicate: predicate, limit: cap, sortDescriptors: [oldestFirst]) { [weak self] _, samples, error in
            if let error = error, (error as? HKError)?.code != .errorNoData {
                completion(.failure(CraftHealthError(message: error.localizedDescription)))
                return
            }

            let bpm = HKUnit.count().unitDivided(by: .minute())
            let rows: [[String: Any]] = (samples as? [HKQuantitySample] ?? []).map { sample in
                var item: [String: Any] = [
                    "bpm": sample.quantity.doubleValue(for: bpm),
                    "startDate": sample.startDate.timeIntervalSince1970 * 1000,
                    "endDate": sample.endDate.timeIntervalSince1970 * 1000,
                    "sourceName": sample.sourceRevision.source.name,
                ]
                if let device = sample.device?.name { item["deviceName"] = device }
                if let model = sample.device?.model { item["deviceModel"] = model }
                if let series = sample as? HKDiscreteQuantitySample, series.count > 1 {
                    item["count"] = series.count
                    item["min"] = series.minimumQuantity.doubleValue(for: bpm)
                    item["max"] = series.maximumQuantity.doubleValue(for: bpm)
                }
                if let raw = sample.metadata?[HKMetadataKeyHeartRateMotionContext] as? NSNumber {
                    switch HKHeartRateMotionContext(rawValue: raw.intValue) {
                    case .sedentary: item["motionContext"] = "sedentary"
                    case .active: item["motionContext"] = "active"
                    default: break
                    }
                }
                return item
            }
            completion(.success(rows))
        }
        healthStore.execute(query)
    }

    /// A stable name for each sleep analysis value: in bed, awake, or one
    /// of the asleep stages (`asleep` when the source does not stage it).
    private static func sleepStageName(_ value: Int) -> String {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .inBed: return "inBed"
        case .awake: return "awake"
        case .asleepCore: return "core"
        case .asleepDeep: return "deep"
        case .asleepREM: return "rem"
        default: return "asleep"
        }
    }

    /// Sleep between two instants, oldest first, as the sources wrote it:
    /// time in bed and every asleep or awake stretch, each with its stage
    /// and whether it counts as asleep, so a page can mark the night.
    func getSleepIntervals(startDate: Double?, endDate: Double?, completion: @escaping Completion) {
        guard let healthStore = healthStore else {
            completion(.failure(CraftHealthError(message: "HealthKit not available")))
            return
        }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(.failure(CraftHealthError(message: "Sleep data is unavailable")))
            return
        }

        let end = endDate.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
        let start = startDate.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Calendar.current.date(byAdding: .day, value: -1, to: end)!
        // Any interval that overlaps the range, so a night that began
        // before it still counts.
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let oldestFirst = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [oldestFirst]) { [weak self] _, samples, error in
            if let error = error, (error as? HKError)?.code != .errorNoData {
                completion(.failure(CraftHealthError(message: error.localizedDescription)))
                return
            }

            let notAsleep: Set<Int> = [HKCategoryValueSleepAnalysis.inBed.rawValue, HKCategoryValueSleepAnalysis.awake.rawValue]
            let rows: [[String: Any]] = (samples as? [HKCategorySample] ?? []).map { sample in
                var item: [String: Any] = [
                    "startDate": sample.startDate.timeIntervalSince1970 * 1000,
                    "endDate": sample.endDate.timeIntervalSince1970 * 1000,
                    "stage": Self.sleepStageName(sample.value),
                    "asleep": !notAsleep.contains(sample.value),
                    "sourceName": sample.sourceRevision.source.name,
                ]
                if let device = sample.device?.name { item["deviceName"] = device }
                return item
            }
            completion(.success(rows))
        }
        healthStore.execute(query)
    }

}
