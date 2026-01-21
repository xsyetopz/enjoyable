import AppKit
import CoreGraphics
import Foundation

final class EventSynthesizer: Sendable {
  func synthesizeKeyDown(keyCode: KeyCode, flags: UInt64 = 0) throws {
    guard AXIsProcessTrusted() else {
      throw OutputError.accessibilityPermissionDenied
    }

    let cgKeyCode = CGKeyCode(keyCode)
    let keyDown = CGEvent(
      keyboardEventSource: nil,
      virtualKey: cgKeyCode,
      keyDown: true
    )
    keyDown?.flags = .init(rawValue: flags)
    keyDown?.post(tap: .cghidEventTap)
  }

  func synthesizeKeyUp(keyCode: KeyCode, flags: UInt64 = 0) throws {
    guard AXIsProcessTrusted() else {
      throw OutputError.accessibilityPermissionDenied
    }

    let cgKeyCode = CGKeyCode(keyCode)
    let keyUp = CGEvent(
      keyboardEventSource: nil,
      virtualKey: cgKeyCode,
      keyDown: false
    )
    keyUp?.flags = .init(rawValue: flags)
    keyUp?.post(tap: .cghidEventTap)
  }

  func synthesizeKeyPress(keyCode: KeyCode, flags: UInt64 = 0) throws {
    guard AXIsProcessTrusted() else {
      throw OutputError.accessibilityPermissionDenied
    }

    let cgKeyCode = CGKeyCode(keyCode)

    let keyDown = CGEvent(
      keyboardEventSource: nil,
      virtualKey: cgKeyCode,
      keyDown: true
    )
    let keyUp = CGEvent(
      keyboardEventSource: nil,
      virtualKey: cgKeyCode,
      keyDown: false
    )

    keyDown?.flags = .init(rawValue: flags)
    keyUp?.flags = .init(rawValue: flags)

    keyDown?.post(tap: .cghidEventTap)
    usleep(16000)
    keyUp?.post(tap: .cghidEventTap)
  }

  func synthesizeKeyRelease(keyCode: KeyCode) throws {
    let cgKeyCode = CGKeyCode(keyCode)

    let keyUp = CGEvent(
      keyboardEventSource: nil,
      virtualKey: cgKeyCode,
      keyDown: false
    )

    keyUp?.post(tap: .cghidEventTap)
  }

  func synthesizeMouseMove(x: CGFloat, y: CGFloat) throws {
    guard AXIsProcessTrusted() else {
      throw OutputError.accessibilityPermissionDenied
    }

    let location = CGPoint(x: x, y: y)

    let mouseMove = CGEvent(
      mouseEventSource: nil,
      mouseType: .mouseMoved,
      mouseCursorPosition: location,
      mouseButton: .left
    )

    mouseMove?.post(tap: .cghidEventTap)
  }

  func synthesizeMouseButton(button: UInt32, state: UInt32) throws {
    guard AXIsProcessTrusted() else {
      throw OutputError.accessibilityPermissionDenied
    }

    let eventType: CGEventType = state == 1 ? .leftMouseDown : .leftMouseUp

    let mouseEvent = CGEvent(
      mouseEventSource: nil,
      mouseType: eventType,
      mouseCursorPosition: .zero,
      mouseButton: .left
    )

    mouseEvent?.post(tap: .cghidEventTap)
  }

  func synthesizeMouseScroll(deltaX: CGFloat, deltaY: CGFloat) throws {
    guard AXIsProcessTrusted() else {
      throw OutputError.accessibilityPermissionDenied
    }

    let wheel1 = Int32(deltaY)
    let wheel2 = Int32(deltaX)

    let scrollEvent = CGEvent(
      scrollWheelEvent2Source: nil,
      units: .pixel,
      wheelCount: 1,
      wheel1: wheel1,
      wheel2: wheel2,
      wheel3: 0
    )

    scrollEvent?.post(tap: .cghidEventTap)
  }
}
