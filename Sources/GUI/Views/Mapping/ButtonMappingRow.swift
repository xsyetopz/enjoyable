import Core
import SwiftUI

struct ButtonMappingRow: View {
  let button: String
  let mapping: ButtonMapping?
  let isSelected: Bool
  let isRecording: Bool
  let onEdit: () -> Void

  @EnvironmentObject var viewModel: MappingViewModel
  @State private var _isHovered = false

  private var _isPressed: Bool {
    viewModel.buttonStates[button] ?? false
  }

  var body: some View {
    HStack(spacing: 0) {
      _buttonLabel

      _mappingDisplay
        .frame(maxWidth: .infinity, alignment: .leading)

      _editButton
        .frame(width: 60)
        .padding(.trailing, 16)
        .opacity(_isHovered || isSelected ? 1.0 : 0.0)
    }
    .frame(height: 48)
    .background(_backgroundColor)
    .contentShape(Rectangle())
    .onHover { hovering in
      _isHovered = hovering
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(button) mapping")
    .accessibilityValue(_accessibilityValue)
  }

  private var _buttonLabel: some View {
    Text(button)
      .font(.system(size: 13, weight: .medium))
      .foregroundColor(_isPressed ? .primary : .primary)
      .frame(width: 100, alignment: .leading)
      .padding(.leading, 16)
      .padding(.vertical, 14)
  }

  private var _mappingDisplay: some View {
    HStack(spacing: 6) {
      if let mapping = mapping {
        _modifierBadge(modifier: mapping.modifier)
        _keyBadge(keyCode: mapping.keyCode)
      } else {
        _emptyMappingView
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }

  private var _emptyMappingView: some View {
    HStack(spacing: 0) {
      Text("Click to set")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.secondary)

      Spacer()
    }
  }

  private var _editButton: some View {
    Button(action: onEdit) {
      Image(systemName: isRecording ? "record.circle.fill" : "pencil.circle")
        .font(.system(size: 14))
        .foregroundColor(isRecording ? .orange : (_isPressed ? .white : .secondary))
        .frame(width: 28, height: 28)
        .background(
          isRecording
            ? Color.orange.opacity(0.2)
            : (_isPressed ? Color.accentColor : Color.secondary.opacity(0.1))
        )
        .cornerRadius(6)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Edit \(button) mapping")
  }

  private var _backgroundColor: Color {
    if isRecording {
      return Color.orange.opacity(0.08)
    } else if isSelected {
      return Color.accentColor.opacity(0.08)
    } else {
      return Color.clear
    }
  }

  private var _accessibilityValue: String {
    if let mapping = mapping {
      let modifierText = _modifierText(mapping.modifier)
      let keyText = _keyCodeText(mapping.keyCode)
      if modifierText.isEmpty {
        return "Mapped to \(keyText)"
      } else {
        return "Mapped to \(modifierText) plus \(keyText)"
      }
    } else {
      return "Not mapped"
    }
  }

  private func _modifierBadge(modifier: KeyModifier) -> some View {
    Text(_modifierText(modifier))
      .font(.system(size: 10, weight: .semibold))
      .foregroundColor(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(Color(nsColor: .labelColor))
      .cornerRadius(5)
  }

  private func _keyBadge(keyCode: UInt16) -> some View {
    Text(_keyCodeText(keyCode))
      .font(.system(size: 11, weight: .medium))
      .foregroundColor(.primary)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(Color(nsColor: .textBackgroundColor))
      .cornerRadius(5)
      .overlay(
        RoundedRectangle(cornerRadius: 5)
          .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
      )
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
