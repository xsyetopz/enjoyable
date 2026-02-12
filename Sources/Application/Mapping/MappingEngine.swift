import Configuration
import Core
import Foundation

public struct MappingEngine {
  private let _chordTimeout: TimeInterval
  private let _macroTimeout: TimeInterval

  public init(
    chordTimeout: TimeInterval = 0.5,
    macroTimeout: TimeInterval = 5.0
  ) {
    self._chordTimeout = chordTimeout
    self._macroTimeout = macroTimeout
  }

  public func processButtonPress(
    buttonIdentifier: String,
    profile: Profile,
    activeMode: String,
    modeStack: [String],
    activeChord: Set<String>,
    macroStates: [String: MacroState]
  ) -> MappingResult {
    let modeSpecificMappings = _getModeSpecificMappings(profile: profile, mode: activeMode)
    let chordMappings = _getChordMappings(profile: profile, mode: activeMode)
    let macroMappings = _getMacroMappings(profile: profile, mode: activeMode)

    var actions: [MappingAction] = []
    var newChord = activeChord
    var newMacroStates = macroStates

    if let chordAction = _checkChord(
      button: buttonIdentifier,
      chordMappings: chordMappings,
      activeChord: activeChord,
      timeout: _chordTimeout
    ) {
      actions.append(chordAction)
      newChord.removeAll()
      return MappingResult(
        actions: actions,
        newMode: activeMode,
        newModeStack: modeStack,
        newChord: newChord,
        newMacroStates: newMacroStates
      )
    }

    if let macroAction = _checkMacro(
      button: buttonIdentifier,
      macroMappings: macroMappings,
      macroStates: macroStates
    ) {
      actions.append(macroAction)
      return MappingResult(
        actions: actions,
        newMode: activeMode,
        newModeStack: modeStack,
        newChord: newChord,
        newMacroStates: newMacroStates
      )
    }

    if let directMapping = modeSpecificMappings[buttonIdentifier] {
      actions.append(.map(mapping: directMapping))
    }

    return MappingResult(
      actions: actions,
      newMode: activeMode,
      newModeStack: modeStack,
      newChord: newChord,
      newMacroStates: newMacroStates
    )
  }

  public func processButtonRelease(
    buttonIdentifier: String,
    profile: Profile,
    activeMode: String,
    activeChord: Set<String>
  ) -> [MappingAction] {
    var newChord = activeChord
    newChord.remove(buttonIdentifier)

    let modeSpecificMappings = _getModeSpecificMappings(profile: profile, mode: activeMode)

    guard let mapping = modeSpecificMappings[buttonIdentifier] else {
      return []
    }

    return [.release(mapping: mapping)]
  }

  private func _getModeSpecificMappings(profile: Profile, mode: String) -> [String: ButtonMapping] {
    var mappings: [String: ButtonMapping] = [:]
    for mapping in profile.buttonMappings {
      mappings[mapping.buttonIdentifier] = mapping
    }
    return mappings
  }

  private func _getChordMappings(profile: Profile, mode: String) -> [Set<String>: ButtonMapping] {
    var chordMappings: [Set<String>: ButtonMapping] = [:]
    for mapping in profile.buttonMappings {
      let chordComponents = Set(mapping.buttonIdentifier.components(separatedBy: "+"))
      if chordComponents.count > 1 {
        chordMappings[chordComponents] = mapping
      }
    }
    return chordMappings
  }

  private func _getMacroMappings(profile: Profile, mode: String) -> [String: MacroDefinition] {
    [:]
  }

  private func _checkChord(
    button: String,
    chordMappings: [Set<String>: ButtonMapping],
    activeChord: Set<String>,
    timeout: TimeInterval
  ) -> MappingAction? {
    var newChord = activeChord
    newChord.insert(button)

    for (chord, mapping) in chordMappings {
      if chord.isSubset(of: newChord) {
        return .map(mapping: mapping)
      }
    }

    return nil
  }

  private func _checkMacro(
    button: String,
    macroMappings: [String: MacroDefinition],
    macroStates: [String: MacroState]
  ) -> MappingAction? {
    guard let macro = macroMappings[button] else {
      return nil
    }

    var state = macroStates[button] ?? MacroState(currentIndex: 0, startTime: Date())

    guard state.currentIndex < macro.actions.count else {
      return nil
    }

    let action = macro.actions[state.currentIndex]
    return .macro(action: action, sequence: macro.actions)
  }
}

extension MappingEngine {
  public struct MappingResult: Sendable {
    public let actions: [MappingAction]
    public let newMode: String
    public let newModeStack: [String]
    public let newChord: Set<String>
    public let newMacroStates: [String: MacroState]
  }

  public enum MappingAction: Sendable {
    case map(mapping: ButtonMapping)
    case release(mapping: ButtonMapping)
    case macro(action: MacroAction, sequence: [MacroAction])
  }

  public struct MacroDefinition: Sendable {
    public let name: String
    public let actions: [MacroAction]
    public let repeatCount: Int
    public let delayBetween: TimeInterval

    public init(
      name: String,
      actions: [MacroAction],
      repeatCount: Int = 1,
      delayBetween: TimeInterval = 0.05
    ) {
      self.name = name
      self.actions = actions
      self.repeatCount = repeatCount
      self.delayBetween = delayBetween
    }
  }

  public enum MacroAction: Sendable {
    case keyDown(keyCode: UInt16, modifier: KeyModifier)
    case keyUp(keyCode: UInt16, modifier: KeyModifier)
    case wait(duration: TimeInterval)
    case mouseMove(deltaX: Double, deltaY: Double)
    case mouseScroll(deltaX: Double, deltaY: Double)
    case mouseClick(button: String)
  }

  public struct MacroState: Sendable {
    public var currentIndex: Int
    public var startTime: Date
  }
}
