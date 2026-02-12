import AppKit
import Foundation

public actor ContextDetector {
  private var _appChangeHandler: ((ContextStore.AppContext?) -> Void)?
  private var _appChangeObserver: (any NSObjectProtocol)?
  private var _pollingTask: Task<Void, Never>?
  private let _pollingInterval: TimeInterval

  public init(pollingInterval: TimeInterval = 1.0) {
    self._pollingInterval = pollingInterval
  }

  public func startDetection(handler: @escaping (ContextStore.AppContext?) -> Void) async {
    _appChangeHandler = handler
    _startAppChangeObserver()
    _startPolling()
    await _notifyCurrentApp()
  }

  public func stopDetection() {
    _stopAppChangeObserver()
    _pollingTask?.cancel()
    _pollingTask = nil
    _appChangeHandler = nil
  }

  public func getCurrentApp() -> NSRunningApplication? {
    NSWorkspace.shared.frontmostApplication
  }

  public func getAllRunningApps() -> [NSRunningApplication] {
    NSWorkspace.shared.runningApplications.filter { app in
      app.bundleIdentifier != nil
    }
  }

  public func waitForAppLaunch(
    bundleIdentifier: String,
    timeout: TimeInterval
  ) async -> NSRunningApplication? {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
      let apps = getAllRunningApps()
      if let app = apps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
        return app
      }
      try? await Task.sleep(nanoseconds: 100_000_000)
    }

    return nil
  }

  private func _startAppChangeObserver() {
    let notificationCenter = NSWorkspace.shared.notificationCenter

    _appChangeObserver = notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let userInfo = notification.userInfo,
        let newApp = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      else { return }

      Task { [weak self] in
        await self?._handleAppChange(app: newApp)
      }
    }
  }

  private func _stopAppChangeObserver() {
    guard let observer = _appChangeObserver else { return }
    NSWorkspace.shared.notificationCenter.removeObserver(observer)
    _appChangeObserver = nil
  }

  private func _startPolling() {
    _pollingTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: UInt64(self?._pollingInterval ?? 1.0 * 1_000_000_000))
        await self?._notifyCurrentApp()
      }
    }
  }

  private func _handleAppChange(app: NSRunningApplication) async {
    let context = ContextStore.AppContext.from(app)
    _appChangeHandler?(context)
  }

  private func _notifyCurrentApp() async {
    let currentApp = getCurrentApp()
    let context = ContextStore.AppContext.from(currentApp)
    _appChangeHandler?(context)
  }
}
