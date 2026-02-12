import SwiftUI

public enum LayoutConstants {
  public enum Padding {
    public static let standard: CGFloat = 16
    public static let small: CGFloat = 8
    public static let large: CGFloat = 24
  }

  public enum Button {
    public static let height: CGFloat = 44
    public static let compactHeight: CGFloat = 36
  }

  public enum CornerRadius {
    public static let standard: CGFloat = 12
    public static let small: CGFloat = 6
  }

  public enum Spacing {
    public static let standard: CGFloat = 20
    public static let small: CGFloat = 8
  }

  public enum ControllerDiagram {
    public static let height: CGFloat = 320
  }

  public enum ButtonSize {
    public static let standard: CGFloat = 26
    public static let stick: CGFloat = 36
    public static let trigger: CGFloat = 28
    public static let bumper: CGFloat = 24
    public static let face: CGFloat = 32
    public static let center: CGFloat = 24
  }

  public enum ButtonPosition {
    public static let ls = CGPoint(x: 70, y: 120)
    public static let rs = CGPoint(x: 210, y: 120)
    public static let lb = CGPoint(x: 45, y: 65)
    public static let rb = CGPoint(x: 235, y: 65)
    public static let lt = CGPoint(x: 45, y: 40)
    public static let rt = CGPoint(x: 235, y: 40)
    public static let y = CGPoint(x: 85, y: 160)
    public static let x = CGPoint(x: 65, y: 180)
    public static let b = CGPoint(x: 105, y: 180)
    public static let a = CGPoint(x: 85, y: 200)
    public static let up = CGPoint(x: 140, y: 230)
    public static let down = CGPoint(x: 140, y: 270)
    public static let left = CGPoint(x: 115, y: 250)
    public static let right = CGPoint(x: 165, y: 250)
    public static let select = CGPoint(x: 100, y: 290)
    public static let start = CGPoint(x: 180, y: 290)

    public static func position(for button: String) -> CGPoint {
      switch button {
      case "LS": return ls
      case "RS": return rs
      case "LB": return lb
      case "RB": return rb
      case "LT": return lt
      case "RT": return rt
      case "Y": return y
      case "X": return x
      case "B": return b
      case "A": return a
      case "Up": return up
      case "Down": return down
      case "Left": return left
      case "Right": return right
      case "Select": return select
      case "Start": return start
      default: return CGPoint(x: 140, y: 160)
      }
    }
  }
}

public enum ThemeConstants {
  public enum Accent {
    public static let opacity08 = Color.accentColor.opacity(0.08)
    public static let opacity12 = Color.accentColor.opacity(0.12)
    public static let opacity20 = Color.accentColor.opacity(0.2)
  }

  public enum Secondary {
    public static let opacity02 = Color.secondary.opacity(0.2)
    public static let opacity03 = Color.secondary.opacity(0.3)
    public static let opacity04 = Color.secondary.opacity(0.4)
    public static let opacity10 = Color.secondary.opacity(0.1)
  }

  public enum Colors {
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let controlBackground = Color(nsColor: .controlBackgroundColor)
    public static let textBackground = Color(nsColor: .textBackgroundColor)
    public static let label = Color(nsColor: .labelColor)
    public static let orange = Color.orange
    public static let clear = Color.clear
    public static let gray = Color.gray
  }

  public enum Recording {
    public static let backgroundOpacity = 0.1
    public static let strokeWidth: CGFloat = 2
  }

  public enum Selection {
    public static let strokeWidth: CGFloat = 2
    public static let strokeWidthSmall: CGFloat = 1
    public static let accentStroke = Color.accentColor
    public static let grayStroke = Color.gray.opacity(0.2)
  }

  public enum Divider {
    public static let opacity = 0.2
    public static let height: CGFloat = 0.5
  }

  public enum FontSize {
    public static let caption: CGFloat = 10
    public static let caption2: CGFloat = 8
    public static let body: CGFloat = 11
    public static let bodyMedium: CGFloat = 13
    public static let title3: CGFloat = 18
    public static let title2: CGFloat = 22
    public static let largeIcon: CGFloat = 56
  }

  public enum FontWeight {
    public static let medium = Font.Weight.medium
    public static let semibold = Font.Weight.semibold
    public static let bold = Font.Weight.bold
  }

  public enum Animation {
    public static let easeInOutShort: Double = 0.1
    public static let easeInOutMedium: Double = 0.15
  }
}
