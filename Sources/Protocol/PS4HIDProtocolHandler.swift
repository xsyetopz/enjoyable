import Foundation

final class PS4HIDProtocolHandler: ProtocolHandlerProtocol, Sendable {
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
    guard data.count >= 10 else {
      throw ProtocolError.invalidReportSize(expected: 10, actual: data.count)
    }

    let reportType = data[0]
    guard reportType == 0x01 else {
      return InputEvent(
        buttons: [],
        dPadDirection: .centered,
        leftTrigger: nil,
        rightTrigger: nil,
        leftStick: nil,
        rightStick: nil,
        timestamp: Date()
      )
    }

    let buttons = parseButtons(data)
    let dPadDirection = parseDPad(data)

    let leftTrigger = normalizeTrigger(data[8])
    let rightTrigger = normalizeTrigger(data[9])

    let leftStick = parseStick(data, xOffset: 1, yOffset: 2)
    let rightStick = parseStick(data, xOffset: 3, yOffset: 4)

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

  private func parseButtons(_ data: Data) -> ButtonSet {
    var buttons: ButtonSet = []

    let buttonMask1 = data[5]
    let buttonMask2 = data[6]

    if (buttonMask1 & 0x01) != 0 { buttons.insert(.share) }
    if (buttonMask1 & 0x02) != 0 { buttons.insert(.leftStick) }
    if (buttonMask1 & 0x04) != 0 { buttons.insert(.rightStick) }
    if (buttonMask1 & 0x08) != 0 { buttons.insert(.start) }
    if (buttonMask1 & 0x10) != 0 { buttons.insert(.dPadUp) }
    if (buttonMask1 & 0x20) != 0 { buttons.insert(.dPadRight) }
    if (buttonMask1 & 0x40) != 0 { buttons.insert(.dPadDown) }
    if (buttonMask1 & 0x80) != 0 { buttons.insert(.dPadLeft) }

    if (buttonMask2 & 0x01) != 0 { buttons.insert(.leftShoulder) }
    if (buttonMask2 & 0x02) != 0 { buttons.insert(.rightShoulder) }
    if (buttonMask2 & 0x04) != 0 { buttons.insert(.guide) }

    if (buttonMask2 & 0x10) != 0 { buttons.insert(.a) }
    if (buttonMask2 & 0x20) != 0 { buttons.insert(.b) }
    if (buttonMask2 & 0x40) != 0 { buttons.insert(.x) }
    if (buttonMask2 & 0x80) != 0 { buttons.insert(.y) }

    return buttons
  }

  private func parseDPad(_ data: Data) -> DPadDirection {
    let buttonMask1 = data[5]

    if (buttonMask1 & 0x10) != 0 { return .north }
    if (buttonMask1 & 0x20) != 0 { return .east }
    if (buttonMask1 & 0x40) != 0 { return .south }
    if (buttonMask1 & 0x80) != 0 { return .west }

    return .centered
  }

  private func parseStick(_ data: Data, xOffset: Int, yOffset: Int) -> StickPosition {
    guard data.count > yOffset else {
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
