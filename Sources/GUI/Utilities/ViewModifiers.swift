import Configuration
import SwiftUI

extension View {
  func cardStyle() -> some View {
    self
      .padding(16)
      .background(Color(nsColor: .controlBackgroundColor))
      .cornerRadius(12)
  }

  func sectionHeader() -> some View {
    self
      .font(.headline)
      .padding(.bottom, 8)
  }
}

extension View {
  func primaryButton() -> some View {
    self
      .buttonStyle(.borderedProminent)
      .controlSize(.regular)
  }

  func secondaryButton() -> some View {
    self
      .buttonStyle(.bordered)
      .controlSize(.regular)
  }

  func iconButton() -> some View {
    self
      .buttonStyle(.borderless)
      .foregroundColor(.secondary)
  }
}

extension View {
  func titleStyle() -> some View {
    self
      .font(.title2.bold())
      .foregroundColor(.primary)
  }

  func subtitleStyle() -> some View {
    self
      .font(.subheadline)
      .foregroundColor(.secondary)
  }
}

extension View {
  func listRowStyle() -> some View {
    self
      .padding(.vertical, 8)
      .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
  }
}

extension View {
  func smoothFade() -> some View {
    self
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.2), value: true)
  }

  func scaleOnTap() -> some View {
    self
      .scaleEffect(0.95)
      .animation(.easeInOut(duration: 0.1), value: false)
  }
}

extension View {
  func focusRing() -> some View {
    self
  }
}

extension View {
  func hoverEffect() -> some View {
    self
      .onHover { hovering in
        if hovering {
          NSCursor.pointingHand.push()
        } else {
          NSCursor.pop()
        }
      }
  }
}

extension View {
  @ViewBuilder
  func ifLet<T>(_ value: T?, transform: (Self, T) -> some View) -> some View {
    if let value = value {
      transform(self, value)
    } else {
      self
    }
  }

  @ViewBuilder
  func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }
}

#if DEBUG
@MainActor
struct PreviewHelpers {
  static func mockAppState() -> AppState {
    let state = AppState()
    state.profiles = [
      Profile(name: "Default", deviceID: nil, buttonMappings: []),
      Profile(name: "Gaming", deviceID: nil, buttonMappings: []),
    ]
    state.currentProfile = state.profiles.first
    return state
  }
}
#endif
