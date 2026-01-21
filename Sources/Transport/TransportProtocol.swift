import Foundation
import IOKit
import IOUSBHost

protocol DeviceHandle: Sendable {
  func open() throws
  func close()
  func read(_ length: Int) throws -> Data
  func write(_ data: Data) throws
}

protocol TransportProtocol: Sendable {
  func start() async throws
  func stop() async throws
  func enumerate() async throws -> [DeviceCandidate]
  func read(deviceId: DeviceId, endpoint: UInt8, length: Int) async throws -> Data
  func write(deviceId: DeviceId, endpoint: UInt8, data: Data) async throws
  func registerDevice(_ deviceId: DeviceId, device: any DeviceHandle)
  func unregisterDevice(_ deviceId: DeviceId)
  var onDeviceDiscovered: ((DeviceCandidate) -> Void)? { get set }
  var onDeviceRemoved: ((DeviceId) -> Void)? { get set }
}
