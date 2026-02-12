import Foundation

public actor DriverStateManager {
  private var _currentState: DriverState
  private var _stateChangeHandlers: [(DriverState) -> Void]
  private var _errorHistory: [String]
  private let _maxErrorHistory: Int

  public init(initialState: DriverState = .stopped) {
    self._currentState = initialState
    self._stateChangeHandlers = []
    self._errorHistory = []
    self._maxErrorHistory = 10
  }

  public func getState() -> DriverState {
    _currentState
  }

  public func transition(to newState: DriverState) -> Bool {
    guard _canTransition(to: newState) else {
      return false
    }

    let previousState = _currentState
    _currentState = newState
    _notifyStateChangeHandlers(newState: newState)

    if case .error(let message) = newState {
      _recordError(message)
    }

    return true
  }

  public func addStateChangeHandler(_ handler: @escaping (DriverState) -> Void) {
    _stateChangeHandlers.append(handler)
  }

  public func removeStateChangeHandler(at index: Int) {
    guard index < _stateChangeHandlers.count else { return }
    _stateChangeHandlers.remove(at: index)
  }

  public func getErrorHistory() -> [String] {
    _errorHistory
  }

  public func clearErrorHistory() {
    _errorHistory.removeAll()
  }

  private func _canTransition(to newState: DriverState) -> Bool {
    switch (_currentState, newState) {
    case (.stopped, .starting),
      (.starting, .running),
      (.running, .pausing),
      (.pausing, .paused),
      (.paused, .running),
      (.running, .stopping),
      (.stopping, .stopped),
      (_, .error):
      return true
    case (.error, .starting):
      return true
    default:
      return false
    }
  }

  private func _notifyStateChangeHandlers(newState: DriverState) {
    for handler in _stateChangeHandlers {
      handler(newState)
    }
  }

  private func _recordError(_ message: String) {
    _errorHistory.append(message)
    if _errorHistory.count > _maxErrorHistory {
      _errorHistory.removeFirst()
    }
  }
}

extension DriverStateManager {
  public enum StateError: LocalizedError {
    case invalidTransition(from: DriverState, to: DriverState)
    case operationNotAllowed

    public var errorDescription: String? {
      switch self {
      case .invalidTransition(let from, let to):
        return "Cannot transition from \(String(describing: from)) to \(String(describing: to))"
      case .operationNotAllowed:
        return "Operation not allowed in current state"
      }
    }
  }
}
