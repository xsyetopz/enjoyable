import Foundation

public actor InputBuffer {
  private var _inputQueue: [QueuedInput] = []
  private var _debounceState: [String: DebounceEntry] = [:]
  private let _maxQueueSize: Int
  private let _debounceInterval: UInt64

  public init(
    maxQueueSize: Int = 100,
    debounceIntervalMs: UInt64 = 10
  ) {
    self._maxQueueSize = maxQueueSize
    self._debounceInterval = debounceIntervalMs * 1_000_000
  }

  public func bufferInput(_ input: InputRouter.ParsedInput) async {
    for inputState in input.inputs {
      let key = "\(input.deviceID.stringValue)_\(inputState.buttonIdentifier)"

      if let existingEntry = _debounceState[key] {
        if await _shouldDebounce(existing: existingEntry, newState: inputState.isPressed) {
          continue
        }
      }

      let entry = DebounceEntry(
        identifier: inputState.buttonIdentifier,
        isPressed: inputState.isPressed,
        timestamp: Date()
      )
      _debounceState[key] = entry

      let queuedInput = QueuedInput(
        input: input,
        timestamp: Date()
      )
      _inputQueue.append(queuedInput)

      if _inputQueue.count > _maxQueueSize {
        _inputQueue.removeFirst()
      }
    }
  }

  public func getNextInput() -> InputRouter.ParsedInput? {
    guard !_inputQueue.isEmpty else {
      return nil
    }

    return _inputQueue.removeFirst().input
  }

  public func clearBuffer() {
    _inputQueue.removeAll()
  }

  public func getQueueCount() -> Int {
    _inputQueue.count
  }

  private func _shouldDebounce(existing: DebounceEntry, newState: Bool) async -> Bool {
    guard existing.isPressed != newState else {
      return false
    }

    let elapsed = Date().timeIntervalSince(existing.timestamp)
    let elapsedNs = UInt64(elapsed * 1_000_000_000)

    return elapsedNs < _debounceInterval
  }
}

private struct DebounceEntry {
  let identifier: String
  let isPressed: Bool
  let timestamp: Date
}

private struct QueuedInput {
  let input: InputRouter.ParsedInput
  let timestamp: Date
}
