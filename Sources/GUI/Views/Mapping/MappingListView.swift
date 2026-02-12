import Core
import SwiftUI

struct MappingListView: View {
  let buttons: [String]
  let selectedButton: String?
  let recordingButton: String?
  let searchText: String
  let onSelect: (String) -> Void
  let onEdit: (String) -> Void

  @EnvironmentObject var appState: AppState

  private var _filteredButtons: [String] {
    if searchText.isEmpty {
      return buttons
    }
    return buttons.filter { $0.localizedCaseInsensitiveContains(searchText) }
  }

  private var _mappedButtons: Set<String> {
    Set(appState.currentProfile?.buttonMappings.map { $0.buttonIdentifier } ?? [])
  }

  var body: some View {
    VStack(spacing: 0) {
      _searchField

      Divider()

      _tableHeader

      _buttonList
    }
    .background(Color(nsColor: .controlBackgroundColor))
    .cornerRadius(12)
  }

  private var _searchField: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundColor(.secondary)

      TextField("Search buttons", text: .constant(searchText))
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .disabled(true)

      if !searchText.isEmpty {
        Button(action: {}) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color(nsColor: .textBackgroundColor))
    .cornerRadius(8)
    .padding(12)
  }

  private var _tableHeader: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        Text("Button")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(.secondary)
          .frame(width: 100, alignment: .leading)
          .padding(.leading, 16)
          .padding(.vertical, 10)

        Text("Mapped To")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.vertical, 10)

        Text("")
          .frame(width: 60)
          .padding(.trailing, 16)
      }
      .background(Color(nsColor: .controlBackgroundColor))

      Divider()
        .frame(height: 0.5)
        .background(Color.secondary.opacity(0.2))
    }
  }

  private var _buttonList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(_filteredButtons, id: \.self) { button in
          ButtonMappingRow(
            button: button,
            mapping: _mapping(for: button),
            isSelected: selectedButton == button,
            isRecording: recordingButton == button,
            onEdit: { onEdit(button) }
          )
          .onTapGesture {
            if recordingButton == nil {
              onSelect(button)
            }
          }

          if button != _filteredButtons.last {
            Divider()
              .frame(height: 0.5)
              .background(Color.secondary.opacity(0.2))
          }
        }
      }
    }
    .frame(minHeight: 200)
  }

  private func _mapping(for button: String) -> ButtonMapping? {
    appState.currentProfile?.buttonMappings.first { $0.buttonIdentifier == button }
  }
}

struct MappingListView_Previews: PreviewProvider {
  static var previews: some View {
    MappingListView(
      buttons: GamepadConstants.Button.allNames,
      selectedButton: nil,
      recordingButton: nil,
      searchText: "",
      onSelect: { _ in },
      onEdit: { _ in }
    )
    .environmentObject(AppState())
    .frame(width: 320, height: 400)
    .padding()
  }
}
