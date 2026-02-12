import Core
import SwiftUI

struct MappingDetailView: View {
  let button: String
  let mapping: ButtonMapping?
  let onSave: (ButtonMapping) -> Void
  let onDelete: () -> Void
  let onCancel: () -> Void

  @State private var _isRecording: Bool = false
  @State private var _currentKeyCode: UInt16
  @State private var _currentModifier: KeyModifier

  init(
    button: String,
    mapping: ButtonMapping?,
    onSave: @escaping (ButtonMapping) -> Void,
    onDelete: @escaping () -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.button = button
    self.mapping = mapping
    self.onSave = onSave
    self.onDelete = onDelete
    self.onCancel = onCancel

    __currentKeyCode = State(initialValue: mapping?.keyCode ?? 0)
    __currentModifier = State(initialValue: mapping?.modifier ?? .none)
  }

  var body: some View {
    VStack(spacing: 0) {
      _header

      Divider()

      _content
    }
    .background(Color(nsColor: .controlBackgroundColor))
    .cornerRadius(12)
  }

  private var _header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(button)
          .font(.title3.bold())

        if let mapping = mapping {
          Text("Currently mapped to \(_keyCombinationText(mapping))")
            .font(.caption)
            .foregroundColor(.secondary)
        } else {
          Text("Not mapped")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      Button(action: onCancel) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 20))
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(20)
  }

  private var _content: some View {
    VStack(spacing: 20) {
      if _isRecording {
        KeyRecorderView(
          buttonName: button,
          onComplete: { keyCode, modifier in
            _currentKeyCode = keyCode
            _currentModifier = modifier
            _isRecording = false
          },
          onCancel: {
            _isRecording = false
          }
        )
      } else {
        _recordingSection

        _modifierSection

        _previewSection

        _actionsSection
      }
    }
    .padding(20)
  }

  private var _recordingSection: some View {
    VStack(spacing: 12) {
      Text("Record a key")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button(action: {
        _isRecording = true
      }) {
        HStack {
          Image(systemName: "record.circle")
            .font(.system(size: 16))

          Text("Record New Key")
            .font(.system(size: 14, weight: .medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.accentColor)
        .foregroundColor(.white)
        .cornerRadius(8)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Record new key for \(button)")
    }
  }

  private var _modifierSection: some View {
    VStack(spacing: 12) {
      Text("Modifier")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 8) {
        ForEach([KeyModifier.command, .control, .option, .shift], id: \.self) { modifier in
          _modifierButton(modifier)
        }
      }
    }
  }

  private func _modifierButton(_ modifier: KeyModifier) -> some View {
    Button(action: {
      if _currentModifier == modifier {
        _currentModifier = .none
      } else {
        _currentModifier = modifier
      }
    }) {
      Text(_modifierText(modifier))
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(_currentModifier == modifier ? .white : .primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
          _currentModifier == modifier ? Color.accentColor : Color(nsColor: .textBackgroundColor)
        )
        .cornerRadius(6)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(
              _currentModifier == modifier ? Color.accentColor : Color.secondary.opacity(0.3),
              lineWidth: 1
            )
        )
    }
    .buttonStyle(.plain)
  }

  private var _previewSection: some View {
    VStack(spacing: 12) {
      Text("Preview")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 8) {
        if _currentModifier != .none {
          _modifierBadge(_currentModifier)
        }

        if _currentKeyCode != 0 {
          _keyBadge(_currentKeyCode)
        } else {
          Text("No key selected")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var _actionsSection: some View {
    HStack(spacing: 12) {
      Button(action: onDelete) {
        Text("Delete")
          .font(.system(size: 14, weight: .medium))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(Color.red.opacity(0.1))
          .foregroundColor(.red)
          .cornerRadius(8)
      }
      .buttonStyle(.plain)
      .disabled(_currentKeyCode == 0 && mapping == nil)

      Button(action: {
        let newMapping = ButtonMapping(
          buttonIdentifier: button,
          keyCode: _currentKeyCode,
          modifier: _currentModifier
        )
        onSave(newMapping)
      }) {
        Text("Save")
          .font(.system(size: 14, weight: .medium))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(Color.accentColor)
          .foregroundColor(.white)
          .cornerRadius(8)
      }
      .buttonStyle(.plain)
      .disabled(_currentKeyCode == 0)
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

  private func _keyCombinationText(_ mapping: ButtonMapping) -> String {
    let modifierText = _modifierText(mapping.modifier)
    let keyText = _keyCodeText(mapping.keyCode)
    if modifierText.isEmpty {
      return keyText
    } else {
      return "\(modifierText) + \(keyText)"
    }
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
