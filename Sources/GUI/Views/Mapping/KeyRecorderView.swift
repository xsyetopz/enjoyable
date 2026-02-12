import Core
import SwiftUI

struct KeyRecorderView: View {
  let buttonName: String
  let onComplete: (UInt16, KeyModifier) -> Void
  let onCancel: () -> Void

  @State private var _recordedKeyCode: UInt16 = 0
  @State private var _recordedModifier: KeyModifier = .none
  @State private var _timeRemainingSeconds: Int = 5
  @State private var _keyEventMonitor: Any?
  @State private var _recordingTimer: Timer?

  var body: some View {
    VStack(spacing: 16) {
      _recordingPrompt

      _keyCombinationDisplay

      _instructions
    }
    .padding(24)
    .background(Color(nsColor: .controlBackgroundColor))
    .cornerRadius(12)
    .onAppear {
      _startRecording()
    }
    .onDisappear {
      _stopRecording()
    }
  }

  private var _recordingPrompt: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(Color.orange)
        .frame(width: 10, height: 10)

      Text("Press any key for \(buttonName)")
        .font(.headline)
        .foregroundColor(.primary)
    }
  }

  private var _keyCombinationDisplay: some View {
    HStack(spacing: 8) {
      if _recordedModifier != .none {
        _modifierBadge(_recordedModifier)
      }

      if _recordedKeyCode != 0 {
        _keyBadge(_recordedKeyCode)
      } else {
        Text("Press a key...")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.secondary)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color(nsColor: .textBackgroundColor))
          .cornerRadius(6)
      }
    }
    .padding(.vertical, 8)
  }

  private var _instructions: some View {
    VStack(spacing: 4) {
      Text("Press Escape to cancel")
        .font(.caption)
        .foregroundColor(.secondary)

      Text("Time remaining: \(_timeRemainingSeconds)s")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  private func _modifierBadge(_ modifier: KeyModifier) -> some View {
    Text(_modifierText(modifier))
      .font(.system(size: 12, weight: .semibold))
      .foregroundColor(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color(nsColor: .labelColor))
      .cornerRadius(6)
  }

  private func _keyBadge(_ keyCode: UInt16) -> some View {
    Text(_keyCodeText(keyCode))
      .font(.system(size: 14, weight: .medium))
      .foregroundColor(.primary)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Color(nsColor: .textBackgroundColor))
      .cornerRadius(6)
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
      )
  }

  private func _startRecording() {
    _timeRemainingSeconds = 5

    _keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
      _handleKeyEvent(event)
      return nil
    }

    _recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      DispatchQueue.main.async {
        if self._timeRemainingSeconds > 0 {
          self._timeRemainingSeconds -= 1
        } else {
          _stopRecording()
          onCancel()
        }
      }
    }
  }

  private func _stopRecording() {
    if let monitor = _keyEventMonitor {
      NSEvent.removeMonitor(monitor)
      _keyEventMonitor = nil
    }
    _recordingTimer?.invalidate()
    _recordingTimer = nil
  }

  private func _handleKeyEvent(_ event: NSEvent) {
    if event.keyCode == 53 {
      _stopRecording()
      onCancel()
      return
    }

    let modifier = _modifierFromNSEvent(event)

    if event.keyCode != 0 {
      _recordedKeyCode = event.keyCode
      _recordedModifier = modifier

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        _stopRecording()
        onComplete(_recordedKeyCode, _recordedModifier)
      }
    }
  }

  private func _modifierFromNSEvent(_ event: NSEvent) -> KeyModifier {
    let flags = event.modifierFlags
    if flags.contains(.command) {
      return .command
    }
    if flags.contains(.control) {
      return .control
    }
    if flags.contains(.option) {
      return .option
    }
    if flags.contains(.shift) {
      return .shift
    }
    return .none
  }

  private func _modifierText(_ modifier: KeyModifier) -> String {
    switch modifier {
    case .none:
      return ""
    case .command:
      return "⌘"
    case .control:
      return "⌃"
    case .option:
      return "⌥"
    case .shift:
      return "⇧"
    }
  }

  private func _keyCodeText(_ keyCode: UInt16) -> String {
    if keyCode == 0 {
      return "None"
    }
    return _keyCodeToString(keyCode)
  }

  private func _keyCodeToString(_ keyCode: UInt16) -> String {
    switch keyCode {
    case 0x00:
      return "A"
    case 0x01:
      return "S"
    case 0x02:
      return "D"
    case 0x03:
      return "F"
    case 0x04:
      return "H"
    case 0x05:
      return "G"
    case 0x06:
      return "Z"
    case 0x07:
      return "X"
    case 0x08:
      return "C"
    case 0x09:
      return "V"
    case 0x0B:
      return "B"
    case 0x0C:
      return "Q"
    case 0x0D:
      return "W"
    case 0x0E:
      return "E"
    case 0x0F:
      return "R"
    case 0x10:
      return "Y"
    case 0x11:
      return "T"
    case 0x12:
      return "1"
    case 0x13:
      return "2"
    case 0x14:
      return "3"
    case 0x15:
      return "4"
    case 0x17:
      return "5"
    case 0x16:
      return "6"
    case 0x1A:
      return "7"
    case 0x1C:
      return "8"
    case 0x19:
      return "9"
    case 0x1D:
      return "0"
    case 0x31:
      return "Space"
    case 0x24:
      return "Return"
    case 0x30:
      return "Tab"
    case 0x35:
      return "Escape"
    case 0x33:
      return "Backspace"
    default:
      return "Key \(keyCode)"
    }
  }
}
