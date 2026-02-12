import Core
import Foundation
@preconcurrency import GameController
import Protocol

public actor GameControllerService {
  private var _controllers: [USBDeviceID: GCController] = [:]
  private var _controllerInputHandlers: [GCController: ControllerInputHandler] = [:]
  private let _eventHandler: @Sendable (GameControllerEvent) -> Void

  public init(
    eventHandler: @escaping @Sendable (GameControllerEvent) -> Void = { _ in }
  ) {
    self._eventHandler = eventHandler
    _setupControllerNotifications()
  }

  private nonisolated func _setupControllerNotifications() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(_controllerDidConnect),
      name: .GCControllerDidConnect,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(_controllerDidDisconnect),
      name: .GCControllerDidDisconnect,
      object: nil
    )
  }

  @objc private nonisolated func _controllerDidConnect(_ notification: Notification) {
    guard let controller = notification.object as? GCController else { return }
    let vendorName = controller.vendorName

    Task {
      await self._handleConnection(vendorName: vendorName, controller: controller)
    }
  }

  private func _handleConnection(vendorName: String?, controller: GCController) async {
    let handler = ControllerInputHandler(controller: controller) { [weak self] event in
      Task {
        await self?._handleControllerInput(event)
      }
    }

    _controllerInputHandlers[controller] = handler

    if let extendedGamepad = controller.extendedGamepad {
      handler.observe(extendedGamepad)
    }

    let event = GameControllerEvent(
      type: .controllerConnected,
      controller: controller,
      message: "GameController device connected: \(vendorName ?? "Unknown")"
    )
    _eventHandler(event)
  }

  @objc private nonisolated func _controllerDidDisconnect(_ notification: Notification) {
    guard let controller = notification.object as? GCController else { return }

    Task {
      await self._handleDisconnection(controller: controller)
    }
  }

  private func _handleDisconnection(controller: GCController) async {
    _controllerInputHandlers.removeValue(forKey: controller)

    for (deviceID, gcController) in _controllers where gcController == controller {
      _controllers.removeValue(forKey: deviceID)
      break
    }

    let event = GameControllerEvent(
      type: .controllerDisconnected,
      controller: controller,
      message: "GameController device disconnected"
    )
    _eventHandler(event)
  }

  public func mapToVirtualDevice(deviceID: USBDeviceID, controller: GCController) {
    _controllers[deviceID] = controller
  }

  public func unmapDevice(deviceID: USBDeviceID) {
    _controllers.removeValue(forKey: deviceID)
  }

  public func getController(for deviceID: USBDeviceID) -> GCController? {
    _controllers[deviceID]
  }

  public func getAllControllers() -> [GCController] {
    Array(_controllers.values)
  }

  public func isControllerConnected(_ deviceID: USBDeviceID) -> Bool {
    _controllers[deviceID] != nil
  }

  private func _handleControllerInput(_ event: ControllerInputEvent) {
    let mappedEvent = GameControllerEvent(
      type: .inputReceived,
      controller: event.controller,
      inputEvent: event.inputEvent,
      message: "Received input from GameController"
    )
    _eventHandler(mappedEvent)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}

private class ControllerInputHandler: @unchecked Sendable {
  private weak var _controller: GCController?
  private let _inputHandler: @Sendable (ControllerInputEvent) -> Void

  init(controller: GCController, inputHandler: @escaping @Sendable (ControllerInputEvent) -> Void) {
    self._controller = controller
    self._inputHandler = inputHandler
  }

  func observe(_ extendedGamepad: GCExtendedGamepad) {
    extendedGamepad.leftTrigger.valueChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleTriggerInput(.left, value: value)
    }

    extendedGamepad.rightTrigger.valueChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleTriggerInput(.right, value: value)
    }

    extendedGamepad.buttonA.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleButtonInput(.a, pressed: pressed)
    }

    extendedGamepad.buttonB.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleButtonInput(.b, pressed: pressed)
    }

    extendedGamepad.buttonX.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleButtonInput(.x, pressed: pressed)
    }

    extendedGamepad.buttonY.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleButtonInput(.y, pressed: pressed)
    }

    extendedGamepad.leftShoulder.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleButtonInput(.leftShoulder, pressed: pressed)
    }

    extendedGamepad.rightShoulder.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleButtonInput(.rightShoulder, pressed: pressed)
    }

    extendedGamepad.leftThumbstickButton?.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleButtonInput(.leftStick, pressed: pressed)
    }

    extendedGamepad.rightThumbstickButton?.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleButtonInput(.rightStick, pressed: pressed)
    }

    extendedGamepad.dpad.up.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleDPadInput(.up, pressed: pressed)
    }

    extendedGamepad.dpad.down.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleDPadInput(.down, pressed: pressed)
    }

    extendedGamepad.dpad.left.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleDPadInput(.left, pressed: pressed)
    }

    extendedGamepad.dpad.right.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleDPadInput(.right, pressed: pressed)
    }

    extendedGamepad.buttonOptions?.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleButtonInput(.back, pressed: pressed)
    }

    extendedGamepad.buttonMenu.pressedChangedHandler = { [weak self] (input: GCControllerButtonInput, value: Float, pressed: Bool) in
      self?._handleButtonInput(.start, pressed: pressed)
    }
  }

  private func _handleButtonInput(_ button: ButtonIdentifier, pressed: Bool) {
    let event = ControllerInputEvent(
      controller: _controller,
      inputEvent: .buttonPress(
        ButtonEvent(buttonID: button, isPressed: pressed, timestamp: _currentTimestamp())
      )
    )
    _inputHandler(event)
  }

  private func _handleAxisInput(_ axis: AxisIdentifier, value: Float) {
    let event = ControllerInputEvent(
      controller: _controller,
      inputEvent: .axisMove(
        AxisEvent(
          axisID: axis,
          value: value,
          rawValue: Int16(value * 32767),
          timestamp: _currentTimestamp()
        )
      )
    )
    _inputHandler(event)
  }

  private func _handleTriggerInput(_ trigger: TriggerIdentifier, value: Float) {
    let event = ControllerInputEvent(
      controller: _controller,
      inputEvent: .triggerMove(
        TriggerEvent(
          triggerID: trigger,
          value: value,
          rawValue: UInt8(value * 255),
          isPressed: value > 0.1,
          timestamp: _currentTimestamp()
        )
      )
    )
    _inputHandler(event)
  }

  private func _handleDPadInput(_ direction: DPadDirection, pressed: Bool) {
    let event = ControllerInputEvent(
      controller: _controller,
      inputEvent: .dpadMove(
        DPadEvent(
          dpadID: 0,
          horizontal: pressed ? direction : .neutral,
          vertical: .neutral,
          timestamp: _currentTimestamp()
        )
      )
    )
    _inputHandler(event)
  }

  private func _currentTimestamp() -> UInt64 {
    UInt64(Date().timeIntervalSince1970 * 1_000_000)
  }
}

private struct ControllerInputEvent {
  weak var controller: GCController?
  let inputEvent: InputEvent
}

public struct GameControllerEvent: Sendable {
  public let type: EventType
  public weak var controller: GCController?
  public let inputEvent: InputEvent?
  public let message: String

  public init(
    type: EventType,
    controller: GCController? = nil,
    inputEvent: InputEvent? = nil,
    message: String = ""
  ) {
    self.type = type
    self.controller = controller
    self.inputEvent = inputEvent
    self.message = message
  }

  public enum EventType: Sendable {
    case controllerConnected
    case controllerDisconnected
    case inputReceived
    case error
  }
}