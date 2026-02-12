import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var appState: AppState

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        _generalSettingsSection
        _appearanceSettingsSection
        _behaviorSettingsSection
        _aboutSection
      }
      .padding(24)
    }
  }

  private var _generalSettingsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("General", systemImage: "gearshape")
        .font(.title2.bold())

      VStack(spacing: 0) {
        ToggleRow(
          title: "Start at Login",
          description: "Launch Enjoyable when you log in to your computer",
          isOn: appState.startAtLogin,
          onToggle: { appState.setStartAtLogin($0) }
        )

        Divider()
          .padding(.leading)

        ToggleRow(
          title: "Show Notifications",
          description: "Display notifications for device connections and disconnections",
          isOn: appState.showNotifications,
          onToggle: { value in
            appState.showNotifications = value
            appState.saveSettings()
          }
        )

        Divider()
          .padding(.leading)

        ToggleRow(
          title: "Minimize to Tray",
          description: "When closing the window, minimize to the menu bar instead of quitting",
          isOn: appState.minimizeToTray,
          onToggle: { value in
            appState.minimizeToTray = value
            appState.saveSettings()
          }
        )
      }
      .background(Color(nsColor: .controlBackgroundColor))
      .cornerRadius(12)
    }
  }

  private var _appearanceSettingsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Appearance", systemImage: "paintbrush")
        .font(.title2.bold())

      VStack(spacing: 0) {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Theme")
              .font(.body)
            Text("Choose how Enjoyable appears on your system")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Spacer()

          HStack(spacing: 0) {
            ForEach(AppearanceMode.allCases) { mode in
              Button(action: {
                appState.appearanceMode = mode
                appState.saveSettings()
              }) {
                Text(mode.displayName)
                  .font(.caption)
                  .fontWeight(appState.appearanceMode == mode ? .semibold : .regular)
                  .foregroundColor(appState.appearanceMode == mode ? .primary : .secondary)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(
                    RoundedRectangle(cornerRadius: 6)
                      .fill(
                        appState.appearanceMode == mode
                          ? Color(nsColor: .controlAccentColor).opacity(0.2) : Color.clear
                      )
                  )
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding()
      }
      .background(Color(nsColor: .controlBackgroundColor))
      .cornerRadius(12)
    }
  }

  private var _behaviorSettingsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Behavior", systemImage: "slider.horizontal.3")
        .font(.title2.bold())

      VStack(spacing: 0) {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Device Refresh Rate")
              .font(.body)
            Text("How often to check for connected devices")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Spacer()

          Text("0.1s")
            .font(.body)
            .foregroundColor(.secondary)
        }
        .padding()

        Divider()
          .padding(.leading)

        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Auto-connect")
              .font(.body)
            Text("Automatically connect to known devices when they are plugged in")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Spacer()

          Toggle("", isOn: .constant(true))
            .labelsHidden()
        }
        .padding()
      }
      .background(Color(nsColor: .controlBackgroundColor))
      .cornerRadius(12)
    }
  }

  private var _aboutSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("About", systemImage: "info.circle")
        .font(.title2.bold())

      VStack(spacing: 0) {
        HStack {
          Text("Version")
            .font(.body)

          Spacer()

          Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            .font(.body)
            .foregroundColor(.secondary)
        }
        .padding()

        Divider()
          .padding(.leading)

        HStack {
          Text("Build")
            .font(.body)

          Spacer()

          Text(_buildNumber)
            .font(.body)
            .foregroundColor(.secondary)
        }
        .padding()
      }
      .background(Color(nsColor: .controlBackgroundColor))
      .cornerRadius(12)
    }
  }

  private var _buildNumber: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyMMdd.HHmm"
    return formatter.string(from: Date())
  }
}

extension AppearanceMode {
  var displayName: String {
    switch self {
    case .system: return "System"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }
}

struct ToggleRow: View {
  let title: String
  let description: String
  let isOn: Bool
  let onToggle: (Bool) -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Toggle(
        "",
        isOn: Binding(
          get: { isOn },
          set: { onToggle($0) }
        )
      )
      .toggleStyle(.switch)
      .controlSize(.regular)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.body)
        Text(description)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .fixedSize(horizontal: false, vertical: true)

      Spacer()
    }
    .padding()
  }
}
