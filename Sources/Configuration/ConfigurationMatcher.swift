import Foundation

public enum MatchResult: Equatable {
  case exact(DeviceConfiguration)
  case vendor(DeviceConfiguration)
  case protocolFallback(DeviceConfiguration)
  case generic(DeviceConfiguration)
  case none

  public static func == (lhs: MatchResult, rhs: MatchResult) -> Bool {
    switch (lhs, rhs) {
    case (.exact(let a), .exact(let b)):
      return a == b
    case (.vendor(let a), .vendor(let b)):
      return a == b
    case (.protocolFallback(let a), .protocolFallback(let b)):
      return a == b
    case (.generic(let a), .generic(let b)):
      return a == b
    case (.none, .none):
      return true
    default:
      return false
    }
  }
}

public final class ConfigurationMatcher {
  private let _loader: ConfigurationLoader
  private var _configurationCache: [Int: DeviceConfiguration]?
  private var _vendorCache: [Int: [DeviceConfiguration]]?
  private var _protocolCache: [ProtocolType: DeviceConfiguration]?

  public init(loader: ConfigurationLoader) {
    self._loader = loader
  }

  public convenience init() {
    self.init(loader: ConfigurationLoader())
  }

  func matchDevice(
    vendorId: Int,
    productId: Int,
    protocolType: ProtocolType? = nil
  ) -> MatchResult {
    if _configurationCache == nil {
      _cacheConfigurations()
    }

    if let config = _configurationCache?[productId] {
      if config.device.vendorId == vendorId {
        return .exact(config)
      }
    }
    if let vendorConfigs = _vendorCache?[vendorId] {
      if let config = vendorConfigs.first {
        return .vendor(config)
      }
    }

    if let knownProtocol = protocolType ?? _guessProtocol(vendorId: vendorId, productId: productId)
    {
      if let config = _protocolCache?[knownProtocol] {
        return .protocolFallback(config)
      }
    }

    if let genericConfig = _configurationCache?[0] {
      return .generic(genericConfig)
    }

    return .none
  }

  private func _cacheConfigurations() {
    _configurationCache = [:]
    _vendorCache = [:]
    _protocolCache = [:]

    do {
      let configurations = try _loader.loadAllConfigurations()

      for config in configurations {
        _configurationCache?[config.device.productId] = config

        _vendorCache?[config.device.vendorId, default: []].append(config)
        _protocolCache?[config.protocolType] = config
      }
    } catch {
      NSLog("Failed to cache configurations: \(error)")
    }
  }

  private func _guessProtocol(vendorId: Int, productId: Int) -> ProtocolType? {
    if vendorId == 0x045E {
      switch productId {
      case 0x028E, 0x0719:  // Xbox 360 controllers
        return .xinput
      case 0x02DD, 0x02E0, 0x02E1, 0x02E3, 0x02E5, 0x02E6, 0x02E7, 0x02FD:  // Xbox One controllers
        return .gip
      default:
        return .xinput
      }
    }
    if vendorId == 0x054C {
      switch productId {
      case 0x05C4, 0x09CC, 0x0BA0:  // DualShock 4
        return .ds4
      case 0x0CE6:  // DualSense
        return .hid
      default:
        return .hid
      }
    }

    if vendorId == 0x057E {
      return .hid
    }

    return .hid
  }

  func findAllMatching(
    vendorId: Int,
    productId: Int
  ) -> [DeviceConfiguration] {
    var matches: [DeviceConfiguration] = []

    do {
      let configurations = try _loader.loadAllConfigurations()

      for config in configurations {
        if config.matches(vendorId: vendorId, productId: productId) {
          matches.append(config)
        }
      }
    } catch {
      return []
    }

    return matches
  }

  public func bestConfiguration(
    vendorId: Int,
    productId: Int,
    protocolType: ProtocolType? = nil
  ) -> DeviceConfiguration? {
    let result = matchDevice(vendorId: vendorId, productId: productId, protocolType: protocolType)

    switch result {
    case .exact(let config):
      return config
    case .vendor(let config):
      return config
    case .protocolFallback(let config):
      return config
    case .generic(let config):
      return config
    case .none:
      return nil
    }
  }

  func isDeviceSupported(vendorId: Int, productId: Int) -> Bool {
    let result = matchDevice(vendorId: vendorId, productId: productId)
    return result != .none
  }

  func initializationSteps(
    vendorId: Int,
    productId: Int
  ) -> [InitStep]? {
    guard let config = bestConfiguration(vendorId: vendorId, productId: productId) else {
      return nil
    }
    return config.initialization
  }

  public func mappings(
    vendorId: Int,
    productId: Int
  ) -> ButtonMappings? {
    guard let config = bestConfiguration(vendorId: vendorId, productId: productId) else {
      return nil
    }
    return config.mappings
  }

  func quirks(
    vendorId: Int,
    productId: Int
  ) -> [DeviceQuirk]? {
    guard let config = bestConfiguration(vendorId: vendorId, productId: productId) else {
      return nil
    }
    return config.quirks
  }

  func hasQuirk(
    vendorId: Int,
    productId: Int,
    quirkName: String
  ) -> Bool {
    guard let config = bestConfiguration(vendorId: vendorId, productId: productId) else {
      return false
    }
    return config.hasQuirk(named: quirkName)
  }

  func clearCache() {
    _configurationCache = nil
    _vendorCache = nil
    _protocolCache = nil
  }
}
