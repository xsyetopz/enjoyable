import AppKit
import CoreGraphics
import Foundation
import Infrastructure
import Services
import SwiftUI

nonisolated(unsafe) var sharedUSBDeviceService: USBService?

private func _ensureRunningFromAppBundle() {
  let bundlePath = Bundle.main.bundlePath
  if !bundlePath.hasSuffix(".app") {
    let executablePath = ProcessInfo.processInfo.arguments[0]
    let executableURL = URL(fileURLWithPath: executablePath)
    let appBundleURL = executableURL.deletingLastPathComponent()
      .appendingPathComponent("Enjoyable.app")
    
    if FileManager.default.fileExists(atPath: appBundleURL.path) {
      let task = Process()
      task.launchPath = "/usr/bin/open"
      task.arguments = [appBundleURL.path]
      try? task.run()
      task.waitUntilExit()
      exit(0)
    }
  }
}

@main
struct EnjoyableApp: App {
  @StateObject private var _appState = AppState()

  init() {
    _ensureRunningFromAppBundle()
    SignalHandlers.setup()
  }

  var body: some Scene {
    WindowGroup {
      ThemeAwareView {
        MainWindowView()
      }
      .frame(minWidth: 900, minHeight: 600)
      .environmentObject(_appState)
      .onChange(of: _appState.appearanceMode) { _ in
        _appState.saveSettings()
      }
    }
    .commands {
      CommandGroup(replacing: .appInfo) {
        Button("About Enjoyable") {
          _appState.showAboutPanel = true
        }
        .keyboardShortcut(",")
      }

      CommandGroup(after: .appSettings) {
        Button("Preferences...") {
          _appState.selectedTab = .settings
        }
        .keyboardShortcut(",", modifiers: [.command, .shift])
      }

      CommandGroup(replacing: .newItem) {
        Button("New Profile") {
          _appState.createNewProfile()
        }
        .keyboardShortcut("n")
      }

      CommandGroup(replacing: .saveItem) {
        Button("Save Profile") {
          Task {
            await _appState.saveCurrentProfile()
          }
        }
        .keyboardShortcut("s", modifiers: [.command])
      }

      CommandGroup(replacing: .toolbar) {
        Button(action: {
          Task {
            await _appState.refreshDevices()
          }
        }) {
          Label("Refresh Devices", systemImage: "arrow.clockwise")
        }
        .keyboardShortcut("r")
      }
    }

    Settings {
      SettingsView()
        .environmentObject(_appState)
    }
  }
}

private struct ThemeEnvironmentKey: EnvironmentKey {
  static let defaultValue: AppearanceMode = .system
}

extension EnvironmentValues {
  var themeMode: AppearanceMode {
    get { self[ThemeEnvironmentKey.self] }
    set { self[ThemeEnvironmentKey.self] = newValue }
  }
}

struct ThemeAwareView<Content: View>: View {
  @EnvironmentObject private var _appState: AppState
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .environment(\.themeMode, _appState.appearanceMode)
      .preferredColorScheme(_appState.appearanceMode.colorScheme)
  }
}
