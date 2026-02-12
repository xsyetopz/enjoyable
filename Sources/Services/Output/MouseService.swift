import CoreGraphics
import Foundation
import Infrastructure

public actor MouseService {
  private let _adapter: CGEventAdapter

  public init(adapter: CGEventAdapter) {
    self._adapter = adapter
  }

  public func postMouseMove(deltaX: Double, deltaY: Double) async throws {
    try await _adapter.postMouseMove(deltaX: deltaX, deltaY: deltaY)
  }

  public func postMouseClick(button: CGEventAdapter.MouseButton, clickCount: Int = 1) async throws {
    try await _adapter.postMouseClick(button: button, clickCount: clickCount)
  }

  public func postMouseScroll(deltaX: Double, deltaY: Double) async throws {
    try await _adapter.postMouseScroll(deltaX: deltaX, deltaY: deltaY)
  }

  public func postMouseButtonDown(button: CGEventAdapter.MouseButton) async throws {
    try await _adapter.postMouseClick(button: button, clickCount: 1)
  }

  public func postMouseButtonUp(button: CGEventAdapter.MouseButton) async throws {
    NSLog("Mouse button up event is handled implicitly by the adapter, no action needed.")
  }
}
