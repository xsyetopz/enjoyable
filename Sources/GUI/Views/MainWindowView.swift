import Core
import SwiftUI

struct MainWindowView: View {
  @EnvironmentObject var appState: AppState

  var body: some View {
    VStack(spacing: 0) {
      _tabBarView
      Divider()
      _contentView
    }
    .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
      Button("OK") {
        appState.dismissError()
      }
    } message: {
      Text(appState.errorMessage ?? "")
    }
    .sheet(isPresented: $appState.showAboutPanel) {
      AboutPanelView()
    }
  }

  private var _tabBarView: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        Spacer()
        ForEach(MainTab.allCases, id: \.self) { tab in
          TabButton(
            tab: tab,
            isSelected: appState.selectedTab == tab,
            action: {
              appState.selectedTab = tab
            }
          )
        }
        Spacer()
      }
      .padding(.horizontal, 24)
      .padding(.top, 16)
      .padding(.bottom, 12)
    }
    .background(Color(nsColor: .controlBackgroundColor))
  }

  private var _contentView: some View {
    Group {
      switch appState.selectedTab {
      case .devices:
        DevicesView()
      case .mapping:
        MappingView()
      case .profiles:
        ProfileView()
      case .settings:
        SettingsView()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

struct TabButton: View {
  let tab: MainTab
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        Image(systemName: tab.systemIcon)
          .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
        Text(tab.rawValue)
          .font(.caption)
          .fontWeight(isSelected ? .semibold : .regular)
      }
      .frame(width: 80)
      .padding(.vertical, 8)
      .background(isSelected ? ThemeConstants.Accent.opacity08 : ThemeConstants.Colors.clear)
      .foregroundColor(isSelected ? .accentColor : .secondary)
      .cornerRadius(8)
    }
    .buttonStyle(.plain)
  }
}

struct AboutPanelView: View {
  @Environment(\.dismiss) private var _dismiss

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "gamecontroller.fill")
        .font(.system(size: 64))
        .foregroundColor(.accentColor)

      Text("Enjoyable")
        .font(.largeTitle.bold())

      Text(
        "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")"
      )
      .font(.subheadline)
      .foregroundColor(.secondary)

      Text("A user-level gamepad driver for macOS")
        .font(.body)
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)

      Divider()

      Text("Configure your gamepads, create profiles, and enhance your gaming experience.")
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      Button("Close") {
        _dismiss()
      }
      .keyboardShortcut(.escape)
    }
    .padding(40)
    .frame(width: 400, height: 350)
  }
}
