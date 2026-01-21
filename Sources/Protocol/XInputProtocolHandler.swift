import Foundation

final class XInputProtocolHandler: ProtocolHandlerProtocol, Sendable {
  private let config: ControllerConfig
  private let deadZones: DeadZones?

  init(config: ControllerConfig) {
    self.config = config
    self.deadZones = config.deadZones
  }

  func getConfig() -> ControllerConfig {
    return config
  }

  func parse(_ data: Data) throws -> InputEvent {
    let expectedSize = config.reportSize

    guard data.count >= expectedSize else {
      throw ProtocolError.invalidReportSize(
        expected: expectedSize,
        actual: data.count
      )
    }

    let wButtons = UInt16(data[0]) | (UInt16(data[1]) << 8)
    let dpadBits = wButtons & 0x000F

    let buttons = parseButtons(wButtons, dpadBits: dpadBits)
    let dPadDirection = decodeDPad(dpadBits)
    let leftTrigger = normalizeTrigger(data[2])
    let rightTrigger = normalizeTrigger(data[3])

    let thumbLX = Int16(data[4]) | (Int16(data[5]) << 8)
    let thumbLY = Int16(data[6]) | (Int16(data[7]) << 8)
    let thumbRX = Int16(data[8]) | (Int16(data[9]) << 8)
    let thumbRY = Int16(data[10]) | (Int16(data[11]) << 8)

    let leftStick = StickPosition(
      x: normalizeStick(thumbLX),
      y: normalizeStick(thumbLY)
    )
    let rightStick = StickPosition(
      x: normalizeStick(thumbRX),
      y: normalizeStick(thumbRY)
    )

    let adjustedLeftStick = applyDeadZone(
      leftStick,
      threshold: deadZones?.leftStick ?? Constants.DeadZones.leftStickDefault
    )
    let adjustedRightStick = applyDeadZone(
      rightStick,
      threshold: deadZones?.rightStick ?? Constants.DeadZones.rightStickDefault
    )

    return InputEvent(
      buttons: buttons,
      dPadDirection: dPadDirection,
      leftTrigger: leftTrigger,
      rightTrigger: rightTrigger,
      leftStick: adjustedLeftStick,
      rightStick: adjustedRightStick,
      timestamp: Date()
    )
  }

  private func parseButtons(_ wButtons: UInt16, dpadBits: UInt16) -> ButtonSet {
    var buttons: ButtonSet = []

    if (wButtons & 0x1000) != 0 { buttons.insert(.a) }
    if (wButtons & 0x2000) != 0 { buttons.insert(.b) }
    if (wButtons & 0x4000) != 0 { buttons.insert(.x) }
    if (wButtons & 0x8000) != 0 { buttons.insert(.y) }

    if dpadBits != 0x000F {
      if (wButtons & 0x0001) != 0 { buttons.insert(.leftShoulder) }
      if (wButtons & 0x0002) != 0 { buttons.insert(.rightShoulder) }
    }

    if (wButtons & 0x0010) != 0 { buttons.insert(.start) }
    if (wButtons & 0x0020) != 0 { buttons.insert(.back) }
    if (wButtons & 0x0040) != 0 { buttons.insert(.leftStick) }
    if (wButtons & 0x0080) != 0 { buttons.insert(.rightStick) }
    if (wButtons & 0x0100) != 0 { buttons.insert(.guide) }

    return buttons
  }

  private func decodeDPad(_ bits: UInt16) -> DPadDirection {
    switch bits {
    case 0x0: return .north
    case 0x1: return .northEast
    case 0x2: return .east
    case 0x3: return .southEast
    case 0x4: return .south
    case 0x5: return .southWest
    case 0x6: return .west
    case 0x7: return .northWest
    case 0xF: return .centered
    default: return .centered
    }
  }

  private func normalizeStick(_ value: Int16) -> Float {
    let clamped = Int32(
      max(Constants.Input.stickRangeMin, min(Constants.Input.stickRangeMax, value))
    )
    return Float(clamped) / Float(Constants.Input.stickRangeMax)
  }

  private func normalizeTrigger(_ value: UInt8) -> Float {
    Float(value) / Float(Constants.Input.triggerRange)
  }

  private func applyDeadZone(_ stick: StickPosition, threshold: Float) -> StickPosition {
    let magnitude = sqrt(stick.x * stick.x + stick.y * stick.y)
    guard magnitude >= threshold else {
      return StickPosition(x: 0.0, y: 0.0)
    }

    let scale = (magnitude - threshold) / (1.0 - threshold)

    return StickPosition(
      x: (stick.x / magnitude) * scale,
      y: (stick.y / magnitude) * scale
    )
  }
}
