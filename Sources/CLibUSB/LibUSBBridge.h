#ifndef LibUSBBridge_h
#define LibUSBBridge_h

#include <stddef.h>
#include <stdint.h>

typedef struct libusb_context libusb_context;
typedef struct libusb_device libusb_device;
typedef struct libusb_device_handle libusb_device_handle;

#define LIBUSB_SUCCESS 0
#define LIBUSB_ERROR_IO -1
#define LIBUSB_ERROR_INVALID_PARAM -2
#define LIBUSB_ERROR_ACCESS -3
#define LIBUSB_ERROR_NO_DEVICE -4
#define LIBUSB_ERROR_NOT_FOUND -5
#define LIBUSB_ERROR_BUSY -6
#define LIBUSB_ERROR_TIMEOUT -7
#define LIBUSB_ERROR_PIPE -8
#define LIBUSB_ERROR_INTERRUPTED -10
#define LIBUSB_ERROR_NO_MEM -11
#define LIBUSB_ERROR_NOT_SUPPORTED -12

#define LIBUSB_TRANSFER_TYPE_INTERRUPT 3

#define LIBUSB_ENDPOINT_IN 0x80
#define LIBUSB_ENDPOINT_OUT 0x00

int libusb_init(libusb_context **ctx);
void libusb_exit(libusb_context *ctx);

libusb_device_handle *libusb_open_device_with_vid_pid(libusb_context *ctx,
                                                      uint16_t vid,
                                                      uint16_t pid);
void libusb_close(libusb_device_handle *dev_handle);

int libusb_kernel_driver_active(libusb_device_handle *dev_handle,
                                int interface_number);
int libusb_detach_kernel_driver(libusb_device_handle *dev_handle,
                                int interface_number);
int libusb_attach_kernel_driver(libusb_device_handle *dev_handle,
                                int interface_number);

int libusb_claim_interface(libusb_device_handle *dev_handle,
                           int interface_number);
int libusb_release_interface(libusb_device_handle *dev_handle,
                             int interface_number);

int libusb_interrupt_transfer(libusb_device_handle *dev_handle,
                              unsigned char endpoint, unsigned char *data,
                              int length, int *actual_length,
                              unsigned int timeout);

int libusb_reset_device(libusb_device_handle *dev_handle);

#endif /* LibUSBBridge_h */
