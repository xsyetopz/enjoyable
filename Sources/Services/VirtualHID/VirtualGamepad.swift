import Core
import CoreFoundation
import Foundation
import IOKit
import Protocol

@_silgen_name("IOHIDUserDeviceCreate")
func IOHIDUserDeviceCreate(
  _ allocator: CFAllocator?,
  _ properties: CFDictionary,
  _ options: CFIndex
) -> IOHIDUserDevice?

@_silgen_name("IOHIDUserDeviceHandleReportWithTimeStamp")
func IOHIDUserDeviceHandleReportWithTimeStamp(
  _ device: IOHIDUserDevice,
  _ timestamp: UInt64,
  _ report: UnsafePointer<UInt8>,
  _ reportLength: CFIndex
) -> IOReturn

@_silgen_name("IOHIDUserDeviceUnscheduleFromRunLoop")
func IOHIDUserDeviceUnscheduleFromRunLoop(
  _ device: IOHIDUserDevice,
  _ runLoop: CFRunLoop,
  _ runLoopMode: CFString
) -> IOReturn

final class VirtualGamepad: @unchecked Sendable {
  private var _device: IOHIDUserDevice?
  private var _reportQueue: DispatchQueue?
  private var _isDestroyed = false
  private var _setReportBlock:
    ((IOHIDReportType, UInt32, UnsafePointer<UInt8>, CFIndex) -> IOReturn)?
  private let _eventHandler: @Sendable (VirtualHIDEvent) -> Void

  private let _vendorID: UInt16
  private let _productID: UInt16
  private let _productName: String
  private let _manufacturer: String

  private let _state = GamepadState()

  static func create(
    vendorID: UInt16,
    productID: UInt16,
    productName: String,
    manufacturer: String,
    eventHandler: @escaping @Sendable (VirtualHIDEvent) -> Void
  ) async throws -> VirtualGamepad {
    let gamepad = VirtualGamepad(
      vendorID: vendorID,
      productID: productID,
      productName: productName,
      manufacturer: manufacturer,
      eventHandler: eventHandler
    )

    try await gamepad._initialize()
    return gamepad
  }

  private init(
    vendorID: UInt16,
    productID: UInt16,
    productName: String,
    manufacturer: String,
    eventHandler: @escaping @Sendable (VirtualHIDEvent) -> Void
  ) {
    self._vendorID = vendorID
    self._productID = productID
    self._productName = productName
    self._manufacturer = manufacturer
    self._eventHandler = eventHandler
    self._reportQueue = DispatchQueue(
      label: "com.enjoyable.virtualgamepad.\(vendorID)-\(productID)"
    )
  }

  private func _initialize() async throws {
    let reportDescriptor = _createXboxStyleDescriptor()

    var properties: [String: Any] = [:]
    properties[kIOHIDVendorIDKey] = _vendorID
    properties[kIOHIDProductIDKey] = _productID
    properties[kIOHIDProductKey] = _productName as CFString
    properties[kIOHIDManufacturerKey] = _manufacturer as CFString
    properties[kIOHIDReportDescriptorKey] = reportDescriptor as CFData

    let device = IOHIDUserDeviceCreate(kCFAllocatorDefault, properties as CFDictionary, 0)

    guard device != nil else {
      throw VirtualHIDError.deviceCreationFailed
    }

    _setReportBlock = { reportType, reportID, report, reportLength in
      return kIOReturnSuccess
    }

    if let device = device, let block = _setReportBlock {
      IOHIDUserDeviceRegisterSetReportBlock(device, block)
    }

    _device = device
  }

  private func _createXboxStyleDescriptor() -> Data {
    var descriptor: [UInt8] = []

    descriptor.append(HIDUsagePageTag.genericDesktop.rawValue)
    descriptor.append(HIDGenericDesktopUsage.gamePad.rawValue)
    descriptor.append(HIDCollectionTag.application.rawValue)

    descriptor.append(HIDUsagePageTag.button.rawValue)
    descriptor.append(HIDButtonUsage.button1.rawValue)
    descriptor.append(HIDCollectionTag.physical.rawValue)

    descriptor.append(HIDUsagePageTag.genericDesktop.rawValue)
    descriptor.append(HIDGenericDesktopUsage.x.rawValue)
    descriptor.append(HIDGenericDesktopUsage.y.rawValue)
    descriptor.append(HIDGenericDesktopUsage.z.rawValue)
    descriptor.append(HIDGenericDesktopUsage.rz.rawValue)

    descriptor.append(HIDGlobalTag.logicalMinimum.rawValue)
    descriptor.append(0x00)

    descriptor.append(HIDGlobalTag.logicalMaximum.rawValue)
    descriptor.append(0xFF)

    descriptor.append(HIDGlobalTag.physicalMinimum.rawValue)
    descriptor.append(0x00)

    descriptor.append(HIDGlobalTag.physicalMaximum.rawValue)
    descriptor.append(0xFF)

    descriptor.append(HIDGlobalTag.unit.rawValue)
    descriptor.append(0x11)

    descriptor.append(HIDGlobalTag.reportSize.rawValue)
    descriptor.append(0x08)

    descriptor.append(HIDGlobalTag.reportCount.rawValue)
    descriptor.append(0x04)

    descriptor.append(HIDInputOutputTag.dataVarAbs.rawValue)

    descriptor.append(HIDUsagePageTag.button.rawValue)
    descriptor.append(HIDGenericDesktopUsage.hatSwitch.rawValue)

    descriptor.append(HIDGlobalTag.logicalMinimum.rawValue)
    descriptor.append(0x00)

    descriptor.append(HIDGlobalTag.logicalMaximum.rawValue)
    descriptor.append(0x07)

    descriptor.append(HIDGlobalTag.physicalMinimum.rawValue)
    descriptor.append(0x00)

    descriptor.append(HIDGlobalTag.physicalMaximum.rawValue)
    descriptor.append(0x07)

    descriptor.append(HIDGlobalTag.unit.rawValue)
    descriptor.append(0x14)

    descriptor.append(HIDGlobalTag.reportSize.rawValue)
    descriptor.append(0x04)

    descriptor.append(HIDGlobalTag.reportCount.rawValue)
    descriptor.append(0x01)

    descriptor.append(HIDInputOutputTag.constVarAbs.rawValue)

    descriptor.append(HIDUsagePageTag.button.rawValue)
    descriptor.append(HIDButtonUsage.button1.rawValue)
    descriptor.append(HIDButtonUsage.button2.rawValue)
    descriptor.append(HIDButtonUsage.button3.rawValue)
    descriptor.append(HIDButtonUsage.button4.rawValue)
    descriptor.append(HIDButtonUsage.button5.rawValue)
    descriptor.append(HIDButtonUsage.button6.rawValue)
    descriptor.append(HIDButtonUsage.button7.rawValue)
    descriptor.append(HIDButtonUsage.button8.rawValue)
    descriptor.append(HIDButtonUsage.button9.rawValue)
    descriptor.append(HIDButtonUsage.button10.rawValue)
    descriptor.append(HIDButtonUsage.button11.rawValue)
    descriptor.append(HIDButtonUsage.button12.rawValue)
    descriptor.append(HIDButtonUsage.button13.rawValue)
    descriptor.append(HIDButtonUsage.button14.rawValue)

    descriptor.append(HIDGlobalTag.logicalMinimum.rawValue)
    descriptor.append(0x00)

    descriptor.append(HIDGlobalTag.logicalMaximum.rawValue)
    descriptor.append(0x01)

    descriptor.append(HIDGlobalTag.reportSize.rawValue)
    descriptor.append(0x01)

    descriptor.append(HIDGlobalTag.reportCount.rawValue)
    descriptor.append(0x0E)

    descriptor.append(HIDInputOutputTag.dataVarAbs.rawValue)

    descriptor.append(HIDCollectionTag.end.rawValue)

    descriptor.append(HIDUsagePageTag.pid.rawValue)
    descriptor.append(HIDPIDUsage.physicalInterfaceDevice.rawValue)
    descriptor.append(HIDPIDUsage.normal.rawValue)
    descriptor.append(HIDCollectionTag.application.rawValue)

    descriptor.append(HIDUsagePageTag.genericDesktop.rawValue)
    descriptor.append(HIDPIDUsage.setEffectReport.rawValue)
    descriptor.append(HIDPIDUsage.effectBlockIndex.rawValue)

    descriptor.append(HIDGlobalTag.logicalMinimum.rawValue)
    descriptor.append(0x00)

    descriptor.append(HIDGlobalTag.logicalMaximum.rawValue)
    descriptor.append(0xFF)
    descriptor.append(0x00)

    descriptor.append(HIDGlobalTag.reportSize.rawValue)
    descriptor.append(0x08)

    descriptor.append(HIDGlobalTag.reportCount.rawValue)
    descriptor.append(0x02)

    descriptor.append(HIDInputOutputTag.dataVarAbs.rawValue)

    descriptor.append(HIDCollectionTag.end.rawValue)

    return Data(descriptor)
  }

  func sendRumble(leftMotor: Float, rightMotor: Float) async throws {
    guard !_isDestroyed, let device = _device else {
      throw VirtualHIDError.deviceNotFound
    }

    let leftValue = clampUInt8(from: leftMotor * 255)
    let rightValue = clampUInt8(from: rightMotor * 255)

    var report = Array(repeating: UInt8(0), count: 4)
    report[0] = 0x00
    report[1] = rightValue
    report[2] = leftValue
    report[3] = 0x00

    let reportData = Data(report)
    let timestamp = mach_absolute_time()
    let sendResult = reportData.withUnsafeBytes { bytes in
      IOHIDUserDeviceHandleReportWithTimeStamp(
        device,
        timestamp,
        bytes.bindMemory(to: UInt8.self).baseAddress!,
        reportData.count
      )
    }

    guard sendResult == kIOReturnSuccess else {
      throw VirtualHIDError.reportSendFailed
    }
  }

  func sendLED(pattern: LEDPattern) async throws {
    guard !_isDestroyed, let device = _device else {
      throw VirtualHIDError.deviceNotFound
    }

    var report = Array(repeating: UInt8(0), count: 3)

    switch pattern {
    case .off:
      report[0] = 0x00
    case .on:
      report[0] = 0x01
    case .blink(let fast):
      report[0] = fast ? 0x02 : 0x03
    case .player(let number):
      report[0] = 0x04 + UInt8(number - 1)
    case .breathing:
      report[0] = 0x0A
    case .custom(let frequencies):
      if !frequencies.isEmpty {
        report[0] = 0x0B
        report[1] = frequencies[0]
        report[2] = frequencies.count > 1 ? frequencies[1] : frequencies[0]
      }
    }

    let reportData = Data(report)
    let timestamp = mach_absolute_time()
    let sendResult = reportData.withUnsafeBytes { bytes in
      IOHIDUserDeviceHandleReportWithTimeStamp(
        device,
        timestamp,
        bytes.bindMemory(to: UInt8.self).baseAddress!,
        reportData.count
      )
    }

    guard sendResult == kIOReturnSuccess else {
      throw VirtualHIDError.reportSendFailed
    }
  }

  func updateButtonState(button: ButtonIdentifier, isPressed: Bool) async throws {
    guard !_isDestroyed, let device = _device else {
      throw VirtualHIDError.deviceNotFound
    }

    let bitPosition = _buttonToBitPosition(button)
    await _state.updateButtonState(bitPosition: bitPosition, isPressed: isPressed)

    try await _sendInputReport(device: device)
  }

  func updateAxisValue(axis: AxisIdentifier, value: Float) async throws {
    guard !_isDestroyed, let device = _device else {
      throw VirtualHIDError.deviceNotFound
    }

    let byteIndex = _axisToByteIndex(axis)
    let clampedValue = UInt8(clamping: Int(value * 255))
    await _state.updateAxisValue(byteIndex: byteIndex, value: clampedValue)

    try await _sendInputReport(device: device)
  }

  func updateTriggerValue(trigger: TriggerIdentifier, value: Float) async throws {
    guard !_isDestroyed, let device = _device else {
      throw VirtualHIDError.deviceNotFound
    }

    let index = _triggerToIndex(trigger)
    let clampedValue = UInt8(clamping: Int(value * 255))
    await _state.updateTriggerValue(index: index, value: clampedValue)

    try await _sendInputReport(device: device)
  }

  private func _sendInputReport(device: IOHIDUserDevice) async throws {
    let state = await _state.getState()

    var report = [UInt8](repeating: 0, count: 20)

    report[0] = UInt8(state.buttonStates & 0xFF)
    report[1] = UInt8((state.buttonStates >> 8) & 0xFF)

    for i in 0..<4 {
      report[2 + i] = state.axisValues[i]
    }

    report[6] = state.triggerValues[0]
    report[7] = state.triggerValues[1]

    let reportData = Data(report)
    let timestamp = mach_absolute_time()
    let sendResult = reportData.withUnsafeBytes { bytes in
      IOHIDUserDeviceHandleReportWithTimeStamp(
        device,
        timestamp,
        bytes.bindMemory(to: UInt8.self).baseAddress!,
        reportData.count
      )
    }

    guard sendResult == kIOReturnSuccess else {
      throw VirtualHIDError.reportSendFailed
    }
  }

  private func _buttonToBitPosition(_ button: ButtonIdentifier) -> Int {
    switch button {
    case .a: return 0
    case .b: return 1
    case .x: return 2
    case .y: return 3
    case .leftShoulder: return 4
    case .rightShoulder: return 5
    case .back: return 6
    case .start: return 7
    case .leftStick: return 8
    case .rightStick: return 9
    case .guide: return 10
    default: return 0
    }
  }

  private func _axisToByteIndex(_ axis: AxisIdentifier) -> Int {
    switch axis {
    case .leftStickX: return 0
    case .leftStickY: return 1
    case .rightStickX: return 2
    case .rightStickY: return 3
    default: return 0
    }
  }

  private func _triggerToIndex(_ trigger: TriggerIdentifier) -> Int {
    switch trigger {
    case .left: return 0
    case .right: return 1
    default: return 0
    }
  }

  func destroy() async {
    _isDestroyed = true

    if let device = _device {
      _ = IOHIDUserDeviceUnscheduleFromRunLoop(
        device,
        CFRunLoopGetMain(),
        CFRunLoopMode.defaultMode.rawValue as CFString
      )
      _device = nil
    }

    _reportQueue = nil
  }
}

private func clampUInt8(from value: Float) -> UInt8 {
  let clamped = max(0, min(255, value))
  return UInt8(clamped)
}

private actor GamepadState {
  private var _currentButtonStates: UInt16 = 0
  private var _currentAxisValues: [UInt8] = Array(repeating: 128, count: 6)
  private var _currentTriggerValues: [UInt8] = [0, 0]

  func updateButtonState(bitPosition: Int, isPressed: Bool) {
    if isPressed {
      _currentButtonStates |= (1 << bitPosition)
    } else {
      _currentButtonStates &= ~(1 << bitPosition)
    }
  }

  func updateAxisValue(byteIndex: Int, value: UInt8) {
    _currentAxisValues[byteIndex] = value
  }

  func updateTriggerValue(index: Int, value: UInt8) {
    _currentTriggerValues[index] = value
  }

  func getState() -> (buttonStates: UInt16, axisValues: [UInt8], triggerValues: [UInt8]) {
    return (_currentButtonStates, _currentAxisValues, _currentTriggerValues)
  }
}
