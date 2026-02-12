import Configuration
import Core
import SwiftUI

struct ProfileView: View {
  @EnvironmentObject var appState: AppState
  @State private var _showingNewProfileSheet = false
  @State private var _newProfileName = ""
  @State private var _showingDeleteConfirmation = false
  @State private var _profileToDelete: Profile?

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        _profileListHeader

        if appState.profiles.isEmpty {
          _emptyProfilesView
        } else {
          _profileListView
        }

        if let currentProfile = appState.currentProfile {
          _currentProfileEditor(currentProfile)
        }
      }
      .padding(24)
    }
    .sheet(isPresented: $_showingNewProfileSheet) {
      _newProfileSheet
    }
    .alert("Delete Profile", isPresented: $_showingDeleteConfirmation) {
      Button("Cancel", role: .cancel) {
        _profileToDelete = nil
      }
      Button("Delete", role: .destructive) {
        if let profile = _profileToDelete {
          Task {
            await appState.deleteProfile(profile)
          }
        }
        _profileToDelete = nil
      }
    } message: {
      Text("Are you sure you want to delete this profile? This action cannot be undone.")
    }
  }

  private var _profileListHeader: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Profiles")
          .font(.title2.bold())

        Text("\(appState.profiles.count) profile\(appState.profiles.count == 1 ? "" : "s")")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }

      Spacer()

      HStack(spacing: 12) {
        Button(action: {
          Task {
            await appState.saveCurrentProfile()
          }
        }) {
          Label("Export", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.bordered)

        Button(action: {
          _showingNewProfileSheet = true
        }) {
          Label("New Profile", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(.bottom, 8)
  }

  private var _emptyProfilesView: some View {
    VStack(spacing: 16) {
      Image(systemName: "doc.on.doc")
        .font(.system(size: 56))
        .foregroundColor(.secondary)

      Text("No Profiles")
        .font(.title3.bold())

      Text("Create a profile to save your button mappings")
        .font(.body)
        .foregroundColor(.secondary)

      Button(action: {
        _showingNewProfileSheet = true
      }) {
        Label("Create Profile", systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
    .padding(40)
    .frame(maxWidth: .infinity)
    .background(Color(nsColor: .controlBackgroundColor))
    .cornerRadius(12)
  }

  private var _profileListView: some View {
    LazyVStack(spacing: 12) {
      ForEach(appState.profiles) { profile in
        ProfileRowView(
          profile: profile,
          isActive: appState.currentProfile?.id == profile.id,
          onSelect: {
            appState.selectProfile(profile)
          },
          onDelete: {
            _profileToDelete = profile
            _showingDeleteConfirmation = true
          }
        )
      }
    }
  }

  private func _currentProfileEditor(_ profile: Profile) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Profile Settings")
        .font(.headline)

      VStack(spacing: 16) {
        HStack {
          Text("Name")
            .font(.body)
            .frame(width: 80, alignment: .leading)

          TextField(
            "Profile Name",
            text: Binding(
              get: { profile.name },
              set: { newName in
                if var updatedProfile = appState.currentProfile {
                  updatedProfile = updatedProfile.withName(newName)
                  appState.selectProfile(updatedProfile)
                }
              }
            )
          )
          .textFieldStyle(.roundedBorder)
        }

        HStack {
          Text("Device")
            .font(.body)
            .frame(width: 80, alignment: .leading)

          Picker(
            "Device",
            selection: Binding(
              get: {
                appState.selectedDevice.map {
                  USBDeviceID(vendorID: $0.vendorID, productID: $0.productID)
                }
              },
              set: { newDeviceID in
                if var updatedProfile = appState.currentProfile {
                  updatedProfile = updatedProfile.withDeviceID(newDeviceID)
                  appState.selectProfile(updatedProfile)
                }
              }
            )
          ) {
            Text("All Devices").tag(nil as USBDeviceID?)
            ForEach(appState.connectedDevices, id: \.vendorID) { device in
              Text(device.deviceName).tag(
                USBDeviceID(vendorID: device.vendorID, productID: device.productID) as USBDeviceID?
              )
            }
          }
          .pickerStyle(.menu)
        }
      }

      HStack {
        Spacer()

        Button(action: {
          Task {
            await appState.saveCurrentProfile()
          }
        }) {
          Label("Save Profile", systemImage: "square.and.arrow.down")
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(LayoutConstants.Padding.standard)
    .background(ThemeConstants.Colors.controlBackground)
    .cornerRadius(LayoutConstants.CornerRadius.standard)
  }

  private var _newProfileSheet: some View {
    VStack(spacing: 20) {
      Text("New Profile")
        .font(.title2.bold())

      TextField("Profile Name", text: $_newProfileName)
        .textFieldStyle(.roundedBorder)
        .frame(width: 300)

      HStack(spacing: 16) {
        Button("Cancel") {
          _showingNewProfileSheet = false
          _newProfileName = ""
        }
        .keyboardShortcut(.escape)

        Button("Create") {
          let newProfile = Profile(
            name: _newProfileName.isEmpty
              ? "Profile \(appState.profiles.count + 1)" : _newProfileName,
            deviceID: nil,
            buttonMappings: []
          )
          appState.profiles.append(newProfile)
          appState.selectProfile(newProfile)
          _showingNewProfileSheet = false
          _newProfileName = ""
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.return)
      }
    }
    .padding(30)
    .frame(width: 400, height: 200)
  }
}

struct ProfileRowView: View {
  let profile: Profile
  let isActive: Bool
  let onSelect: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(profile.name)
            .font(.headline)

          if isActive {
            Text("Active")
              .font(.caption)
              .fontWeight(.medium)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(ThemeConstants.Accent.opacity20)
              .cornerRadius(8)
          }
        }

        HStack(spacing: 12) {
          Text("\(profile.buttonMappings.count) mappings")
            .font(.caption)
            .foregroundColor(.secondary)

          if let deviceID = profile.deviceID {
            Text("Device: \(deviceID.stringValue)")
              .font(.caption)
              .foregroundColor(.secondary)
          } else {
            Text("All Devices")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }

      Spacer()

      HStack(spacing: 8) {
        Button(action: onSelect) {
          Label(
            isActive ? "Selected" : "Select",
            systemImage: isActive ? "checkmark.circle.fill" : "circle"
          )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Button(action: onDelete) {
          Image(systemName: "trash")
            .font(.body)
        }
        .buttonStyle(.borderless)
        .foregroundColor(.red)
      }
    }
    .padding(LayoutConstants.Padding.standard)
    .background(
      isActive ? ThemeConstants.Accent.opacity08 : ThemeConstants.Colors.controlBackground
    )
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(
          isActive ? Color.accentColor : ThemeConstants.Selection.grayStroke,
          lineWidth: isActive
            ? ThemeConstants.Selection.strokeWidth : ThemeConstants.Selection.strokeWidthSmall
        )
    )
  }
}
