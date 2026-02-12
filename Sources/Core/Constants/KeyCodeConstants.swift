import Foundation

public enum KeyCodeConstants {
  public static let unmapped: UInt16 = 0x0000

  public enum Letter {
    public static let a: UInt16 = 0x00
    public static let s: UInt16 = 0x01
    public static let d: UInt16 = 0x02
    public static let f: UInt16 = 0x03
    public static let h: UInt16 = 0x04
    public static let g: UInt16 = 0x05
    public static let z: UInt16 = 0x06
    public static let x: UInt16 = 0x07
    public static let c: UInt16 = 0x08
    public static let v: UInt16 = 0x09
    public static let b: UInt16 = 0x0B
    public static let q: UInt16 = 0x0C
    public static let w: UInt16 = 0x0D
    public static let e: UInt16 = 0x0E
    public static let r: UInt16 = 0x0F
    public static let y: UInt16 = 0x10
    public static let t: UInt16 = 0x11
  }

  public enum Number {
    public static let one: UInt16 = 0x12
    public static let two: UInt16 = 0x13
    public static let three: UInt16 = 0x14
    public static let four: UInt16 = 0x15
    public static let five: UInt16 = 0x17
    public static let six: UInt16 = 0x16
    public static let seven: UInt16 = 0x1A
    public static let eight: UInt16 = 0x1C
    public static let nine: UInt16 = 0x19
    public static let zero: UInt16 = 0x1D
  }

  public enum Special {
    public static let space: UInt16 = 0x31
    public static let returnKey: UInt16 = 0x24
    public static let tab: UInt16 = 0x30
    public static let escape: UInt16 = 0x35
    public static let backspace: UInt16 = 0x33
  }
}
