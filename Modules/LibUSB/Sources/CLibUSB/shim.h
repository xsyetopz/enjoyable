#ifndef CLibUSB_shim
#define CLibUSB_shim

#if __has_include(<libusb-1.0/libusb.h>)
#include <libusb-1.0/libusb.h>
#elif __has_include(<libusb.h>)
#include <libusb.h>
#else
#error "libusb headers not found"
#endif

#endif
