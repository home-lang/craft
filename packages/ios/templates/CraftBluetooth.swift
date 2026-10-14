import CoreBluetooth
import Foundation

struct CraftBluetoothError: Error {
    let message: String
    let code: String
}

/// One explicitly chosen GATT channel. Scanning is user initiated; no vendor API.
final class CraftBluetooth: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    typealias Completion = (Result<Any, CraftBluetoothError>) -> Void
    static let shared = CraftBluetooth()
    private var central: CBCentralManager?
    private var devices: [String: CBPeripheral] = [:]
    private var names: [String: String] = [:]
    private var strengths: [String: Int] = [:]
    private var scanServices: [CBUUID] = []
    private var namePrefix = ""
    private var scanCompletion: Completion?
    private var scanTimer: DispatchWorkItem?
    private var peripheral: CBPeripheral?
    private var serviceUUID: CBUUID?
    private var writeUUID: CBUUID?
    private var notifyUUID: CBUUID?
    private var writer: CBCharacteristic?
    private var notifier: CBCharacteristic?
    private var connectCompletion: Completion?
    private var connectTimer: DispatchWorkItem?
    private var exchangeCompletion: Completion?
    private var exchangeTimer: DispatchWorkItem?
    private var responsePrefix = Data()
    private var connected = false

    func perform(method: String, args: [Any], completion: @escaping Completion) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.perform(method: method, args: args, completion: completion) }
            return
        }
        let options = args.first as? [String: Any] ?? [:]
        switch method {
        case "getState":
            completion(.success(["available": true, "connected": connected, "scanning": scanCompletion != nil]))
        case "scan": scan(options, completion)
        case "stopScan": stopScan(); completion(.success(true))
        case "connect": connect(options, completion)
        case "exchange": exchange(options, completion)
        case "disconnect": disconnect(); completion(.success(true))
        default: reject(completion, "Unsupported Bluetooth method", "UNKNOWN_ACTION")
        }
    }

    private func reject(_ completion: Completion, _ message: String, _ code: String) {
        completion(.failure(CraftBluetoothError(message: message, code: code)))
    }

    private func ensureCentral() {
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
    }

    private func scan(_ options: [String: Any], _ completion: @escaping Completion) {
        guard scanCompletion == nil, connectCompletion == nil, exchangeCompletion == nil else {
            return reject(completion, "A Bluetooth operation is already running", "BUSY")
        }
        guard let services = options["services"] as? [String], !services.isEmpty, services.count <= 8,
              services.allSatisfy({ UUID(uuidString: $0) != nil }) else {
            return reject(completion, "Scan needs full service UUIDs", "INVALID_ARGUMENT")
        }
        let timeout = min(20, max(1, (options["timeoutMs"] as? Double ?? 10000) / 1000))
        scanServices = services.map(CBUUID.init(string:))
        namePrefix = options["namePrefix"] as? String ?? ""
        devices.removeAll(); names.removeAll(); strengths.removeAll()
        scanCompletion = completion
        ensureCentral()
        if central?.state == .poweredOn { startScan() }
        else if let state = central?.state, state != .unknown, state != .resetting { rejectRadio(state); return }
        let timer = DispatchWorkItem { [weak self] in self?.finishScan() }
        scanTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timer)
    }

    private func startScan() {
        guard scanCompletion != nil else { return }
        central?.scanForPeripherals(withServices: scanServices, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    private func finishScan() {
        central?.stopScan(); scanTimer?.cancel(); scanTimer = nil
        let completion = scanCompletion; scanCompletion = nil
        let rows: [[String: Any]] = devices.keys.sorted().map { ["id": $0, "name": names[$0] ?? "", "rssi": strengths[$0] ?? -127] }
        completion?(.success(rows))
    }

    private func stopScan() {
        central?.stopScan(); scanTimer?.cancel(); scanTimer = nil
        let completion = scanCompletion; scanCompletion = nil
        if let completion { reject(completion, "Bluetooth scan cancelled", "CANCELLED") }
    }

    private func rejectRadio(_ state: CBManagerState) {
        let code = state == .unauthorized ? "NOT_AUTHORIZED" : state == .poweredOff ? "BLUETOOTH_OFF" : "UNSUPPORTED"
        let failure = CraftBluetoothError(message: "Bluetooth is not available", code: code)
        central?.stopScan(); scanTimer?.cancel(); scanTimer = nil
        let scan = scanCompletion; scanCompletion = nil; scan?(.failure(failure))
        settleConnect(.failure(failure)); settleExchange(.failure(failure))
        connected = false
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { startScan() }
        else if central.state != .unknown, central.state != .resetting { rejectRadio(central.state) }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard scanCompletion != nil, devices.count < 64 else { return }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        guard namePrefix.isEmpty || name.lowercased().hasPrefix(namePrefix.lowercased()) else { return }
        let id = peripheral.identifier.uuidString
        devices[id] = peripheral; names[id] = name; strengths[id] = RSSI.intValue
    }

    private func connect(_ options: [String: Any], _ completion: @escaping Completion) {
        guard scanCompletion == nil, connectCompletion == nil, exchangeCompletion == nil else {
            return reject(completion, "A Bluetooth operation is already running", "BUSY")
        }
        guard let id = options["id"] as? String, let found = devices[id],
              let service = options["service"] as? String, UUID(uuidString: service) != nil,
              let write = options["write"] as? String, UUID(uuidString: write) != nil,
              let notify = options["notify"] as? String, UUID(uuidString: notify) != nil else {
            return reject(completion, "Choose a nearby device and its GATT channel", "INVALID_ARGUMENT")
        }
        guard central?.state == .poweredOn else { return reject(completion, "Bluetooth is off", "BLUETOOTH_OFF") }
        disconnect()
        peripheral = found; serviceUUID = CBUUID(string: service); writeUUID = CBUUID(string: write); notifyUUID = CBUUID(string: notify)
        found.delegate = self; connectCompletion = completion
        central?.connect(found, options: nil)
        let timer = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.settleConnect(.failure(CraftBluetoothError(message: "Device did not connect; wake it and try again", code: "TIMEOUT")))
            self.disconnect()
        }
        connectTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timer)
    }

    private func settleConnect(_ result: Result<Any, CraftBluetoothError>) {
        connectTimer?.cancel(); connectTimer = nil
        let completion = connectCompletion; connectCompletion = nil; completion?(result)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral === self.peripheral, let serviceUUID else { return }
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral === self.peripheral else { return }
        settleConnect(.failure(CraftBluetoothError(message: "Bluetooth connection failed", code: "CONNECT_FAILED")))
        disconnect()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral === self.peripheral else { return }
        connected = false; writer = nil; notifier = nil
        settleConnect(.failure(CraftBluetoothError(message: "Bluetooth device disconnected", code: "DISCONNECTED")))
        settleExchange(.failure(CraftBluetoothError(message: "Bluetooth device disconnected", code: "DISCONNECTED")))
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral === self.peripheral else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }), let writeUUID, let notifyUUID else {
            settleConnect(.failure(CraftBluetoothError(message: "The selected GATT service is missing", code: "UNSUPPORTED_DEVICE"))); disconnect(); return
        }
        peripheral.discoverCharacteristics([writeUUID, notifyUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral === self.peripheral else { return }
        writer = service.characteristics?.first(where: { $0.uuid == writeUUID })
        notifier = service.characteristics?.first(where: { $0.uuid == notifyUUID })
        guard error == nil, let writer, let notifier, writer.properties.contains(.write) || writer.properties.contains(.writeWithoutResponse), notifier.properties.contains(.notify) else {
            settleConnect(.failure(CraftBluetoothError(message: "The selected GATT channel is missing", code: "UNSUPPORTED_DEVICE"))); disconnect(); return
        }
        peripheral.setNotifyValue(true, for: notifier)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral === self.peripheral, characteristic === notifier else { return }
        guard error == nil, characteristic.isNotifying else {
            settleConnect(.failure(CraftBluetoothError(message: "Could not subscribe to the device", code: "CONNECT_FAILED"))); disconnect(); return
        }
        connected = true
        let id = peripheral.identifier.uuidString
        settleConnect(.success(["id": id, "name": names[id] ?? peripheral.name ?? ""]))
    }

    private func exchange(_ options: [String: Any], _ completion: @escaping Completion) {
        guard exchangeCompletion == nil else { return reject(completion, "A Bluetooth request is already running", "BUSY") }
        guard connected, let peripheral, let writer else { return reject(completion, "Bluetooth device is disconnected", "DISCONNECTED") }
        guard let bytes = options["bytes"] as? [Int], !bytes.isEmpty, bytes.count <= 182, bytes.allSatisfy({ (0...255).contains($0) }),
              let prefix = options["responsePrefix"] as? [Int], !prefix.isEmpty, prefix.count <= 16, prefix.allSatisfy({ (0...255).contains($0) }) else {
            return reject(completion, "Invalid Bluetooth request bytes", "INVALID_ARGUMENT")
        }
        let type: CBCharacteristicWriteType = writer.properties.contains(.write) ? .withResponse : .withoutResponse
        guard bytes.count <= peripheral.maximumWriteValueLength(for: type) else { return reject(completion, "Bluetooth request exceeds the negotiated MTU", "MTU_TOO_SMALL") }
        if type == .withoutResponse, !peripheral.canSendWriteWithoutResponse { return reject(completion, "Bluetooth write queue is busy; retry", "BUSY") }
        responsePrefix = Data(prefix.map(UInt8.init)); exchangeCompletion = completion
        let timeout = min(20, max(1, (options["timeoutMs"] as? Double ?? 10000) / 1000))
        let timer = DispatchWorkItem { [weak self] in self?.settleExchange(.failure(CraftBluetoothError(message: "Bluetooth device did not answer", code: "TIMEOUT"))) }
        exchangeTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timer)
        peripheral.writeValue(Data(bytes.map(UInt8.init)), for: writer, type: type)
    }

    private func settleExchange(_ result: Result<Any, CraftBluetoothError>) {
        exchangeTimer?.cancel(); exchangeTimer = nil
        let completion = exchangeCompletion; exchangeCompletion = nil; responsePrefix = Data(); completion?(result)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral === self.peripheral, characteristic === writer, error != nil else { return }
        settleExchange(.failure(CraftBluetoothError(message: "Bluetooth write failed", code: "WRITE_FAILED")))
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral === self.peripheral, characteristic === notifier, exchangeCompletion != nil else { return }
        guard error == nil, let data = characteristic.value else {
            settleExchange(.failure(CraftBluetoothError(message: "Bluetooth notification failed", code: "READ_FAILED"))); return
        }
        guard data.starts(with: responsePrefix) else { return }
        guard data.count <= 4096 else {
            settleExchange(.failure(CraftBluetoothError(message: "Bluetooth response is too large", code: "INVALID_RESPONSE"))); return
        }
        settleExchange(.success(data.map(Int.init)))
    }

    private func disconnect() {
        stopScan()
        settleConnect(.failure(CraftBluetoothError(message: "Bluetooth connection cancelled", code: "CANCELLED")))
        settleExchange(.failure(CraftBluetoothError(message: "Bluetooth request cancelled", code: "CANCELLED")))
        if let peripheral { central?.cancelPeripheralConnection(peripheral); peripheral.delegate = nil }
        peripheral = nil; writer = nil; notifier = nil; connected = false
    }
}
