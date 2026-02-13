import Logging

extension Logger {
  func debug(hex: UInt8, _ message: String) {
    debug("\(message) 0x\(String(format: "%02X", hex))")
  }

  func debug(hex: UInt16, _ message: String) {
    debug("\(message) 0x\(String(format: "%04X", hex))")
  }

  func trace(hex: UInt8, _ message: String) {
    trace("\(message) 0x\(String(format: "%02X", hex))")
  }

  func trace(hex: UInt16, _ message: String) {
    trace("\(message) 0x\(String(format: "%04X", hex))")
  }
}
