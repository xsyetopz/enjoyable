import Foundation
import IOKit

@_silgen_name("IOCreatePlugInInterfaceForService")
func IOCreatePlugInInterfaceForServiceRaw(
  _ service: io_service_t,
  _ pluginType: CFUUID,
  _ interfaceType: CFUUID,
  _ theInterface: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
  _ score: UnsafeMutablePointer<Int32>
) -> KernReturn

@_silgen_name("IODestroyPlugInInterface")
func IODestroyPlugInInterface(_ theInterface: UnsafeMutableRawPointer) -> KernReturn

@_silgen_name("IOObjectRelease")
func IOObjectRelease(_ object: IOObject) -> KernReturn

@_silgen_name("IOIteratorNext")
func IOIteratorNext(_ iterator: IOIterator) -> IOObject

@_silgen_name("enumerate_usb_devices_c")
func enumerateUSBDevices(_ iterator: UnsafeMutablePointer<IOIterator>) -> KernReturn

@_silgen_name("IOServiceGetMatchingServices")
func IOServiceGetMatchingServices(
  _ masterPort: mach_port_t,
  _ matching: CFDictionary?,
  _ existing: UnsafeMutablePointer<IOIterator>
) -> KernReturn

@_silgen_name("IORegistryEntryCreateCFProperty")
func IORegistryEntryCreateCFProperty(
  _ entry: IORegistryEntry,
  _ key: CFString,
  _ allocator: CFAllocator?,
  _ options: IOOptionBits
) -> Unmanaged<CFTypeRef>?

@_silgen_name("IORegistryEntryGetParentEntry")
func IORegistryEntryGetParentEntry(
  _ entry: IORegistryEntry,
  _ plane: UnsafePointer<Int8>,
  _ parent: UnsafeMutablePointer<IORegistryEntry>
) -> KernReturn

@_silgen_name("IORegistryEntryGetName")
func IORegistryEntryGetName(
  _ entry: IORegistryEntry,
  _ name: UnsafeMutablePointer<Int8>
) -> KernReturn

enum IOKitInterface {
  static func getQueryInterface(
    _ interface: UnsafeMutableRawPointer
  ) -> (
    @convention(c) (UnsafeMutableRawPointer, CFUUID) -> UnsafeMutableRawPointer?
  )? {
    let vtablePtr = interface.advanced(by: 2 * MemoryLayout<UnsafeMutableRawPointer>.stride)
    let vtable = vtablePtr.assumingMemoryBound(to: UnsafeMutableRawPointer.self).pointee
    return vtable.assumingMemoryBound(
      to: (@convention(c) (
        UnsafeMutableRawPointer,
        CFUUID
      ) -> UnsafeMutableRawPointer?).self
    ).pointee
  }

  static func getDeviceOpen(
    _ interface: UnsafeMutableRawPointer
  ) -> (
    @convention(c) (UnsafeMutableRawPointer, UInt8) -> KernReturn
  )? {
    let offset = 4 + 3 * MemoryLayout<UnsafeMutableRawPointer>.stride
    let funcPtr = getVTable(interface).advanced(by: offset)
    return funcPtr.assumingMemoryBound(
      to: (@convention(c) (
        UnsafeMutableRawPointer,
        UInt8
      ) -> KernReturn).self
    ).pointee
  }

  static func getDeviceClose(
    _ interface: UnsafeMutableRawPointer
  ) -> (
    @convention(c) (UnsafeMutableRawPointer) -> KernReturn
  )? {
    let offset = 4 + 4 * MemoryLayout<UnsafeMutableRawPointer>.stride
    let funcPtr = getVTable(interface).advanced(by: offset)
    return funcPtr.assumingMemoryBound(
      to: (@convention(c) (
        UnsafeMutableRawPointer
      ) -> KernReturn).self
    ).pointee
  }

  static func getCreateInterfaceIterator(
    _ interface: UnsafeMutableRawPointer
  ) -> (
    @convention(c) (
      UnsafeMutableRawPointer,
      UnsafeMutablePointer<IOIterator>?
    ) -> KernReturn
  )? {
    let offset = 4 + 9 * MemoryLayout<UnsafeMutableRawPointer>.stride
    let funcPtr = getVTable(interface).advanced(by: offset)
    return funcPtr.assumingMemoryBound(
      to: (@convention(c) (
        UnsafeMutableRawPointer,
        UnsafeMutablePointer<IOIterator>?
      ) -> KernReturn).self
    ).pointee
  }

  static func getInterfaceOpen(
    _ interface: UnsafeMutableRawPointer
  ) -> (
    @convention(c) (UnsafeMutableRawPointer) -> KernReturn
  )? {
    let offset = 4 + 3 * MemoryLayout<UnsafeMutableRawPointer>.stride
    let funcPtr = getVTable(interface).advanced(by: offset)
    return funcPtr.assumingMemoryBound(
      to: (@convention(c) (
        UnsafeMutableRawPointer
      ) -> KernReturn).self
    ).pointee
  }

  static func getInterfaceClose(
    _ interface: UnsafeMutableRawPointer
  ) -> (
    @convention(c) (UnsafeMutableRawPointer) -> KernReturn
  )? {
    let offset = 4 + 4 * MemoryLayout<UnsafeMutableRawPointer>.stride
    let funcPtr = getVTable(interface).advanced(by: offset)
    return funcPtr.assumingMemoryBound(
      to: (@convention(c) (
        UnsafeMutableRawPointer
      ) -> KernReturn).self
    ).pointee
  }

  static func getReadPipe(
    _ interface: UnsafeMutableRawPointer
  ) -> (
    @convention(c) (
      UnsafeMutableRawPointer,
      UInt8,
      UnsafeMutableRawPointer?,
      UInt32,
      UnsafeMutablePointer<UInt32>?,
      UnsafeMutableRawPointer?,
      UnsafeMutableRawPointer?,
      UnsafeMutableRawPointer?
    ) -> KernReturn
  )? {
    let offset = 4 + 12 * MemoryLayout<UnsafeMutableRawPointer>.stride
    let funcPtr = getVTable(interface).advanced(by: offset)
    return funcPtr.assumingMemoryBound(
      to: (@convention(c) (
        UnsafeMutableRawPointer,
        UInt8,
        UnsafeMutableRawPointer?,
        UInt32,
        UnsafeMutablePointer<UInt32>?,
        UnsafeMutableRawPointer?,
        UnsafeMutableRawPointer?,
        UnsafeMutableRawPointer?
      ) -> KernReturn).self
    ).pointee
  }

  static func getWritePipe(
    _ interface: UnsafeMutableRawPointer
  ) -> (
    @convention(c) (
      UnsafeMutableRawPointer,
      UInt8,
      UnsafeMutableRawPointer?,
      UInt32,
      UnsafeMutablePointer<UInt32>?,
      UInt32,
      UnsafeMutableRawPointer?,
      UnsafeMutableRawPointer?
    ) -> KernReturn
  )? {
    let offset = 4 + 13 * MemoryLayout<UnsafeMutableRawPointer>.stride
    let funcPtr = getVTable(interface).advanced(by: offset)
    return funcPtr.assumingMemoryBound(
      to: (@convention(c) (
        UnsafeMutableRawPointer,
        UInt8,
        UnsafeMutableRawPointer?,
        UInt32,
        UnsafeMutablePointer<UInt32>?,
        UInt32,
        UnsafeMutableRawPointer?,
        UnsafeMutableRawPointer?
      ) -> KernReturn).self
    ).pointee
  }

  static func getNumEndpoints(
    _ interface: UnsafeMutableRawPointer
  ) -> (
    @convention(c) (
      UnsafeMutableRawPointer,
      UnsafeMutablePointer<UInt8>?
    ) -> KernReturn
  )? {
    let offset = 4 + 54 * MemoryLayout<UnsafeMutableRawPointer>.stride
    let funcPtr = getVTable(interface).advanced(by: offset)
    return funcPtr.assumingMemoryBound(
      to: (@convention(c) (
        UnsafeMutableRawPointer,
        UnsafeMutablePointer<UInt8>?
      ) -> KernReturn).self
    ).pointee
  }

  static func getPipeProperties(
    _ interface: UnsafeMutableRawPointer
  ) -> (
    @convention(c) (
      UnsafeMutableRawPointer,
      UInt8,
      UnsafeMutablePointer<UInt8>?,
      UnsafeMutablePointer<UInt8>?,
      UnsafeMutablePointer<UInt8>?,
      UnsafeMutablePointer<UInt16>?,
      UnsafeMutablePointer<UInt8>?
    ) -> KernReturn
  )? {
    let offset = 4 + 55 * MemoryLayout<UnsafeMutableRawPointer>.stride
    let funcPtr = getVTable(interface).advanced(by: offset)
    return funcPtr.assumingMemoryBound(
      to: (@convention(c) (
        UnsafeMutableRawPointer,
        UInt8,
        UnsafeMutablePointer<UInt8>?,
        UnsafeMutablePointer<UInt8>?,
        UnsafeMutablePointer<UInt8>?,
        UnsafeMutablePointer<UInt16>?,
        UnsafeMutablePointer<UInt8>?
      ) -> KernReturn).self
    ).pointee
  }

  private static func getVTable(_ interface: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
    return interface.assumingMemoryBound(to: UnsafeMutableRawPointer.self).pointee
  }
}
