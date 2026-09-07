cmake_minimum_required(VERSION 3.13)

include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)

project(gb_cart_rp2040 C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(gb_cart_rp2040
    src/main.c
)

target_link_libraries(gb_cart_rp2040
    pico_stdlib
    hardware_spi
)

# USB CDC is our bring-up console. UART is intentionally disabled because
# GP0/GP1 are used by the SPI link to the FPGA.
pico_enable_stdio_usb(gb_cart_rp2040 1)
pico_enable_stdio_uart(gb_cart_rp2040 0)

pico_add_extra_outputs(gb_cart_rp2040)
