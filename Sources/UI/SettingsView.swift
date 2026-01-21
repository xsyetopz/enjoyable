import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var settings: SettingsWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Settings")
        .font(.title)
        .fontWeight(.bold)
        .padding(.bottom, 10)

      Divider()

      generalSection

      Divider()

      virtualGamepadSection

      Divider()

      developerModeSection
    }
    .padding(20)
    .frame(
      width: Constants.WindowDimensions.settingsWidth,
      height: Constants.WindowDimensions.settingsHeight
    )
  }

  private var generalSection: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("General")
        .font(.headline)
        .padding(.bottom, 5)

      Toggle("Launch at login", isOn: $settings.launchAtLogin)

      Toggle("Show connection notifications", isOn: $settings.showConnectionNotifications)
    }
    .padding(.vertical, 10)
  }

  private var virtualGamepadSection: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("Virtual Gamepad")
        .font(.headline)
        .padding(.bottom, 5)

      Toggle("Passthrough Mode", isOn: $settings.passthroughMode)

      Text(
        "When enabled, physical controller works natively (no virtual gamepad). When disabled, inputs are routed thru virtual gamepad for compatibility."
      )
      .font(.caption)
      .foregroundColor(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 10)
  }

  private var developerModeSection: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("Developer Mode")
        .font(.headline)
        .padding(.bottom, 5)

      Toggle("Enable Developer Mode", isOn: $settings.developerModeEnabled)

      Text(
        "Warning: Shows advanced tools for debugging controllers. Only enable if you are contributing controller support."
      )
      .font(.caption)
      .foregroundColor(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 10)
  }
}
