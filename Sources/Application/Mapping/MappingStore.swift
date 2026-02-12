import Configuration
import Foundation

public actor MappingStore {
  private var _activeMode: String
  private var _modeStack: [String]
  private var _activeChord: Set<String>
  private var _macroStates: [String: MappingEngine.MacroState]
  private var _buttonHistory: [(button: String, timestamp: Date)]

  public init(initialMode: String = "default") {
    self._activeMode = initialMode
    self._modeStack = []
    self._activeChord = []
    self._macroStates = [:]
    self._buttonHistory = []
  }

  public func getActiveMode() -> String {
    _activeMode
  }

  public func pushMode(_ mode: String) {
    _modeStack.append(_activeMode)
    _activeMode = mode
  }

  public func popMode() {
    _activeMode = _modeStack.popLast() ?? "default"
  }

  public func switchMode(_ mode: String) {
    _activeMode = mode
  }

  public func getModeStack() -> [String] {
    _modeStack
  }

  public func getActiveChord() -> Set<String> {
    _activeChord
  }

  public func addToChord(_ button: String) {
    _activeChord.insert(button)
  }

  public func removeFromChord(_ button: String) {
    _activeChord.remove(button)
  }

  public func clearChord() {
    _activeChord.removeAll()
  }

  public func getMacroState(for button: String) -> MappingEngine.MacroState? {
    _macroStates[button]
  }

  public func setMacroState(_ state: MappingEngine.MacroState, for button: String) {
    _macroStates[button] = state
  }

  public func removeMacroState(for button: String) {
    _macroStates.removeValue(forKey: button)
  }

  public func cancelAllMacros() {
    _macroStates.removeAll()
  }

  public func addButtonHistory(button: String) {
    _buttonHistory.append((button, Date()))
    if _buttonHistory.count > 20 {
      _buttonHistory.removeFirst()
    }
  }

  public func getButtonHistory() -> [(button: String, timestamp: Date)] {
    _buttonHistory
  }

  public func getState() -> MappingStoreState {
    MappingStoreState(
      activeMode: _activeMode,
      modeStack: _modeStack,
      activeChord: _activeChord,
      macroStatesCount: _macroStates.count
    )
  }
}

extension MappingStore {
  public struct MappingStoreState: Sendable, Equatable {
    public let activeMode: String
    public let modeStack: [String]
    public let activeChord: Set<String>
    public let macroStatesCount: Int
  }
}
