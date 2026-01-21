import Foundation

struct DetectionScore: Sendable {
  let isValid: Bool
  let score: Int
  let details: String

  static let invalid = DetectionScore(isValid: false, score: 0, details: "No valid response")
  static let low = DetectionScore(isValid: true, score: 50, details: "Partial match")
  static let medium = DetectionScore(isValid: true, score: 75, details: "Good match")
  static let high = DetectionScore(isValid: true, score: 100, details: "Excellent match")

  static func custom(score: Int, details: String) -> DetectionScore {
    DetectionScore(isValid: score > 0, score: score, details: details)
  }
}
