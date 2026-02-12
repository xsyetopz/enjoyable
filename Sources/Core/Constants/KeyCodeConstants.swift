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

  public enum Arrow {
    public static let up: UInt16 = 0x3E
    public static let down: UInt16 = 0x3D
    public static let left: UInt16 = 0x3B
    public static let right: UInt16 = 0x3C
  }

  public enum Modifier {
    public static let command: UInt16 = 0x37
    public static let control: UInt16 = 0x3B
    public static let option: UInt16 = 0x3A
    public static let shift: UInt16 = 0x38
    public static let capsLock: UInt16 = 0x39
  }

  public enum Function {
    public static let f1: UInt16 = 0x7A
    public static let f2: UInt16 = 0x78
    public static let f3: UInt16 = 0x63
    public static let f4: UInt16 = 0x76
    public static let f5: UInt16 = 0x60
    public static let f6: UInt16 = 0x61
    public static let f7: UInt16 = 0x62
    public static let f8: UInt16 = 0x64
    public static let f9: UInt16 = 0x65
    public static let f10: UInt16 = 0x6D
    public static let f11: UInt16 = 0x67
    public static let f12: UInt16 = 0x6F
    public static let f13: UInt16 = 0x69
    public static let f14: UInt16 = 0x6B
    public static let f15: UInt16 = 0x71
    public static let f16: UInt16 = 0x6A
    public static let f17: UInt16 = 0x40
    public static let f18: UInt16 = 0x4F
    public static let f19: UInt16 = 0x42
  }

  public enum Navigation {
    public static let home: UInt16 = 0x73
    public static let end: UInt16 = 0x77
    public static let pageUp: UInt16 = 0x74
    public static let pageDown: UInt16 = 0x79
    public static let help: UInt16 = 0x72
  }
}
