#if os(Linux)
import CLibUSB
import Foundation

typealias timeval = libusb_timeval

extension timeval {
  init(seconds: Int32, microseconds: Int32) {
    self.init(tv_sec: seconds, tv_usec: microseconds)
  }
}
#endif
