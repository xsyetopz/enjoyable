import Core
import Foundation
import Infrastructure

public actor KeyboardService {
  private let _adapter: CGEventAdapter

  public init(adapter: CGEventAdapter) {
    self._adapter = adapter
  }

  public func postKeyDown(keyCode: UInt16, modifier: KeyModifier) async throws {
    try await _adapter.postKeyDown(keyCode: keyCode, modifier: modifier)
  }

  public func postKeyUp(keyCode: UInt16, modifier: KeyModifier) async throws {
    try await _adapter.postKeyUp(keyCode: keyCode, modifier: modifier)
  }

  public func releaseAllKeys() async throws {
    try await _adapter.releaseAllKeys()
  }

  public func postKeyPress(keyCode: UInt16, modifier: KeyModifier) async throws {
    try await _adapter.postKeyDown(keyCode: keyCode, modifier: modifier)
    try await _adapter.postKeyUp(keyCode: keyCode, modifier: modifier)
  }
}
