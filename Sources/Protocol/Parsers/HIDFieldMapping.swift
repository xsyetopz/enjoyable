import Core
import Foundation

struct FieldMapping: Sendable, Equatable {
  let usagePage: HIDUsagePage
  let usage: UInt16
  let bitOffset: Int
  let bitLength: Int
  let reportOffset: Int
  let isSigned: Bool
  let logicalMinimum: Int16
  let logicalMaximum: Int16
}

final class HIDFieldMappingBuilder: @unchecked Sendable {
  private var _fieldMappings: [Int: FieldMapping] = [:]
  private var _currentBitOffset = 0
  private var _currentReportID: UInt8 = 0
  private var _logicalMinimum: Int16 = 0
  private var _logicalMaximum: Int16 = 127
  private var _currentUsagePage: HIDUsagePage = .genericDesktop
  private var _usageMinimum: UInt16 = 0
  private var _usageMaximum: UInt16 = 0
  private var _pendingUsages: [(usage: UInt16, count: Int)] = []
  private let _descriptor: HIDReportDescriptor

  init(descriptor: HIDReportDescriptor) {
    self._descriptor = descriptor
  }

  func buildMappings() -> [Int: FieldMapping] {
    _fieldMappings = [:]
    _currentBitOffset = 0
    _currentReportID = 0
    _logicalMinimum = 0
    _logicalMaximum = 127
    _currentUsagePage = .genericDesktop
    _usageMinimum = 0
    _usageMaximum = 0
    _pendingUsages = []

    for item in _descriptor.items {
      switch item.type {
      case .global:
        _processGlobalItem(item)
      case .local:
        _processLocalItem(item)
      case .main:
        _processMainItem(item)
      case .reserved:
        break
      }
    }

    return _fieldMappings
  }

  private func _processGlobalItem(_ item: HIDItem) {
    guard let data = item.data else { return }
    let value = _decodeSignedValue(data)

    switch HIDGlobalItemTag(rawValue: item.tag) {
    case .reportID:
      if let firstByte = data.first {
        _currentReportID = firstByte
      }
    case .logicalMinimum:
      _logicalMinimum = value
    case .logicalMaximum:
      _logicalMaximum = value
    case .usagePage:
      _currentUsagePage = HIDUsagePage(rawValue: UInt16(value))
    default:
      break
    }
  }

  private func _processLocalItem(_ item: HIDItem) {
    guard let data = item.data else { return }
    let value = _decodeUnsignedValue(data)

    switch HIDLocalItemTag(rawValue: item.tag) {
    case .usage:
      _pendingUsages.append((usage: value, count: 1))
    case .usageMinimum:
      _usageMinimum = value
    case .usageMaximum:
      _usageMaximum = value
    default:
      break
    }
  }

  private func _processMainItem(_ item: HIDItem) {
    guard let data = item.data else { return }
    let byteValue = data.first ?? 0
    let flags = HIDFieldFlags(
      isConstant: (byteValue & 0x01) != 0,
      isVariable: (byteValue & 0x02) != 0,
      isRelative: (byteValue & 0x04) != 0,
      isWrap: (byteValue & 0x08) != 0,
      isNonLinear: (byteValue & 0x10) != 0,
      noPreferred: (byteValue & 0x20) != 0,
      hasNullPosition: (byteValue & 0x40) != 0,
      volatile: (byteValue & 0x80) != 0
    )
    let isConstant = flags.isConstant
    let isVariable = flags.isVariable

    if isVariable && !isConstant {
      if !_pendingUsages.isEmpty {
        for (_, usageEntry) in _pendingUsages.enumerated() {
          let bitLength = _descriptor.reportSize
          let mapping = FieldMapping(
            usagePage: _currentUsagePage,
            usage: usageEntry.usage,
            bitOffset: _currentBitOffset,
            bitLength: bitLength,
            reportOffset: _currentBitOffset / 8,
            isSigned: _logicalMinimum < 0,
            logicalMinimum: _logicalMinimum,
            logicalMaximum: _logicalMaximum
          )
          let fieldIndex = _fieldMappings.count
          _fieldMappings[fieldIndex] = mapping
          _currentBitOffset += bitLength
        }
        _pendingUsages.removeAll()
      } else if _usageMinimum > 0 && _usageMaximum > 0 {
        for usage in _usageMinimum..._usageMaximum {
          let bitLength = _descriptor.reportSize
          let mapping = FieldMapping(
            usagePage: _currentUsagePage,
            usage: usage,
            bitOffset: _currentBitOffset,
            bitLength: bitLength,
            reportOffset: _currentBitOffset / 8,
            isSigned: _logicalMinimum < 0,
            logicalMinimum: _logicalMinimum,
            logicalMaximum: _logicalMaximum
          )
          let fieldIndex = _fieldMappings.count
          _fieldMappings[fieldIndex] = mapping
          _currentBitOffset += bitLength
        }
      }
    }
  }

  private func _decodeSignedValue(_ data: Data) -> Int16 {
    guard let firstByte = data.first else { return 0 }
    if data.count == 1 {
      return Int16(bitPattern: UInt16(firstByte))
    } else if data.count == 2 {
      return Int16(bitPattern: UInt16(data[0]) | (UInt16(data[1]) << 8))
    }
    return 0
  }

  private func _decodeUnsignedValue(_ data: Data) -> UInt16 {
    guard let firstByte = data.first else { return 0 }
    if data.count == 1 {
      return UInt16(firstByte)
    } else if data.count == 2 {
      return UInt16(data[0]) | (UInt16(data[1]) << 8)
    }
    return 0
  }
}

struct FieldValueExtractor: Sendable {
  static func extract(from report: Data, mapping: FieldMapping) -> Int32 {
    let byteIndex = mapping.reportOffset
    guard byteIndex < report.count else { return 0 }

    let startBit = mapping.bitOffset % 8
    let endBit = startBit + mapping.bitLength - 1
    let endByteIndex = byteIndex + endBit / 8

    guard endByteIndex < report.count else { return 0 }

    var result: UInt32 = 0
    var bitsExtracted = 0

    for byteOffset in byteIndex...endByteIndex {
      let byteValue = report[byteOffset]
      let availableBits = min(8, mapping.bitLength - bitsExtracted)
      let startBitInByte = (byteOffset == byteIndex) ? startBit : 0
      let bitsToExtract = min(availableBits, 8 - startBitInByte)

      if bitsToExtract > 0 {
        let mask = UInt32(((1 << bitsToExtract) - 1) << startBitInByte)
        let extracted = (UInt32(byteValue) & mask) >> UInt32(startBitInByte)
        result |= extracted << bitsExtracted
        bitsExtracted += bitsToExtract
      }
    }

    if mapping.isSigned && bitsExtracted > 0 {
      let signBitMask: UInt32 = 1 << UInt(bitsExtracted - 1)
      if (result & signBitMask) != 0 {
        let signExtension = UInt32(~((1 << bitsExtracted) - 1))
        result |= signExtension
      }
    }

    return Int32(result)
  }
}

struct UsageMapper: Sendable {
  static func mapToButton(usagePage: HIDUsagePage, usage: UInt16) -> ButtonIdentifier? {
    switch (usagePage, usage) {
    case (.button, 1): return .a
    case (.button, 2): return .b
    case (.button, 3): return .x
    case (.button, 4): return .y
    case (.button, 5): return .leftShoulder
    case (.button, 6): return .rightShoulder
    case (.button, 7): return .leftTrigger
    case (.button, 8): return .rightTrigger
    case (.button, 9): return .back
    case (.button, 10): return .start
    case (.button, 11): return .leftStick
    case (.button, 12): return .rightStick
    case (.genericDesktop, 0x3D): return .start
    case (.genericDesktop, 0x3E): return .back
    default:
      if usage >= 0x01 && usage <= 0x20 {
        return .custom(UInt8(usage))
      }
      return nil
    }
  }

  static func mapToAxis(usagePage: HIDUsagePage, usage: UInt16) -> AxisIdentifier? {
    switch (usagePage, usage) {
    case (.genericDesktop, 0x30): return .leftStickX
    case (.genericDesktop, 0x31): return .leftStickY
    case (.genericDesktop, 0x32): return .leftTrigger
    case (.genericDesktop, 0x33): return .rightStickX
    case (.genericDesktop, 0x34): return .rightStickY
    case (.genericDesktop, 0x35): return .rightTrigger
    case (.genericDesktop, 0x36): return .custom(0)
    case (.genericDesktop, 0x37): return .custom(1)
    default:
      if usage >= 0x30 && usage <= 0x37 {
        return .custom(UInt8(usage - 0x30))
      }
      return nil
    }
  }

  static func mapToTrigger(usagePage: HIDUsagePage, usage: UInt16) -> TriggerIdentifier? {
    switch (usagePage, usage) {
    case (.genericDesktop, 0x32): return .left
    case (.genericDesktop, 0x35): return .right
    default:
      if usage >= 0x32 && usage <= 0x35 {
        return .custom(UInt8(usage - 0x32))
      }
      return nil
    }
  }
}

struct ValueNormalizer: Sendable {
  static func normalizeAxis(_ value: Int32, mapping: FieldMapping) -> Float {
    let range = Float(mapping.logicalMaximum) - Float(mapping.logicalMinimum)
    guard range != 0 else { return 0.0 }
    let normalized = (Float(value) - Float(mapping.logicalMinimum)) / range
    return max(-1.0, min(1.0, normalized))
  }

  static func normalizeTrigger(_ value: Int32, mapping: FieldMapping) -> Float {
    let range = Float(mapping.logicalMaximum) - Float(mapping.logicalMinimum)
    guard range != 0 else { return 0.0 }
    let normalized = (Float(value) - Float(mapping.logicalMinimum)) / range
    return max(0.0, min(1.0, normalized))
  }
}
