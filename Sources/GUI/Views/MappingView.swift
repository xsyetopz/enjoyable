import Core
import SwiftUI

struct MappingView: View {
  @EnvironmentObject var _appState: AppState
  @State private var _selectedButton: String?
  @State private var _recordingButton: String?
  @State private var _searchText: String = ""
  @State private var _showingDetail: Bool = false

  private let _standardButtons = GamepadConstants.Button.allNames

  var body: some View {
    if #available(macOS 13.0, *) {
      _navigationSplitView
    } else {
      _legacyLayout
    }
  }

  @available(macOS 13.0, *)
  private var _navigationSplitView: some View {
    NavigationSplitView {
      _sidebar
    } detail: {
      _detailContent
    }
    .navigationSplitViewStyle(.balanced)
    .onChange(of: _selectedButton) { newValue in
      if newValue != nil {
        _showingDetail = true
      }
    }
  }

  private var _legacyLayout: some View {
    HStack(spacing: 0) {
      _sidebar
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

      Divider()

      _detailContent
        .frame(minWidth: 300)
    }
    .padding(16)
  }

  private var _sidebar: some View {
    VStack(spacing: 0) {
      if _appState.selectedDevice == nil {
        _noDeviceSelectedView
      } else {
        MappingListView(
          buttons: _standardButtons,
          selectedButton: _selectedButton,
          recordingButton: _recordingButton,
          searchText: _searchText,
          onSelect: { button in
            _startRecording(for: button)
          },
          onEdit: { button in
            _selectedButton = button
            _showingDetail = true
          }
        )
      }
    }
    .padding(16)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var _noDeviceSelectedView: some View {
    VStack(spacing: 16) {
      Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
        .font(.system(size: 48))
        .foregroundColor(.secondary)

      Text("No Device Selected")
        .font(.headline)

      Text("Select a device from the Devices tab to configure button mappings")
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      Button(action: {
        _appState.selectedTab = .devices
      }) {
        Label("Select Device", systemImage: "gamecontroller")
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.regular)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .controlBackgroundColor))
    .cornerRadius(12)
  }

  @ViewBuilder
  private var _detailContent: some View {
    if let button = _selectedButton, _showingDetail {
      MappingDetailView(
        button: button,
        mapping: _mapping(for: button),
        onSave: { mapping in
          _saveMapping(mapping)
          _showingDetail = false
        },
        onDelete: {
          _deleteMapping(for: button)
          _showingDetail = false
        },
        onCancel: {
          _showingDetail = false
        }
      )
    } else {
      _emptyDetailView
    }
  }

  private var _emptyDetailView: some View {
    VStack(spacing: 16) {
      Image(systemName: "hand.tap")
        .font(.system(size: 48))
        .foregroundColor(.secondary)

      Text("Select a Button")
        .font(.headline)

      Text("Choose a button from the list to edit its key mapping")
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .controlBackgroundColor))
    .cornerRadius(12)
  }

  private func _mapping(for button: String) -> ButtonMapping? {
    _appState.currentProfile?.buttonMappings.first { $0.buttonIdentifier == button }
  }

  private func _startRecording(for button: String) {
    _recordingButton = button
  }

  private func _saveMapping(_ mapping: ButtonMapping) {
    guard let profile = _appState.currentProfile else { return }
    var mappings = profile.buttonMappings

    if let index = mappings.firstIndex(where: { $0.buttonIdentifier == mapping.buttonIdentifier }) {
      mappings[index] = mapping
    } else {
      mappings.append(mapping)
    }

    let updatedProfile = profile.withButtonMappings(mappings)
    _appState.currentProfile = updatedProfile

    Task {
      await _appState.saveCurrentProfile()
    }

    _recordingButton = nil
  }

  private func _deleteMapping(for button: String) {
    guard let profile = _appState.currentProfile else { return }
    let mappings = profile.buttonMappings.filter { $0.buttonIdentifier != button }

    let updatedProfile = profile.withButtonMappings(mappings)
    _appState.currentProfile = updatedProfile

    Task {
      await _appState.saveCurrentProfile()
    }

    _recordingButton = nil
  }
}

struct MappingView_Previews: PreviewProvider {
  static var previews: some View {
    MappingView()
      .environmentObject(AppState())
      .frame(width: 600, height: 400)
  }
}
