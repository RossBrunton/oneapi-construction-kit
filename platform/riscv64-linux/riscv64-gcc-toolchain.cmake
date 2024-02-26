# Copyright (C) Codeplay Software Limited
#
# Licensed under the Apache License, Version 2.0 (the "License") with LLVM
# Exceptions; you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://github.com/codeplaysoftware/oneapi-construction-kit/blob/main/LICENSE.txt
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

# Note: By default this looks for tools in `/usr/bin`, which is where the
# Ubuntu `gcc-*-riscv64-linux-gnu` packages place it.
# For building OCK, qemu is also required (`qemu-user` in Ubuntu).

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR riscv64)

if(CMAKE_HOST_SYSTEM_NAME STREQUAL Windows)
  message(FATAL_ERROR "Cross-compiling for RV64 Linux is not supported on \
    Windows")
endif()

set(TOOLCHAIN_ROOT "/usr" CACHE PATH "path to toolchain root directory")
set(CMAKE_TRY_COMPILE_PLATFORM_VARIABLES TOOLCHAIN_ROOT)
if (NOT TOOLCHAIN_ROOT)
  message(FATAL_ERROR "TOOLCHAIN_ROOT must be defined when using the riscv64 \
    toolchain!")
endif()

set(TRIPLE riscv64-linux-gnu)

# LLVM requires GCC 7 or up
find_program(CMAKE_C_COMPILER NAMES
             "${TOOLCHAIN_TRIPLE}-gcc"
             "${TOOLCHAIN_TRIPLE}-gcc-13"
             "${TOOLCHAIN_TRIPLE}-gcc-12"
             "${TOOLCHAIN_TRIPLE}-gcc-11"
             "${TOOLCHAIN_TRIPLE}-gcc-10"
             "${TOOLCHAIN_TRIPLE}-gcc-9"
             "${TOOLCHAIN_TRIPLE}-gcc-8"
             "${TOOLCHAIN_TRIPLE}-gcc-7"
             PATHS "${TOOLCHAIN_ROOT}/bin/" DOC "gcc")

find_program(CMAKE_CXX_COMPILER NAMES
             "${TOOLCHAIN_TRIPLE}-g++"
             "${TOOLCHAIN_TRIPLE}-g++-13"
             "${TOOLCHAIN_TRIPLE}-g++-12"
             "${TOOLCHAIN_TRIPLE}-g++-11"
             "${TOOLCHAIN_TRIPLE}-g++-10"
             "${TOOLCHAIN_TRIPLE}-g++-9"
             "${TOOLCHAIN_TRIPLE}-g++-8"
             "${TOOLCHAIN_TRIPLE}-g++-7"
             PATHS "${TOOLCHAIN_ROOT}/bin/" DOC "g++")

set(CMAKE_AR "${TOOLCHAIN_ROOT}/bin/${TRIPLE}-ar" CACHE PATH "archive" FORCE)
set(CMAKE_LINKER "${TOOLCHAIN_ROOT}/bin/${TRIPLE}-ld" CACHE PATH "linker" FORCE)
set(CMAKE_NM "${TOOLCHAIN_ROOT}/bin/${TRIPLE}-nm" CACHE PATH "nm" FORCE)
set(CMAKE_OBJCOPY "${TOOLCHAIN_ROOT}/bin/${TRIPLE}-objcopy" CACHE PATH "objcopy" FORCE)
set(CMAKE_OBJDUMP "${TOOLCHAIN_ROOT}/bin/${TRIPLE}-objdump" CACHE PATH "objdump" FORCE)
set(CMAKE_STRIP "${TOOLCHAIN_ROOT}/bin/${TRIPLE}-strip" CACHE PATH "strip" FORCE)
set(CMAKE_RANLIB "${TOOLCHAIN_ROOT}/bin/${TRIPLE}-ranlib" CACHE PATH "ranlib" FORCE)

find_program(QEMU_RISCV64_EXECUTABLE qemu-riscv64)
if(NOT QEMU_RISCV64_EXECUTABLE MATCHES NOTFOUND)
  set(CMAKE_CROSSCOMPILING_EMULATOR
    ${QEMU_RISCV64_EXECUTABLE} -L ${CMAKE_FIND_ROOT_PATH}
    CACHE STRING "qemu" FORCE)
endif()

set(TARGET_FLAGS "")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${BASE_FLAGS} " CACHE STRING "c flags" FORCE)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${BASE_FLAGS}" CACHE STRING "c++ flags" FORCE)

set(LINKER_FLAGS "${TARGET_FLAGS}")
set(LINKER_LIBS "")
set(CMAKE_SHARED_LINKER_FLAGS "${LINKER_FLAGS}" CACHE STRING "linker flags" FORCE)
set(CMAKE_MODULE_LINKER_FLAGS "${LINKER_FLAGS}" CACHE STRING "linker flags" FORCE)
set(CMAKE_EXE_LINKER_FLAGS "${LINKER_FLAGS}" CACHE STRING "linker flags" FORCE)

set(CMAKE_CXX_LINK_EXECUTABLE "<CMAKE_CXX_COMPILER> <CMAKE_CXX_LINK_FLAGS> <LINK_FLAGS> -o <TARGET>  <OBJECTS> <LINK_LIBRARIES> ${LINKER_LIBS}" CACHE STRING "Linker command line" FORCE)
