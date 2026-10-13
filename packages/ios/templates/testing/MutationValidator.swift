import Foundation
let messages = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [[String: Any]]
func report(_ message: String) {
  try! (message + "\n").write(to: URL(fileURLWithPath: CommandLine.arguments[2]), atomically: true, encoding: .utf8)
}
let document = CraftNativeMutationDocument()
for message in messages {
  let payload = message["payload"] as? [String: Any] ?? [:]
  if message["type"] as? String == "RENDER" { document.replace(with: payload["document"] as! [String: Any]) }
  if message["type"] as? String == "MUTATE" {
    do { _ = try document.apply(payload) }
    catch let failure as CraftNativeMutationFailure { report("\(failure.code): \(failure.message) at operation \(failure.operationIndex ?? -1)"); exit(1) }
  }
}
report("Accepted all native update batches")
