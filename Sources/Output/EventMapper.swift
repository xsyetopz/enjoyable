import Foundation

enum KeyAction {
  case press
  case release
}

struct KeyEvent {
  let keyCode: UInt64
  let action: KeyAction
}

final class EventMapper {
  private var mappings: [String: OutputAction] = [:]
  private var currentMapping: Mapping?

  private var heldKeys: Set<UInt64> = []

  func loadMapping(_ mapping: Mapping) {
    currentMapping = mapping
    mappings = mapping.inputMappings
  }

  func saveMapping() throws {
  }

  func map(_ event: InputEvent) -> [KeyEvent] {
    var keyEvents: [KeyEvent] = []
    var newHeldKeys: Set<UInt64> = []

    for button in event.buttons {
      if let action = mapButton(button), let keyCode = action.keyCode {
        newHeldKeys.insert(keyCode)
      }
    }

    for keyCode in collectKeyCodes(mapDPad(event.dPadDirection)) {
      newHeldKeys.insert(keyCode)
    }
    for keyCode in collectKeyCodes(mapLeftStick(event.leftStick)) {
      newHeldKeys.insert(keyCode)
    }
    for keyCode in collectKeyCodes(mapRightStick(event.rightStick)) {
      newHeldKeys.insert(keyCode)
    }
    for keyCode in collectKeyCodes(mapTriggers(event.leftTrigger, event.rightTrigger)) {
      newHeldKeys.insert(keyCode)
    }

    for keyCode in newHeldKeys {
      if !heldKeys.contains(keyCode) {
        keyEvents.append(KeyEvent(keyCode: keyCode, action: .press))
      }
    }

    for keyCode in heldKeys {
      if !newHeldKeys.contains(keyCode) {
        keyEvents.append(KeyEvent(keyCode: keyCode, action: .release))
      }
    }

    heldKeys = newHeldKeys
    return keyEvents
  }

  private func collectKeyCodes(_ actions: [OutputAction]) -> [UInt64] {
    actions.compactMap { $0.keyCode }
  }

  private func mapButton(_ button: GamepadButton) -> OutputAction? {
    let buttonKey = button.rawValue

    if let mapping = mappings[buttonKey] {
      return mapping
    }

    return defaultButtonMapping(button)
  }

  private func mapDPad(_ direction: DPadDirection) -> [OutputAction] {
    var actions: [OutputAction] = []

    switch direction {
    case .north:
      actions.append(OutputAction(type: .keyPress, keyCode: 126))
    case .south:
      actions.append(OutputAction(type: .keyPress, keyCode: 125))
    case .west:
      actions.append(OutputAction(type: .keyPress, keyCode: 123))
    case .east:
      actions.append(OutputAction(type: .keyPress, keyCode: 124))
    case .centered, .northEast, .northWest, .southEast, .southWest:
      break
    }

    return actions
  }

  private func mapLeftStick(_ stick: StickPosition?) -> [OutputAction] {
    guard let stick = stick else { return [] }
    var actions: [OutputAction] = []

    // PCSX2 Left Analog: W=Up, S=Down, A=Left, D=Right
    let threshold: Float = 0.5

    if stick.y > threshold {  // Up
      actions.append(OutputAction(type: .keyPress, keyCode: 13))  // W key
    }
    if stick.y < -threshold {  // Down
      actions.append(OutputAction(type: .keyPress, keyCode: 1))  // S key
    }
    if stick.x < -threshold {  // Left
      actions.append(OutputAction(type: .keyPress, keyCode: 0))  // A key
    }
    if stick.x > threshold {  // Right
      actions.append(OutputAction(type: .keyPress, keyCode: 2))  // D key
    }

    return actions
  }

  private func mapRightStick(_ stick: StickPosition?) -> [OutputAction] {
    guard let stick = stick else { return [] }
    var actions: [OutputAction] = []

    // PCSX2 Right Analog: T=Up, G=Down, F=Left, H=Right
    let threshold: Float = 0.5

    if stick.y > threshold {  // Up
      actions.append(OutputAction(type: .keyPress, keyCode: 17))  // T key
    }
    if stick.y < -threshold {  // Down
      actions.append(OutputAction(type: .keyPress, keyCode: 5))  // G key
    }
    if stick.x < -threshold {  // Left
      actions.append(OutputAction(type: .keyPress, keyCode: 3))  // F key
    }
    if stick.x > threshold {  // Right
      actions.append(OutputAction(type: .keyPress, keyCode: 4))  // H key
    }

    return actions
  }

  private func mapTriggers(_ left: Float?, _ right: Float?) -> [OutputAction] {
    var actions: [OutputAction] = []

    // PCSX2: L2=1 key, R2=3 key
    if let left = left, left > 0.5 {
      actions.append(OutputAction(type: .keyPress, keyCode: 18))  // 1 key (L2)
    }
    if let right = right, right > 0.5 {
      actions.append(OutputAction(type: .keyPress, keyCode: 20))  // 3 key (R2)
    }

    return actions
  }

  private func defaultButtonMapping(_ button: GamepadButton) -> OutputAction? {
    // PCSX2 DualShock 2 default keyboard mapping
    switch button {
    case .a:  // Xbox A / PlayStation Cross
      return OutputAction(type: .keyPress, keyCode: 40)  // K key
    case .b:  // Xbox B / PlayStation Circle
      return OutputAction(type: .keyPress, keyCode: 37)  // L key
    case .x:  // Xbox X / PlayStation Square
      return OutputAction(type: .keyPress, keyCode: 38)  // J key
    case .y:  // Xbox Y / PlayStation Triangle
      return OutputAction(type: .keyPress, keyCode: 34)  // I key
    case .start:
      return OutputAction(type: .keyPress, keyCode: 36)  // Return
    case .back:  // Select
      return OutputAction(type: .keyPress, keyCode: 51)  // Backspace
    case .leftShoulder:  // L1
      return OutputAction(type: .keyPress, keyCode: 12)  // Q key
    case .rightShoulder:  // R1
      return OutputAction(type: .keyPress, keyCode: 14)  // E key
    case .leftStick:  // L3
      return OutputAction(type: .keyPress, keyCode: 19)  // 2 key
    case .rightStick:  // R3
      return OutputAction(type: .keyPress, keyCode: 21)  // 4 key
    case .guide:
      return OutputAction(type: .keyPress, keyCode: 53)  // Escape
    default:
      return nil
    }
  }
}
