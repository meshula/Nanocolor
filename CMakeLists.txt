cmake_minimum_required(VERSION 3.15)
project(nanocolor VERSION 1.0.0 LANGUAGES C)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Public headers live flat at the repo root. Consumers use <nanocolor/...>, so
# stage them under a nanocolor/ prefix in the build tree to give the build and
# install interfaces an identical include convention.
set(nanocolor_PUBLIC_HEADERS
    nanocolor.h
    nanocolorProcessing.h
    nanocolorUtils.h)

file(COPY ${nanocolor_PUBLIC_HEADERS}
     DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/include/nanocolor)

# No explicit STATIC/SHARED: honors BUILD_SHARED_LIBS, defaults to STATIC.
# SIMD paths in the sources self-guard on __SSE2__/__ARM_NEON, so no arch flags.
add_library(nanocolor
    nanocolor.c
    nanocolorUtils.c
    ${nanocolor_PUBLIC_HEADERS})

set_target_properties(nanocolor PROPERTIES
    C_STANDARD 11
    C_STANDARD_REQUIRED ON
    # Allow the static build to be linked into a shared library (e.g. a
    # consumer's SHARED target). No-op on macOS where PIC is the default;
    # required for the STATIC-into-SHARED case on Linux.
    POSITION_INDEPENDENT_CODE ON)

# Declare the install include dir exactly once (here, not via
# install(... INCLUDES DESTINATION)) to avoid a duplicated include interface.
target_include_directories(nanocolor
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR})

# glibc needs -lm for the math functions; macOS/MSVC provide them in libc.
if(UNIX AND NOT APPLE)
    target_link_libraries(nanocolor PRIVATE m)
endif()

add_library(Lab::nanocolor ALIAS nanocolor)

install(TARGETS nanocolor
    EXPORT nanocolorTargets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(FILES ${nanocolor_PUBLIC_HEADERS}
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/nanocolor)

install(EXPORT nanocolorTargets
    NAMESPACE Lab::
    FILE nanocolorTargets.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/nanocolor)

configure_package_config_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/nanocolorConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/nanocolorConfig.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/nanocolor)

write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/nanocolorConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion)

install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/nanocolorConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/nanocolorConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/nanocolor)

# Build-tree export so a superbuild can consume Lab::nanocolor without installing.
export(EXPORT nanocolorTargets
    NAMESPACE Lab::
    FILE ${CMAKE_CURRENT_BINARY_DIR}/nanocolorTargets.cmake)
