import Foundation

protocol ProtocolHandlerProtocol: Sendable {
  func parse(_ data: Data) throws -> InputEvent
  func getConfig() -> ControllerConfig
}

final class GIPProtocolHandler: ProtocolHandlerProtocol, Sendable {
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
      throw ProtocolError.invalidReportSize(
        expected: Constants.ProtocolConfig.gipReportSize,
        actual: data.count
      )
    }

    let reportType = data[0]
    if reportType == 0x20 {
      if data.count < 19 { return emptyEvent() }
      let buttons = parseButtons20(data)
      let dPadDirection = parseDPad20(data)
      let leftTrigger = parseTrigger(data, offset: 6)
      let rightTrigger = parseTrigger(data, offset: 8)
      let leftStick = parseStick20(data, offset: 10)
      let rightStick = parseStick20(data, offset: 14)

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
    if reportType == 0x03 {
      if data.count < 8 { return emptyEvent() }

      // ignore 0x20 (keepalive/status packets(?))
      let subtype = data[1]
      if subtype != 0x01 { return emptyEvent() }

      let buttons = parseButtons03(data)
      return InputEvent(
        buttons: buttons,
        dPadDirection: .centered,
        leftTrigger: nil,
        rightTrigger: nil,
        leftStick: nil,
        rightStick: nil,
        timestamp: Date()
      )
    }
    if reportType == 0x07 {
      // Xbox button packet: 07 20 0A 02 01 5B
      var buttons: ButtonSet = []
      if data.count >= 5 && data[4] == 0x01 {
        buttons.insert(.guide)
      }
      return InputEvent(
        buttons: buttons,
        dPadDirection: .centered,
        leftTrigger: nil,
        rightTrigger: nil,
        leftStick: nil,
        rightStick: nil,
        timestamp: Date()
      )
    }
    guard reportType == Constants.ReportType.gipInput else {
      return emptyEvent()
    }

    let buttons = parseButtons(data)
    let dPadDirection = parseDPad(data)
    let leftTrigger = normalizeTrigger(data[0x06])
    let rightTrigger = normalizeTrigger(data[0x07])
    let leftStick = parseStick(data, offset: 0x08)
    let rightStick = parseStick(data, offset: 0x0C)

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

    let buttonMaskLow = data[0x04]
    let buttonMaskHigh = data[0x05]

    if (buttonMaskLow & 0x01) != 0 { buttons.insert(.dPadUp) }
    if (buttonMaskLow & 0x02) != 0 { buttons.insert(.dPadDown) }
    if (buttonMaskLow & 0x04) != 0 { buttons.insert(.dPadLeft) }
    if (buttonMaskLow & 0x08) != 0 { buttons.insert(.dPadRight) }
    if (buttonMaskLow & 0x10) != 0 { buttons.insert(.start) }
    if (buttonMaskLow & 0x20) != 0 { buttons.insert(.back) }
    if (buttonMaskLow & 0x40) != 0 { buttons.insert(.leftStick) }
    if (buttonMaskLow & 0x80) != 0 { buttons.insert(.rightStick) }

    if (buttonMaskHigh & 0x01) != 0 { buttons.insert(.leftShoulder) }
    if (buttonMaskHigh & 0x02) != 0 { buttons.insert(.rightShoulder) }
    if (buttonMaskHigh & 0x04) != 0 { buttons.insert(.guide) }

    if (buttonMaskHigh & 0x10) != 0 { buttons.insert(.a) }
    if (buttonMaskHigh & 0x20) != 0 { buttons.insert(.b) }
    if (buttonMaskHigh & 0x40) != 0 { buttons.insert(.x) }
    if (buttonMaskHigh & 0x80) != 0 { buttons.insert(.y) }

    return buttons
  }

  private func parseDPad(_ data: Data) -> DPadDirection {
    let buttonMaskLow = data[0x04]

    if (buttonMaskLow & 0x01) != 0 { return .north }
    if (buttonMaskLow & 0x02) != 0 { return .south }
    if (buttonMaskLow & 0x04) != 0 { return .west }
    if (buttonMaskLow & 0x08) != 0 { return .east }

    return .centered
  }

  private func parseStick(_ data: Data, offset: Int) -> StickPosition {
    let rawX = Int16(data[offset]) | (Int16(data[offset + 1]) << 8)
    let rawY = Int16(data[offset + 2]) | (Int16(data[offset + 3]) << 8)

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

  private func emptyEvent() -> InputEvent {
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

  private func parseButtons20(_ data: Data) -> ButtonSet {
    var buttons: ButtonSet = []
    if data.count < 19 { return buttons }

    let byte4 = data[4]  // face buttons, menu, view
    let byte5 = data[5]  // D-pad, shoulders
    let byte18 = data[18]  // Share button

    if (byte4 & 0x10) != 0 { buttons.insert(.a) }
    if (byte4 & 0x20) != 0 { buttons.insert(.b) }
    if (byte4 & 0x40) != 0 { buttons.insert(.x) }
    if (byte4 & 0x80) != 0 { buttons.insert(.y) }

    if (byte4 & 0x04) != 0 { buttons.insert(.start) }  // Menu button
    if (byte4 & 0x08) != 0 { buttons.insert(.back) }  // View button

    if (byte5 & 0x10) != 0 { buttons.insert(.leftShoulder) }
    if (byte5 & 0x20) != 0 { buttons.insert(.rightShoulder) }

    if (byte18 & 0x01) != 0 {
      // Share button
    }

    return buttons
  }

  private func parseDPad20(_ data: Data) -> DPadDirection {
    if data.count < 6 { return .centered }
    let byte5 = data[5]

    if (byte5 & 0x01) != 0 { return .north }  // Up
    if (byte5 & 0x02) != 0 { return .south }  // Down
    if (byte5 & 0x04) != 0 { return .west }  // Left
    if (byte5 & 0x08) != 0 { return .east }  // Right

    return .centered
  }

  private func parseTrigger(_ data: Data, offset: Int) -> Float {
    if data.count < offset + 2 { return 0.0 }
    let rawValue = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    return Float(rawValue) / 1023.0
  }

  private func parseStick20(_ data: Data, offset: Int) -> StickPosition {
    if data.count < offset + 4 {
      return StickPosition(x: 0.0, y: 0.0)
    }

    // little endian
    let rawX = Int16(data[offset]) | (Int16(data[offset + 1]) << 8)
    let rawY = Int16(data[offset + 2]) | (Int16(data[offset + 3]) << 8)

    return StickPosition(
      x: normalizeStick(rawX),
      y: normalizeStick(rawY)
    )
  }

  private func parseButtons03(_ data: Data) -> ButtonSet {
    var buttons: ButtonSet = []
    if data.count < 5 { return buttons }

    let byte4 = data[4]

    if (byte4 & 0x10) != 0 { buttons.insert(.a) }
    if (byte4 & 0x20) != 0 { buttons.insert(.b) }
    if (byte4 & 0x40) != 0 { buttons.insert(.x) }
    if (byte4 & 0x80) != 0 { buttons.insert(.y) }

    return buttons
  }
}
