import CLibUSB
import Foundation
import Logging

@usableFromInline internal let kDefaultTimeout: UInt32 = 5000
private let kIsoMaxPacketSize = 1024
private let kIsoDefaultReadLength = 2048

public extension USBDeviceHandle {
  func bulkTransfer(
    endpoint: UInt8,
    data: Data,
    timeout: UInt32 = kDefaultTimeout
  ) throws -> Int {
    USBDeviceHandle.logger.debug("Bulk transfer OUT to endpoint \(endpoint): \(data.count) bytes")

    let transferred = try bulkWrite(on: handle, to: endpoint, data: data, timeout: timeout)

    USBDeviceHandle.logger.debug("Bulk transfer completed: \(transferred) bytes transferred")
    return transferred
  }

  func readBulk(
    endpoint: UInt8,
    length: Int,
    timeout: UInt32 = kDefaultTimeout
  ) throws -> Data {
    USBDeviceHandle.logger.debug(
      "Bulk transfer IN from endpoint \(endpoint): requesting \(length) bytes"
    )

    let resultData = try bulkRead(on: handle, from: endpoint, length: length, timeout: timeout)

    USBDeviceHandle.logger.debug("Bulk transfer completed: \(resultData.count) bytes read")
    return resultData
  }
}

public extension USBDeviceHandle {
  func interruptTransfer(
    endpoint: UInt8,
    data: [UInt8],
    timeout: UInt32 = kDefaultTimeout
  ) throws -> Int {
    USBDeviceHandle.logger.debug(
      "Interrupt transfer OUT to endpoint \(endpoint): \(data.count) bytes"
    )
    var transferred: Int32 = 0
    var buffer = data

    let result = buffer.withUnsafeMutableBufferPointer { ptr in
      libusb_interrupt_transfer(
        handle,
        endpoint,
        ptr.baseAddress,
        Int32(data.count),
        &transferred,
        timeout
      )
    }

    if result < 0 {
      USBDeviceHandle.logger.error("Interrupt transfer failed with error \(result)")
      try USBError.check(result)
    } else {
      USBDeviceHandle.logger.debug("Interrupt transfer completed: \(transferred) bytes transferred")
    }

    return Int(transferred)
  }

  func readInterrupt(
    endpoint: UInt8,
    length: Int,
    timeout: UInt32 = kDefaultTimeout
  ) throws -> [UInt8] {
    USBDeviceHandle.logger.debug(
      "Interrupt transfer IN from endpoint \(endpoint): requesting \(length) bytes"
    )
    var buffer = [UInt8](repeating: 0, count: length)
    var transferred: Int32 = 0

    let result = buffer.withUnsafeMutableBufferPointer { ptr in
      libusb_interrupt_transfer(
        handle,
        endpoint,
        ptr.baseAddress,
        Int32(length),
        &transferred,
        timeout
      )
    }

    try USBError.check(result)
    let resultData = Array(buffer[0..<Int(transferred)])
    USBDeviceHandle.logger.debug("Interrupt transfer completed: \(transferred) bytes read")
    return resultData
  }
}

public extension USBDeviceHandle {
  func isochronousTransfer(
    endpoint: UInt8,
    data: Data,
    timeout: UInt32 = kDefaultTimeout
  ) async throws -> Int {
    USBDeviceHandle.logger.debug(
      "Isochronous transfer OUT to endpoint \(endpoint): \(data.count) bytes"
    )

    return try await withCheckedThrowingContinuation { continuation in
      guard
        let transfer = allocateIsoTransferBuffer(
          bufferSize: data.count,
          endpoint: endpoint,
          timeout: timeout,
          continuation: continuation
        )
      else {
        return
      }

      submitTransfer(transfer: transfer, endpoint: endpoint, continuation: continuation)
    }
  }

  func readIsochronous(
    endpoint: UInt8,
    length: Int,
    timeout: UInt32 = kDefaultTimeout
  ) async throws -> Data {
    USBDeviceHandle.logger.debug(
      "Isochronous transfer IN from endpoint \(endpoint): requesting \(length) bytes"
    )

    return try await withCheckedThrowingContinuation { continuation in
      guard
        let transfer = createIsochronousReadTransfer(
          endpoint: endpoint,
          length: length,
          timeout: timeout,
          continuation: continuation
        )
      else {
        return
      }

      submitIsochronousReadTransfer(transfer: transfer, continuation: continuation)
    }
  }
}

internal extension USBDeviceHandle {
  func allocateIsoTransferBuffer(
    bufferSize: Int,
    endpoint: UInt8,
    timeout: UInt32,
    continuation: CheckedContinuation<Int, Error>
  ) -> UnsafeMutablePointer<libusb_transfer>? {
    var buffer = [UInt8](repeating: 0, count: bufferSize)

    guard let transfer = libusb_alloc_transfer(0) else {
      continuation.resume(throwing: USBError(code: -1))
      return nil
    }

    let numPackets = (bufferSize + kIsoMaxPacketSize - 1) / kIsoMaxPacketSize

    let continuationHolder = IsoContinuationHolder<Int>()
    continuationHolder.continuation = continuation

    buffer.withUnsafeMutableBufferPointer { bufferPtr in
      libusb_fill_iso_transfer(
        transfer,
        handle,
        endpoint,
        bufferPtr.baseAddress,
        Int32(bufferSize),
        Int32(numPackets),
        { (transfer: UnsafeMutablePointer<libusb_transfer>?) in
          guard let transfer else {
            return
          }

          let status = transfer.pointee.status

          let holder =
            Unmanaged<IsoContinuationHolder<Int>>.fromOpaque(
              transfer.pointee.user_data
            )
            .takeRetainedValue() as IsoContinuationHolder<Int>

          switch status {
          case LIBUSB_TRANSFER_COMPLETED:
            let bytesTransferred = Int(transfer.pointee.actual_length)
            USBDeviceHandle.logger.debug(
              "Isochronous transfer completed: \(bytesTransferred) bytes"
            )
            holder.continuation?.resume(returning: bytesTransferred)

          case LIBUSB_TRANSFER_ERROR:
            USBDeviceHandle.logger.error("Isochronous transfer error")
            holder.continuation?.resume(throwing: USBError(code: -1))

          default:
            USBDeviceHandle.logger.debug("Isochronous transfer unknown status: \(status)")
            holder.continuation?.resume(throwing: USBError(code: -1))
          }

          libusb_free_transfer(transfer)
        },
        UnsafeMutableRawPointer(Unmanaged.passRetained(continuationHolder).toOpaque()),
        timeout
      )
    }

    transfer.pointee.num_iso_packets = Int32(numPackets)
    return transfer
  }

  func submitTransfer(
    transfer: UnsafeMutablePointer<libusb_transfer>,
    endpoint: UInt8,
    continuation: CheckedContinuation<Int, Error>
  ) {
    let result = libusb_submit_transfer(transfer)

    if result < 0 {
      USBDeviceHandle.logger.error("Failed to submit isochronous transfer: error \(result)")
      libusb_free_transfer(transfer)
      continuation.resume(throwing: USBError(code: result))
    }
  }

  func createIsochronousReadTransfer(
    endpoint: UInt8,
    length: Int,
    timeout: UInt32,
    continuation: CheckedContinuation<Data, Error>
  ) -> UnsafeMutablePointer<libusb_transfer>? {
    var buffer = [UInt8](repeating: 0, count: length)

    guard let transfer = libusb_alloc_transfer(0) else {
      continuation.resume(throwing: USBError(code: -1))
      return nil
    }

    let numPackets = calculateIsoPacketCount(length: length)
    let continuationHolder = IsoContinuationHolder<Data>()
    continuationHolder.continuation = continuation

    buffer.withUnsafeMutableBufferPointer { bufferPtr in
      libusb_fill_iso_transfer(
        transfer,
        handle,
        endpoint,
        bufferPtr.baseAddress,
        Int32(length),
        Int32(numPackets),
        isoReadTransferCallback,
        UnsafeMutableRawPointer(Unmanaged.passRetained(continuationHolder).toOpaque()),
        timeout
      )
    }

    transfer.pointee.num_iso_packets = Int32(numPackets)
    return transfer
  }

  func calculateIsoPacketCount(length: Int) -> Int {
    (length + kIsoMaxPacketSize - 1) / kIsoMaxPacketSize
  }

  func submitIsochronousReadTransfer(
    transfer: UnsafeMutablePointer<libusb_transfer>,
    continuation: CheckedContinuation<Data, Error>
  ) {
    let result = libusb_submit_transfer(transfer)

    if result < 0 {
      USBDeviceHandle.logger.error("Failed to submit isochronous read transfer: error \(result)")
      libusb_free_transfer(transfer)
      continuation.resume(throwing: USBError(code: result))
    }
  }

  func handleIsoReadCompletion(
    transfer: UnsafeMutablePointer<libusb_transfer>,
    holder: IsoContinuationHolder<Data>
  ) {
    let status = transfer.pointee.status
    let bytesTransferred = Int(transfer.pointee.actual_length)

    switch status {
    case LIBUSB_TRANSFER_COMPLETED:
      USBDeviceHandle.logger.debug("Isochronous read completed: \(bytesTransferred) bytes")
      let bufferPtr = transfer.pointee.buffer
      var resultData = Data()
      if let bufferPtr, bytesTransferred > 0 {
        resultData = Data(bytes: bufferPtr, count: bytesTransferred)
      }
      holder.continuation?.resume(returning: resultData)

    case LIBUSB_TRANSFER_ERROR:
      USBDeviceHandle.logger.error("Isochronous read error")
      holder.continuation?.resume(throwing: USBError(code: -1))

    case LIBUSB_TRANSFER_TIMED_OUT:
      USBDeviceHandle.logger.debug("Isochronous read timed out")
      holder.continuation?.resume(throwing: USBError(code: -110))

    case LIBUSB_TRANSFER_CANCELLED:
      USBDeviceHandle.logger.debug("Isochronous read cancelled")
      holder.continuation?.resume(throwing: USBError(code: -1))

    case LIBUSB_TRANSFER_NO_DEVICE:
      USBDeviceHandle.logger.error("Isochronous read - device disconnected")
      holder.continuation?.resume(throwing: USBError(code: -1))

    case LIBUSB_TRANSFER_OVERFLOW:
      USBDeviceHandle.logger.error("Isochronous read overflow")
      holder.continuation?.resume(throwing: USBError(code: -1))

    default:
      USBDeviceHandle.logger.debug("Isochronous read unknown status: \(status)")
      holder.continuation?.resume(throwing: USBError(code: -1))
    }

    libusb_free_transfer(transfer)
  }
}

private func isoReadTransferCallback(_ transfer: UnsafeMutablePointer<libusb_transfer>?) {
  guard let transfer else {
    return
  }

  let status = transfer.pointee.status
  let holder = Unmanaged<IsoContinuationHolder<Data>>.fromOpaque(transfer.pointee.user_data)
    .takeRetainedValue()

  handleIsoReadStatus(status: status, transfer: transfer, holder: holder)
  libusb_free_transfer(transfer)
}

private func handleIsoReadStatus(
  status: libusb_transfer_status,
  transfer: UnsafeMutablePointer<libusb_transfer>,
  holder: IsoContinuationHolder<Data>
) {
  let bytesTransferred = Int(transfer.pointee.actual_length)

  switch status {
  case LIBUSB_TRANSFER_COMPLETED:
    USBDeviceHandle.logger.debug("Isochronous read completed: \(bytesTransferred) bytes")
    let bufferPtr = transfer.pointee.buffer
    var resultData = Data()
    if let bufferPtr, bytesTransferred > 0 {
      resultData = Data(bytes: bufferPtr, count: bytesTransferred)
    }
    holder.continuation?.resume(returning: resultData)

  case LIBUSB_TRANSFER_ERROR:
    USBDeviceHandle.logger.error("Isochronous read error")
    holder.continuation?.resume(throwing: USBError(code: -1))

  case LIBUSB_TRANSFER_TIMED_OUT:
    USBDeviceHandle.logger.debug("Isochronous read timed out")
    holder.continuation?.resume(throwing: USBError(code: -110))

  case LIBUSB_TRANSFER_CANCELLED:
    USBDeviceHandle.logger.debug("Isochronous read cancelled")
    holder.continuation?.resume(throwing: USBError(code: -1))

  case LIBUSB_TRANSFER_NO_DEVICE:
    USBDeviceHandle.logger.error("Isochronous read - device disconnected")
    holder.continuation?.resume(throwing: USBError(code: -1))

  case LIBUSB_TRANSFER_OVERFLOW:
    USBDeviceHandle.logger.error("Isochronous read overflow")
    holder.continuation?.resume(throwing: USBError(code: -1))

  default:
    USBDeviceHandle.logger.debug("Isochronous read unknown status: \(status)")
    holder.continuation?.resume(throwing: USBError(code: -1))
  }
}

internal final class ContinuationHolder<T> {
  internal var continuation: CheckedContinuation<T, Error>?
}

internal final class IsoContinuationHolder<T> {
  internal var continuation: CheckedContinuation<T, Error>?
}
