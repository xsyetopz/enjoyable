import Foundation

struct ProtocolDetector: Sendable {
  private let indexLoader: ControllerIndexLoader

  init(
    indexLoader: ControllerIndexLoader = ControllerIndexLoader()
  ) {
    self.indexLoader = indexLoader
  }

  func detectController(
    vendorId: VendorId,
    productId: ProductId,
    ioObject: IOObject?
  )
    async -> DetectedProtocol?
  {
    if let knownConfig = try? indexLoader.lookup(vendorId: vendorId, productId: productId) {
      return DetectedProtocol(
        protocolType: knownConfig.protocolType,
        score: DetectionScore.high,
        config: knownConfig
      )
    }

    let device: USBDeviceHandle?
    if let ioObject = ioObject {
      device = USBDeviceHandle(ioObject: ioObject, endpointIn: 0x81, endpointOut: 0x02)
    } else {
      device = nil
    }

    guard let device = device else {
      return nil
    }

    var handlers: [(ProtocolType, DetectionScore)] = []

    if let gipScore = await tryProtocol(.gip, on: device) {
      handlers.append((.gip, gipScore))
    }
    if let xinputScore = await tryProtocol(.xinput, on: device) {
      handlers.append((.xinput, xinputScore))
    }
    if let hidScore = await tryProtocol(.hid, on: device) {
      handlers.append((.hid, hidScore))
    }
    if let switchHIDScore = await tryProtocol(.switchHID, on: device) {
      handlers.append((.switchHID, switchHIDScore))
    }
    if let ps4HIDScore = await tryProtocol(.ps4HID, on: device) {
      handlers.append((.ps4HID, ps4HIDScore))
    }
    if let ps5HIDScore = await tryProtocol(.ps5HID, on: device) {
      handlers.append((.ps5HID, ps5HIDScore))
    }

    guard let bestMatch = handlers.max(by: { $0.1.score < $1.1.score }),
      bestMatch.1.isValid
    else {
      return nil
    }

    let config = Self.createDefaultConfig(
      for: bestMatch.0,
      vendorId: vendorId,
      productId: productId
    )

    return DetectedProtocol(
      protocolType: bestMatch.0,
      score: bestMatch.1,
      config: config
    )
  }

  private func tryProtocol(
    _ protocolType: ProtocolType,
    on device: USBDeviceHandle
  ) async
    -> DetectionScore?
  {
    do {
      try device.open()
      defer { device.close() }

      switch protocolType {
      case .gip:
        return await Self.testGIPProtocol(device)
      case .xinput:
        return await Self.testXInputProtocol(device)
      case .hid:
        return await Self.testHIDProtocol(device)
      case .switchHID:
        return await Self.testSwitchHIDProtocol(device)
      case .ps4HID:
        return await Self.testPS4HIDProtocol(device)
      case .ps5HID:
        return await Self.testPS5HIDProtocol(device)
      }
    } catch {
      return nil
    }
  }

  private static func testGIPProtocol(_ device: USBDeviceHandle) async -> DetectionScore {
    let handshakeCommand: [UInt8] = [0x05, 0x20, 0x00, 0x01, 0x00]

    do {
      try device.write(Data(handshakeCommand))

      let response = try await device.readAsync(64)

      guard response.count >= 5 else {
        return DetectionScore.low
      }

      if response[0] == 0x05 && response[1] == 0x20 {
        let identifyCommand: [UInt8] = [0x0A, 0x20, 0x00, 0x03, 0x00, 0x01, 0x14]
        try device.write(Data(identifyCommand))

        let identifyResponse = try await device.readAsync(64)
        if identifyResponse.count >= 7 && identifyResponse[0] == 0x0A && identifyResponse[1] == 0x20
        {
          return DetectionScore.high
        }
        return DetectionScore.medium
      }

      return DetectionScore.low
    } catch {
      return DetectionScore.invalid
    }
  }

  private static func testXInputProtocol(_ device: USBDeviceHandle) async -> DetectionScore {
    let initCommand: [UInt8] = [0x01, 0x03, 0x00]

    do {
      try device.write(Data(initCommand))

      let response = try await device.readAsync(20)

      guard response.count >= 14 else {
        return DetectionScore.low
      }
      if response[0] == 0x00 && response[1] == 0x0F {
        return DetectionScore.high
      }

      return DetectionScore.low
    } catch {
      return DetectionScore.invalid
    }
  }

  private static func testHIDProtocol(_ device: USBDeviceHandle) async -> DetectionScore {
    do {
      let response = try await device.readAsync(64)
      guard response.count >= 8 else {
        return DetectionScore.low
      }

      let hasValidButtons = (response[2] != 0 || response[3] != 0 || response[4] != 0)
      let hasValidAxes = (response[0] != 0x80 || response[1] != 0x80)
      if hasValidButtons || hasValidAxes {
        return DetectionScore.medium
      }

      return DetectionScore.low
    } catch {
      return DetectionScore.invalid
    }
  }

  private static func testSwitchHIDProtocol(_ device: USBDeviceHandle) async -> DetectionScore {
    let initCommand: [UInt8] = [0x80, 0x02]

    do {
      try device.write(Data(initCommand))

      let response = try await device.readAsync(64)
      guard response.count >= 12 else {
        return DetectionScore.low
      }
      if response[0] == 0x30 {
        return DetectionScore.high
      }

      return DetectionScore.low
    } catch {
      return DetectionScore.invalid
    }
  }

  private static func testPS4HIDProtocol(_ device: USBDeviceHandle) async -> DetectionScore {
    let initCommand: [UInt8] = [0x05, 0x03, 0x00, 0x00, 0x00]

    do {
      try device.write(Data(initCommand))

      let response = try await device.readAsync(64)
      guard response.count >= 10 else {
        return DetectionScore.low
      }
      if response[0] == 0x01 {
        return DetectionScore.high
      }

      return DetectionScore.low
    } catch {
      return DetectionScore.invalid
    }
  }

  private static func testPS5HIDProtocol(_ device: USBDeviceHandle) async -> DetectionScore {
    let initCommand: [UInt8] = [0x05, 0x03, 0x00, 0x00, 0x00]

    do {
      try device.write(Data(initCommand))

      let response = try await device.readAsync(64)
      guard response.count >= 12 else {
        return DetectionScore.low
      }
      if response[0] == 0x01 {
        return DetectionScore.high
      }

      return DetectionScore.low
    } catch {
      return DetectionScore.invalid
    }
  }

  private static func createDefaultConfig(
    for protocolType: ProtocolType,
    vendorId: VendorId,
    productId: ProductId
  ) -> ControllerConfig {
    let reportSize: Int
    let endpoints: Endpoints
    let initSequence: [InitializationStep]

    switch protocolType {
    case .gip:
      reportSize = 36
      endpoints = Endpoints(in: 0x81, out: 0x02)
      initSequence = [
        InitializationStep(type: .write, data: [0x05, 0x20, 0x00, 0x01, 0x00]),
        InitializationStep(type: .delay, delayMs: 10),
        InitializationStep(type: .write, data: [0x0A, 0x20, 0x00, 0x03, 0x00, 0x01, 0x14]),
        InitializationStep(type: .delay, delayMs: 10),
        InitializationStep(type: .write, data: [0x06, 0x20, 0x00, 0x02, 0x01, 0x00]),
      ]
    case .xinput:
      reportSize = 14
      endpoints = Endpoints(in: 0x81, out: 0x02)
      initSequence = [
        InitializationStep(type: .write, data: [0x01, 0x03, 0x00]),
        InitializationStep(type: .delay, delayMs: 10),
      ]
    case .hid, .switchHID, .ps4HID, .ps5HID:
      reportSize = 64
      endpoints = Endpoints(in: 0x81, out: 0x01)
      initSequence = []
    }

    return ControllerConfig(
      id: "auto-\(vendorId)-\(productId)",
      name: "Auto-detected Controller",
      vendorId: vendorId,
      productId: productId,
      transport: "usb",
      protocolTypeStr: protocolType.rawValue,
      reportSize: reportSize,
      manufacturer: nil,
      endpoints: endpoints,
      features: ControllerFeatures(
        vibration: false,
        rgb: false,
        touchpad: false,
        hapticFeedback: false
      ),
      deadZones: DeadZones(leftStick: 0.2395, rightStick: 0.2652, triggers: 0.0),
      protocolConfig: ProtocolConfigData(pollRate: 8, handshakeRequired: true),
      buttonMapping: nil,
      reportFormat: nil,
      initSequence: initSequence
    )
  }
}

struct DetectedProtocol: Sendable {
  let protocolType: ProtocolType
  let score: DetectionScore
  let config: ControllerConfig
}
