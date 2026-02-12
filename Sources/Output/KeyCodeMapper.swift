import Core
import Foundation

public enum KeyCodeMapper {
  public static func mapKey(_ key: String) -> UInt16 {
    let normalizedKey = key.lowercased()
    switch normalizedKey {
    case "a": return KeyCodeConstants.Letter.a
    case "s": return KeyCodeConstants.Letter.s
    case "d": return KeyCodeConstants.Letter.d
    case "f": return KeyCodeConstants.Letter.f
    case "h": return KeyCodeConstants.Letter.h
    case "g": return KeyCodeConstants.Letter.g
    case "z": return KeyCodeConstants.Letter.z
    case "x": return KeyCodeConstants.Letter.x
    case "c": return KeyCodeConstants.Letter.c
    case "v": return KeyCodeConstants.Letter.v
    case "b": return KeyCodeConstants.Letter.b
    case "q": return KeyCodeConstants.Letter.q
    case "w": return KeyCodeConstants.Letter.w
    case "e": return KeyCodeConstants.Letter.e
    case "r": return KeyCodeConstants.Letter.r
    case "y": return KeyCodeConstants.Letter.y
    case "t": return KeyCodeConstants.Letter.t
    case "1", "one": return KeyCodeConstants.Number.one
    case "2", "two": return KeyCodeConstants.Number.two
    case "3", "three": return KeyCodeConstants.Number.three
    case "4", "four": return KeyCodeConstants.Number.four
    case "5", "five": return KeyCodeConstants.Number.five
    case "6", "six": return KeyCodeConstants.Number.six
    case "7", "seven": return KeyCodeConstants.Number.seven
    case "8", "eight": return KeyCodeConstants.Number.eight
    case "9", "nine": return KeyCodeConstants.Number.nine
    case "0", "zero": return KeyCodeConstants.Number.zero
    case "space": return KeyCodeConstants.Special.space
    case "return", "enter": return KeyCodeConstants.Special.returnKey
    case "tab": return KeyCodeConstants.Special.tab
    case "escape", "esc": return KeyCodeConstants.Special.escape
    case "backspace", "delete": return KeyCodeConstants.Special.backspace
    case "up": return 0x3E
    case "down": return 0x3D
    case "left": return 0x3B
    case "right": return 0x3C
    case "command", "cmd", "⌘": return 0x37
    case "control", "ctrl", "⌃": return 0x3B
    case "option", "opt", "alt", "⌥": return 0x3A
    case "shift", "⇧": return 0x38
    case "capslock", "caps": return 0x39
    case "f1": return 0x7A
    case "f2": return 0x78
    case "f3": return 0x63
    case "f4": return 0x76
    case "f5": return 0x60
    case "f6": return 0x61
    case "f7": return 0x62
    case "f8": return 0x64
    case "f9": return 0x65
    case "f10": return 0x6D
    case "f11": return 0x67
    case "f12": return 0x6F
    case "f13": return 0x69
    case "f14": return 0x6B
    case "f15": return 0x71
    case "f16": return 0x6A
    case "f17": return 0x40
    case "f18": return 0x4F
    case "f19": return 0x42
    case "home": return 0x73
    case "end": return 0x77
    case "pageup": return 0x74
    case "pagedown": return 0x79
    case "help": return 0x72
    default: return KeyCodeConstants.unmapped
    }
  }

  public static func isModifierKey(_ keyCode: UInt16) -> Bool {
    switch keyCode {
    case 0x37, 0x3B, 0x3A, 0x38, 0x39:
      return true
    default:
      return false
    }
  }
}
