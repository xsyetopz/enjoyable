import Core
import Foundation

public protocol ReportParser: Sendable {
  func parse(report: Data) -> [InputEvent]

  var parserType: ParserType { get }

  func canParse(_ report: Data) -> Bool
}

extension ReportParser {
  public func canParse(_ report: Data) -> Bool {
    !report.isEmpty
  }
}

public struct ParserCapabilities: Sendable, Equatable {
  public let supportsDescriptorParsing: Bool
  public let supportsXInput: Bool
  public let supportsGIP: Bool
  public let supportsPlayStation: Bool
  public let supportsGenericHID: Bool
  public let maxReportSize: Int
  public let requiresReportID: Bool

  public init(
    supportsDescriptorParsing: Bool = true,
    supportsXInput: Bool = true,
    supportsGIP: Bool = true,
    supportsPlayStation: Bool = true,
    supportsGenericHID: Bool = true,
    maxReportSize: Int = 64,
    requiresReportID: Bool = false
  ) {
    self.supportsDescriptorParsing = supportsDescriptorParsing
    self.supportsXInput = supportsXInput
    self.supportsGIP = supportsGIP
    self.supportsPlayStation = supportsPlayStation
    self.supportsGenericHID = supportsGenericHID
    self.maxReportSize = maxReportSize
    self.requiresReportID = requiresReportID
  }

  public static var fullSupport: ParserCapabilities {
    ParserCapabilities()
  }

  public static var basicSupport: ParserCapabilities {
    ParserCapabilities(
      supportsDescriptorParsing: false,
      supportsXInput: true,
      supportsGIP: true,
      supportsPlayStation: true,
      supportsGenericHID: true
    )
  }
}

public enum ParserError: Error, Sendable, Equatable {
  case invalidReportSize(expected: Int, actual: Int)
  case invalidReportFormat(String)
  case unsupportedParserType
  case descriptorParsingFailed(String)
  case fieldExtractionFailed(fieldIndex: Int)
  case valueNormalizationFailed(fieldIndex: Int, reason: String)
  case timestampGenerationFailed
  case deviceIdentificationFailed(String)
}

public struct ParserStatistics: Sendable {
  public var totalReportsParsed: UInt64
  public var totalEventsGenerated: UInt64
  public var parseErrors: UInt64
  public var averageParseTime: TimeInterval
  public var lastParseTime: TimeInterval
  public var parserType: ParserType

  public init(
    totalReportsParsed: UInt64 = 0,
    totalEventsGenerated: UInt64 = 0,
    parseErrors: UInt64 = 0,
    averageParseTime: TimeInterval = 0,
    lastParseTime: TimeInterval = 0,
    parserType: ParserType = .unknown
  ) {
    self.totalReportsParsed = totalReportsParsed
    self.totalEventsGenerated = totalEventsGenerated
    self.parseErrors = parseErrors
    self.averageParseTime = averageParseTime
    self.lastParseTime = lastParseTime
    self.parserType = parserType
  }

  public mutating func recordParse(events: [InputEvent], parseTime: TimeInterval) {
    totalReportsParsed += 1
    totalEventsGenerated += UInt64(events.count)
    lastParseTime = parseTime
    let totalParses = Double(totalReportsParsed)
    averageParseTime = ((averageParseTime * (totalParses - 1)) + parseTime) / totalParses
  }

  public mutating func recordError() {
    parseErrors += 1
  }

  public var successRate: Double {
    guard totalReportsParsed > 0 else { return 0 }
    return Double(totalReportsParsed - parseErrors) / Double(totalReportsParsed)
  }
}
