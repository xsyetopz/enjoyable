import Core
import SwiftUI

struct MenuBarExtraView: View {
  @EnvironmentObject var appState: AppState

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      _headerSection

      Divider()

      _devicesSection

      Divider()

      _quickActionsSection

      Divider()

      _footerSection
    }
    .frame(width: 250)
  }

  private var _headerSection: some View {
    HStack {
      Image(systemName: "gamecontroller.fill")
        .font(.title2)
        .foregroundColor(.accentColor)

      VStack(alignment: .leading) {
        Text("Enjoyable")
          .font(.headline)

        Text(
          "\(appState.connectedDevices.filter { $0.connectionState == .connected }.count) devices"
        )
        .font(.caption)
        .foregroundColor(.secondary)
      }

      Spacer()

      Button(action: {
        Task {
          await appState.refreshDevices()
        }
      }) {
        Image(systemName: "arrow.clockwise")
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding()
  }

  private var _devicesSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Devices")
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal)

      if appState.connectedDevices.isEmpty {
        Text("No devices connected")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal)
      } else {
        ForEach(appState.connectedDevices.filter { $0.connectionState == .connected }) { device in
          HStack {
            Circle()
              .fill(Color.green)
              .frame(width: 6, height: 6)

            Text(device.deviceName)
              .font(.caption)
              .lineLimit(1)

            Spacer()
          }
          .padding(.horizontal)
        }
      }
    }
    .padding(.vertical, 8)
  }

  private var _quickActionsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Quick Actions")
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal)

      Button(action: {
        appState.selectedTab = .devices
      }) {
        Label("Manage Devices", systemImage: "gamecontroller")
      }
      .buttonStyle(.plain)

      Button(action: {
        appState.selectedTab = .mapping
      }) {
        Label("Configure Mappings", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
      }
      .buttonStyle(.plain)

      Button(action: {
        appState.selectedTab = .profiles
      }) {
        Label("Manage Profiles", systemImage: "doc.on.doc")
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 8)
  }

  private var _footerSection: some View {
    HStack {
      Button(action: {
        appState.showAboutPanel = true
      }) {
        Label("About", systemImage: "info.circle")
      }
      .buttonStyle(.plain)

      Spacer()

      Button(action: {
        NSApp.terminate(nil)
      }) {
        Label("Quit", systemImage: "xmark.circle")
      }
      .buttonStyle(.plain)
    }
    .padding()
  }
}
