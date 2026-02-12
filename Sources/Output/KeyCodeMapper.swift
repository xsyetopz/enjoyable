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
    case "up": return KeyCodeConstants.Arrow.up
    case "down": return KeyCodeConstants.Arrow.down
    case "left": return KeyCodeConstants.Arrow.left
    case "right": return KeyCodeConstants.Arrow.right
    case "command", "cmd", "⌘": return KeyCodeConstants.Modifier.command
    case "control", "ctrl", "⌃": return KeyCodeConstants.Modifier.control
    case "option", "opt", "alt", "⌥": return KeyCodeConstants.Modifier.option
    case "shift", "⇧": return KeyCodeConstants.Modifier.shift
    case "capslock", "caps": return KeyCodeConstants.Modifier.capsLock
    case "f1": return KeyCodeConstants.Function.f1
    case "f2": return KeyCodeConstants.Function.f2
    case "f3": return KeyCodeConstants.Function.f3
    case "f4": return KeyCodeConstants.Function.f4
    case "f5": return KeyCodeConstants.Function.f5
    case "f6": return KeyCodeConstants.Function.f6
    case "f7": return KeyCodeConstants.Function.f7
    case "f8": return KeyCodeConstants.Function.f8
    case "f9": return KeyCodeConstants.Function.f9
    case "f10": return KeyCodeConstants.Function.f10
    case "f11": return KeyCodeConstants.Function.f11
    case "f12": return KeyCodeConstants.Function.f12
    case "f13": return KeyCodeConstants.Function.f13
    case "f14": return KeyCodeConstants.Function.f14
    case "f15": return KeyCodeConstants.Function.f15
    case "f16": return KeyCodeConstants.Function.f16
    case "f17": return KeyCodeConstants.Function.f17
    case "f18": return KeyCodeConstants.Function.f18
    case "f19": return KeyCodeConstants.Function.f19
    case "home": return KeyCodeConstants.Navigation.home
    case "end": return KeyCodeConstants.Navigation.end
    case "pageup": return KeyCodeConstants.Navigation.pageUp
    case "pagedown": return KeyCodeConstants.Navigation.pageDown
    case "help": return KeyCodeConstants.Navigation.help
    default: return KeyCodeConstants.unmapped
    }
  }

  public static func isModifierKey(_ keyCode: UInt16) -> Bool {
    switch keyCode {
    case KeyCodeConstants.Modifier.command,
         KeyCodeConstants.Modifier.control,
         KeyCodeConstants.Modifier.option,
         KeyCodeConstants.Modifier.shift,
         KeyCodeConstants.Modifier.capsLock:
      return true
    default:
      return false
    }
  }
}
