import Foundation

public enum GamepadConstants {
  public enum Button: String, CaseIterable {
    case a = "A"
    case b = "B"
    case x = "X"
    case y = "Y"
    case lb = "LB"
    case rb = "RB"
    case lt = "LT"
    case rt = "RT"
    case ls = "LS"
    case rs = "RS"
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
    case start = "Start"
    case select = "Select"

    public static var allNames: [String] {
      allCases.map { $0.rawValue }
    }

    public static func mapFromRawIdentifier(_ identifier: String) -> String {
      switch identifier {
      case "Button_0": return "A"
      case "Button_1": return "B"
      case "Button_2": return "X"
      case "Button_3": return "Y"
      case "Button_4": return "LB"
      case "Button_5": return "RB"
      case "Button_6": return "LT"
      case "Button_7": return "RT"
      case "Button_8": return "LS"
      case "Button_9": return "RS"
      case "Button_10": return "Select"
      case "Button_11": return "Start"
      case "Axis_0": return "LeftX"
      case "Axis_1": return "LeftY"
      case "Axis_2": return "RightX"
      case "Axis_3": return "RightY"
      default: return identifier
      }
    }
  }
}
