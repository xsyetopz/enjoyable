import Foundation

enum ConfigurationError: Error, LocalizedError {
  case invalidSchemaVersion(String)
  case missingResourcePath
  case fileNotFound(String)
  case invalidJSON(String)
  case parsingError(any Error)
  case noConfigurationsFound

  var errorDescription: String? {
    switch self {
    case .invalidSchemaVersion(let version):
      return "Invalid configuration schema version: \(version)"
    case .missingResourcePath:
      return "Configuration resource path not found"
    case .fileNotFound(let path):
      return "Configuration file not found: \(path)"
    case .invalidJSON(let path):
      return "Invalid JSON in configuration file: \(path)"
    case .parsingError(let error):
      return "Error parsing configuration: \(error.localizedDescription)"
    case .noConfigurationsFound:
      return "No device configurations found"
    }
  }
}

public final class ConfigurationLoader {
  public let fileManager = FileManager.default
  private var _cachedConfigurations: [String: DeviceConfiguration]?

  private func _preprocessJSONC(_ content: String) -> String {
    var inBlockComment = false
    var inString = false
    var resultChars: [Character] = []
    var i = content.startIndex

    while i < content.endIndex {
      let char = content[i]
      let nextIndex = content.index(after: i)

      if inString {
        resultChars.append(char)
        if char == "\"" {
          inString = false
        } else if char == "\\" && nextIndex < content.endIndex {
          resultChars.append(content[nextIndex])
          i = content.index(after: nextIndex)
          continue
        }
      } else {
        if char == "\"" {
          inString = true
          resultChars.append(char)
        } else if char == "/" && nextIndex < content.endIndex {
          let nextChar = content[nextIndex]
          if nextChar == "/" {
            while i < content.endIndex && content[i] != "\n" {
              i = content.index(after: i)
            }
            continue
          } else if nextChar == "*" {
            inBlockComment = true
            i = content.index(after: nextIndex)
            continue
          } else {
            resultChars.append(char)
          }
        } else if char == "*" && nextIndex < content.endIndex && content[nextIndex] == "/" {
          inBlockComment = false
          i = content.index(after: nextIndex)
          continue
        } else if !inBlockComment {
          resultChars.append(char)
        }
      }

      i = nextIndex
    }

    var cleaned = String(resultChars)
    cleaned = cleaned.replacingOccurrences(of: ",}", with: "}")
    cleaned = cleaned.replacingOccurrences(of: ",]", with: "]")
    return cleaned
  }

  var resourcePath: URL? {
    #if os(macOS)
    let appBundlePath = Bundle.main.bundlePath + "/Contents/Resources/Configurations"
    if fileManager.fileExists(atPath: appBundlePath) {
      return URL(fileURLWithPath: appBundlePath)
    }

    if let resourcePath = Bundle.main.resourcePath {
      let resourceConfigPath = resourcePath + "/Configurations"
      if fileManager.fileExists(atPath: resourceConfigPath) {
        return URL(fileURLWithPath: resourceConfigPath)
      }
    }
    #endif

    let currentPath = URL(fileURLWithPath: fileManager.currentDirectoryPath)
    return currentPath.appendingPathComponent("Resources", isDirectory: true)
      .appendingPathComponent("Configurations", isDirectory: true)
  }

  func loadAllConfigurations() throws -> [DeviceConfiguration] {
    var configurations: [DeviceConfiguration] = []

    guard let path = resourcePath else {
      throw ConfigurationError.missingResourcePath
    }

    guard fileManager.fileExists(atPath: path.path) else {
      throw ConfigurationError.fileNotFound(path.path)
    }

    let enumerator = fileManager.enumerator(
      at: path,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    )

    guard let enumerator = enumerator else {
      throw ConfigurationError.noConfigurationsFound
    }

    for case let fileURL as URL in enumerator {
      if fileURL.pathExtension == "json" {
        do {
          let config = try loadConfiguration(from: fileURL)
          configurations.append(config)
          NSLog("[ConfigLoader] Successfully loaded: \(fileURL.lastPathComponent)")
        } catch {
          NSLog("[ConfigLoader] Failed to load \(fileURL.lastPathComponent): \(error)")
        }
      }
    }

    if configurations.isEmpty {
      throw ConfigurationError.noConfigurationsFound
    }

    return configurations
  }

  func loadConfiguration(from url: URL) throws -> DeviceConfiguration {
    let content: String
    do {
      content = try String(contentsOf: url, encoding: .utf8)
    } catch {
      throw ConfigurationError.fileNotFound(url.path)
    }

    let cleanedContent = _preprocessJSONC(content)
    guard let data = cleanedContent.data(using: .utf8) else {
      throw ConfigurationError.invalidJSON(url.path)
    }

    let decoder = JSONDecoder()
    let configuration: DeviceConfiguration
    do {
      configuration = try decoder.decode(DeviceConfiguration.self, from: data)
    } catch {
      throw ConfigurationError.invalidJSON(url.path)
    }

    if configuration.schemaVersion != "1.0" {
      throw ConfigurationError.invalidSchemaVersion(configuration.schemaVersion)
    }

    return configuration
  }

  func loadConfigurations(forVendor vendor: String) throws -> [DeviceConfiguration] {
    guard let path = resourcePath else {
      throw ConfigurationError.missingResourcePath
    }

    let vendorPath = path.appendingPathComponent(vendor, isDirectory: true)
    guard fileManager.fileExists(atPath: vendorPath.path) else {
      return []
    }

    var configurations: [DeviceConfiguration] = []

    let enumerator = fileManager.enumerator(
      at: vendorPath,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    )

    guard let enumerator = enumerator else {
      return []
    }

    for case let fileURL as URL in enumerator {
      if fileURL.pathExtension == "json" {
        do {
          let config = try loadConfiguration(from: fileURL)
          configurations.append(config)
          NSLog("[ConfigLoader] Successfully loaded vendor config: \(fileURL.lastPathComponent)")
        } catch {
          NSLog("[ConfigLoader] Failed to load vendor config \(fileURL.lastPathComponent): \(error)")
        }
      }
    }

    return configurations
  }

  func availableVendors() -> [String] {
    guard let path = resourcePath else {
      return []
    }

    guard
      let contents = try? fileManager.contentsOfDirectory(
        at: path,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    return contents.compactMap { url -> String? in
      let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
      return isDirectory ? url.lastPathComponent : nil
    }
  }

  func clearCache() {
    _cachedConfigurations = nil
  }
}
