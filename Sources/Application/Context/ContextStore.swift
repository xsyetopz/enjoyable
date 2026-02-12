import AppKit
import Foundation

public actor ContextStore {
  private var _currentContext: AppContext?
  private var _contextHistory: [AppContext]
  private let _maxHistorySize: Int

  public init(maxHistorySize: Int = 20) {
    self._contextHistory = []
    self._maxHistorySize = maxHistorySize
  }

  public func getCurrentContext() -> AppContext? {
    _currentContext
  }

  public func updateContext(_ context: AppContext) {
    _currentContext = context
    _addToHistory(context)
  }

  public func getContextHistory() -> [AppContext] {
    _contextHistory
  }

  public func getContext(for bundleIdentifier: String) -> AppContext? {
    _contextHistory.first { $0.bundleIdentifier == bundleIdentifier }
  }

  public func clearHistory() {
    _contextHistory.removeAll()
  }

  private func _addToHistory(_ context: AppContext) {
    _contextHistory.append(context)
    if _contextHistory.count > _maxHistorySize {
      _contextHistory.removeFirst()
    }
  }
}

extension ContextStore {
  public struct AppContext: Sendable, Equatable {
    public let bundleIdentifier: String?
    public let processIdentifier: pid_t
    public let name: String
    public let isActive: Bool
    public let timestamp: Date

    public init(
      bundleIdentifier: String?,
      processIdentifier: pid_t,
      name: String,
      isActive: Bool,
      timestamp: Date = Date()
    ) {
      self.bundleIdentifier = bundleIdentifier
      self.processIdentifier = processIdentifier
      self.name = name
      self.isActive = isActive
      self.timestamp = timestamp
    }

    public static func from(_ app: NSRunningApplication?) -> AppContext {
      AppContext(
        bundleIdentifier: app?.bundleIdentifier,
        processIdentifier: app?.processIdentifier ?? 0,
        name: app?.localizedName ?? "Unknown",
        isActive: app?.isActive ?? false
      )
    }
  }
}
