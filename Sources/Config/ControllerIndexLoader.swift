import Foundation

struct IndexEntry: Codable {
  let id: String
  let path: String
  let vendorId: VendorId
  let productId: ProductId
  let priority: Int
  let enabled: Bool
}

struct ControllerIndex: Codable {
  let schema: String
  let version: Int
  let controllers: [IndexEntry]
}

final class ControllerIndexLoader: Sendable {
  private let resourcePath: String

  init(resourcePath: String = "/Users/krystian/CodeProjects/enjoyable/Resources") {
    self.resourcePath = resourcePath
  }

  func loadIndex() throws -> ControllerIndex {
    let indexPath = "\(resourcePath)/controllers/index.json"

    guard FileManager.default.fileExists(atPath: indexPath) else {
      throw ConfigurationError.fileNotFound(path: indexPath)
    }

    let data = try Data(contentsOf: URL(fileURLWithPath: indexPath))
    let decoder = JSONDecoder()

    do {
      return try decoder.decode(ControllerIndex.self, from: data)
    } catch {
      throw ConfigurationError.invalidJSON(error: error.localizedDescription)
    }
  }

  func loadConfig(for entry: IndexEntry) throws -> ControllerConfig {
    let configPath = "\(resourcePath)/controllers/\(entry.path)"

    guard FileManager.default.fileExists(atPath: configPath) else {
      throw ConfigurationError.fileNotFound(path: configPath)
    }

    let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
    let decoder = JSONDecoder()

    do {
      return try decoder.decode(ControllerConfig.self, from: data)
    } catch {
      throw ConfigurationError.invalidJSON(error: error.localizedDescription)
    }
  }

  func lookup(vendorId: VendorId, productId: ProductId) throws -> ControllerConfig? {
    let index = try loadIndex()

    let enabledControllers = index.controllers
      .filter { $0.enabled }
      .sorted { $0.priority > $1.priority }

    for entry in enabledControllers {
      if entry.vendorId == vendorId && entry.productId == productId {
        return try loadConfig(for: entry)
      }
    }

    return nil
  }

  func getAllConfigs() throws -> [ControllerConfig] {
    let index = try loadIndex()

    var configs: [ControllerConfig] = []

    for entry in index.controllers.filter({ $0.enabled }) {
      if let config = try? loadConfig(for: entry) {
        configs.append(config)
      }
    }

    return configs.sorted { $0.id < $1.id }
  }
}
