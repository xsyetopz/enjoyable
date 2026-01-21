import Foundation

actor DeviceRegistry {
  private var devices: [DeviceId: ControllerDevice] = [:]

  func register(_ device: ControllerDevice) {
    devices[device.id] = device
  }

  func unregister(_ id: DeviceId) {
    devices.removeValue(forKey: id)
  }

  func get(_ id: DeviceId) -> ControllerDevice? {
    return devices[id]
  }

  func getAll() -> [ControllerDevice] {
    return Array(devices.values)
  }

  func getActiveCount() async -> Int {
    var count = 0
    for device in devices.values {
      if await device.isActive {
        count += 1
      }
    }
    return count
  }
}
