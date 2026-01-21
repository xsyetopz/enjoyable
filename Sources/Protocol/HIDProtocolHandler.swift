import Foundation

final class HIDProtocolHandler: ProtocolHandlerProtocol, Sendable {
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
    guard data.count >= 8 else {
      throw ProtocolError.invalidReportSize(expected: 8, actual: data.count)
    }

    let buttons = parseButtons(data)
    let dPadDirection = parseDPad(data)

    let leftStick = parseStick(data, xOffset: 0, yOffset: 1)
    let rightStick = parseStick(data, xOffset: 2, yOffset: 3)

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
      leftTrigger: nil,
      rightTrigger: nil,
      leftStick: adjustedLeftStick,
      rightStick: adjustedRightStick,
      timestamp: Date()
    )
  }

  private func parseButtons(_ data: Data) -> ButtonSet {
    var buttons: ButtonSet = []

    let buttonMask = data[2]

    if (buttonMask & 0x01) != 0 { buttons.insert(.a) }
    if (buttonMask & 0x02) != 0 { buttons.insert(.b) }
    if (buttonMask & 0x04) != 0 { buttons.insert(.x) }
    if (buttonMask & 0x08) != 0 { buttons.insert(.y) }
    if (buttonMask & 0x10) != 0 { buttons.insert(.leftShoulder) }
    if (buttonMask & 0x20) != 0 { buttons.insert(.rightShoulder) }
    if (buttonMask & 0x40) != 0 { buttons.insert(.back) }
    if (buttonMask & 0x80) != 0 { buttons.insert(.start) }

    if data.count > 3 {
      let buttonMask2 = data[3]
      if (buttonMask2 & 0x01) != 0 { buttons.insert(.leftStick) }
      if (buttonMask2 & 0x02) != 0 { buttons.insert(.rightStick) }
      if (buttonMask2 & 0x04) != 0 { buttons.insert(.guide) }
    }

    return buttons
  }

  private func parseDPad(_ data: Data) -> DPadDirection {
    if data.count > 2 {
      let dpadBits = (data[2] >> 4) & 0x0F
      switch dpadBits {
      case 0: return .north
      case 1: return .northEast
      case 2: return .east
      case 3: return .southEast
      case 4: return .south
      case 5: return .southWest
      case 6: return .west
      case 7: return .northWest
      default: return .centered
      }
    }

    return .centered
  }

  private func parseStick(_ data: Data, xOffset: Int, yOffset: Int) -> StickPosition {
    guard data.count > yOffset + 1 else {
      return StickPosition(x: 0, y: 0)
    }

    let rawX = Int16(data[xOffset]) - 128
    let rawY = Int16(data[yOffset]) - 128

    return StickPosition(
      x: normalizeStick(rawX),
      y: normalizeStick(rawY)
    )
  }

  private func normalizeStick(_ value: Int16) -> Float {
    let clamped = Int32(
      max(Constants.Input.stickRangeMin, min(Constants.Input.stickRangeMax, value))
    )
    return Float(clamped) / Float(Constants.Input.stickRangeMax)
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
