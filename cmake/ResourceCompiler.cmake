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

if(COMMAND add_resources AND COMMAND target_resources)
  return()  # Do nothing since the module was already included.
endif()

if(CMAKE_SYSTEM_NAME STREQUAL Windows)
  set(RC_ID_COUNTER 100 CACHE INTERNAL "Global resource compiler ID counter")
endif()

#[=======================================================================[.rst:
.. cmake:command:: add_resources

  Add a set of binary resource files to later be compiled into an executable or
  shared library with :cmake:command:`target_resources`.

  Keyword Arguments:
    * ``NAMESPACE`` - a unique name to reference this group of resources, must be
      a valid C identifier.
    * ``HEADER_FILE`` - an absolute path specifying where the generated header
      file should reside, usually within the binary directory.
    * ``RESOURCES`` - a list of absolute paths to binary resource, these may be
      generated as part of the build.
    * ``DEPENDS`` - a list of dependencies for the generated custom target to
      depend unpon.
#]=======================================================================]
function(add_resources)
  cmake_parse_arguments(args
    ""                        # options
    "NAMESPACE;HEADER_FILE"   # one value keywords
    "RESOURCES;DEPENDS"       # multi value keywords
    ${ARGN})

  if(NOT args_NAMESPACE)
    message(FATAL_ERROR "A NAMESPACE must be provided.")
  endif()
  if(NOT args_HEADER_FILE)
    message(FATAL_ERROR "A HEADER_FILE must be provided.")
  endif()
  list(LENGTH args_RESOURCES num_resources)
  if(num_resources EQUAL 0)
    message(FATAL_ERROR "One or more RESOURCES must be provided.")
  endif()

  # Create a header to access the resources, first determine the filename.
  string(REPLACE "${CMAKE_BINARY_DIR}/" "" header_file ${args_HEADER_FILE})
  string(REGEX REPLACE "[-\/\\\\\.]" "_" header_name ${header_file})
  string(TOUPPER ${header_name} HEADER_NAME)

  get_filename_component(header_dir ${args_HEADER_FILE} DIRECTORY)
  if(NOT EXISTS ${header_dir})
    file(MAKE_DIRECTORY ${header_dir})
  endif()

  # Take a copy of the list of resource files in case the paths need modified.
  set(resources ${args_RESOURCES})

  if(CMAKE_SYSTEM_NAME STREQUAL Linux OR CMAKE_SYSTEM_NAME STREQUAL Darwin)
    file(WRITE ${args_HEADER_FILE} "\
// Copyright (C) Codeplay Software Limited
//
// Licensed under the Apache License, Version 2.0 (the \"License\") with LLVM
// Exceptions; you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://github.com/codeplaysoftware/oneapi-construction-kit/blob/main/LICENSE.txt
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an \"AS IS\" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations
// under the License.
//
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

// This file is automatically generated during CMake configuration.

#ifndef ${HEADER_NAME}_INCLUDED
#define ${HEADER_NAME}_INCLUDED

#include <cstdint>

#include \"cargo/array_view.h\"

extern \"C\" {
")
    foreach(resource ${args_RESOURCES})
      get_filename_component(name ${resource} NAME)
      string(REGEX REPLACE "[-\\.]" "_" name ${name})
      set(cname ${args_NAMESPACE}_${name})
      file(APPEND ${args_HEADER_FILE} "
extern uint8_t ${cname}_data[];
extern uint32_t ${cname}_size;
")
    endforeach()
    file(APPEND ${args_HEADER_FILE} "
}  // extern \"C\"

namespace rc {
namespace ${args_NAMESPACE} {
")

    foreach(resource ${args_RESOURCES})
      get_filename_component(name ${resource} NAME)
      string(REGEX REPLACE "[-\\.]" "_" name ${name})
      set(cname ${args_NAMESPACE}_${name})
      file(APPEND ${args_HEADER_FILE} "
/// Resource compiled from ${resource}.
static ::cargo::array_view<const uint8_t> ${name}(
    ${cname}_data, ${cname}_size);
")
    endforeach()
    file(APPEND ${args_HEADER_FILE} "
}  // namespace ${args_NAMESPACE}
}  // namespace rc

#endif  // ${HEADER_NAME}_INCLUDED
")

  elseif(CMAKE_SYSTEM_NAME STREQUAL Windows)

    # The Windows resource compiler tool (rc.exe) does not automatically add a
    # null terminator to the resources it compiles into .exe/.dll files. This
    # can be problematic when loading .bc/.pch files into LLVM. To avoid
    # issues we; copy each resource file; append a null terminator to the
    # copied file; then use the list of null terminated resource files when
    # generating the .rc file in target_resources() step later on.
    set(resources)
    set(append_null_byte
      ${ComputeAorta_SOURCE_DIR}/scripts/append_null_byte.py)
    file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/resources)
    foreach(resource ${args_RESOURCES})
      get_filename_component(name ${resource} NAME)
      set(nulled_resource ${CMAKE_CURRENT_BINARY_DIR}/resources/${name})
      add_custom_command(OUTPUT ${nulled_resource}
        COMMAND ${CMAKE_COMMAND} -E copy ${resource} ${nulled_resource}
        COMMAND ${PYTHON_EXECUTABLE} ${append_null_byte} ${nulled_resource}
        DEPENDS ${resource} ${append_null_byte}
        COMMENT "Prepare RCDATA ${nulled_resource}")
      list(APPEND resources ${nulled_resource})
    endforeach()

    # Generate a header containing ID macros to be used by both the .rc
    # compiler and user code. The global variable RC_ID_COUNTER is used to
    # ensure that resources have globally unique ID's when compiled. C++ code
    # for use in the application which can not be parsed by rc.exe is wrapped
    # in #ifndef RC_INVOKED.
    file(WRITE ${args_HEADER_FILE} "\
// Copyright (C) Codeplay Software Limited
//
// Licensed under the Apache License, Version 2.0 (the \"License\") with LLVM
// Exceptions; you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://github.com/codeplaysoftware/oneapi-construction-kit/blob/main/LICENSE.txt
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an \"AS IS\" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations
// under the License.
//
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

// This file is automatically generated during CMake configuration.

#ifndef ${HEADER_NAME}_INCLUDED
#define ${HEADER_NAME}_INCLUDED

")

    foreach(resource ${args_RESOURCES})
      get_filename_component(name ${resource} NAME)
      string(REGEX REPLACE "[-\\.]" "_" name ${name})
      set(cname ${args_NAMESPACE}_${name})
      string(TOUPPER ${cname} CNAME)
      file(APPEND ${args_HEADER_FILE} "\
#define ${CNAME}_ID ${RC_ID_COUNTER}
")
      # Increment the global resource compiler ID counter.
      math(EXPR RC_ID_COUNTER "${RC_ID_COUNTER} + 1")
      set(RC_ID_COUNTER ${RC_ID_COUNTER} CACHE INTERNAL
        "Global resource compiler ID counter")
    endforeach()

    file(APPEND ${args_HEADER_FILE} "
#ifndef RC_INVOKED
#include <cassert>
#include <windows.h>

#include \"cargo/array_view.h\"

namespace rc {
namespace detail {
inline cargo::array_view<const uint8_t> load_resource(uint16_t id) {
  HMODULE module = nullptr;
  GetModuleHandleEx(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
                    (LPCTSTR)load_resource, &module);
  assert(module && \"Could not load current module!\");
  HRSRC resource = ::FindResource(module, MAKEINTRESOURCE(id), RT_RCDATA);
  assert(resource && \"Could not load resource!\");
  void* data = ::LockResource(::LoadResource(module, resource));
  assert(data && \"Data was null!\");
  DWORD size = ::SizeofResource(module, resource);
  if (size <= 1) {
    return {};
  }
  size -= 1;  // Account for the additional null terminator.
  return {static_cast<const uint8_t*>(data), static_cast<size_t>(size)};
}
}  // namespace detail

namespace ${args_NAMESPACE} {
")

    foreach(resource ${args_RESOURCES})
      get_filename_component(name ${resource} NAME)
      string(REGEX REPLACE "[-\\.]" "_" name ${name})
      set(cname ${args_NAMESPACE}_${name})
      string(TOUPPER ${cname} CNAME)
      file(APPEND ${args_HEADER_FILE} "\
/// Resource compiled from ${resource}.
static ::cargo::array_view<const uint8_t> ${name}(
    detail::load_resource(${CNAME}_ID));
")
      # Increment the global resource compiler ID counter.
      math(EXPR RC_ID_COUNTER "${RC_ID_COUNTER} + 1")
      set(RC_ID_COUNTER ${RC_ID_COUNTER} CACHE INTERNAL
        "Global resource compiler ID counter")
    endforeach()

    file(APPEND ${args_HEADER_FILE} "
}  // namespace ${args_NAMESPACE}
}  // namespace rc

#endif  // RC_INVOKED

#endif  // ${HEADER_NAME}_INCLUDED
")

  else()
    message(FATAL_ERROR
      "ResourceCompiler doesn't not yet support ${CMAKE_SYSTEM_NAME}")
  endif()

  # Create a target to ensure all binaries in this list can be generated, then
  # only depend on this target when actually embedding. This works around the
  # limitation of CMake where dependencies on files only work within the same
  # directory.
  add_custom_target(resources-${args_NAMESPACE}
    SOURCES ${resources} DEPENDS ${args_DEPENDS})

  # Store the resource list and header file for use later in target_resources.
  set_target_properties(resources-${args_NAMESPACE} PROPERTIES
    RESOURCES "${resources}" RC_HEADER_FILE "${args_HEADER_FILE}")
endfunction()

#[=======================================================================[.rst:
.. cmake:command:: target_resources

  Compile one or more namespaces of binary resources previously defined by
  :cmake:command:`add_resources` into an executable or shared library.

  Arguments:
    * ``target`` - the executable or shared library target name to compile the
      binrary resources into.

  Keyword Arguments:
    * ``NAMESPACES`` - a list of namespaces previously created with
      :cmake:command:`add_resources` to compile into the ``target``.
#]=======================================================================]
function(target_resources target)
  cmake_parse_arguments(args
    ""            # options
    ""            # one value keywords
    "NAMESPACES"  # multi value keywords
    ${ARGN})

  get_target_property(target_type ${target} TYPE)
  if(target_type STREQUAL STATIC_LIBRARY)
    message(FATAL_ERROR "Resources can't be compiled into a static library.")
  endif()

  list(LENGTH args_NAMESPACES num_namespaces)
  if(num_namespaces EQUAL 0)
    message(FATAL_ERROR "One or more NAMESPACES must be provided.")
  endif()

  # Generate the .s/.rc files and add them to the specified target.
  if(CMAKE_SYSTEM_NAME STREQUAL Linux)

    # Generate a .s with incbin directives for each resource in each
    # namespace.
    set(resources_file ${CMAKE_CURRENT_BINARY_DIR}/${target}-resources.s)
    file(WRITE ${resources_file} "\
  .section .rodata
")

    foreach(namespace ${args_NAMESPACES})
      get_target_property(resources resources-${namespace} RESOURCES)
      set_property(SOURCE ${resources_file} APPEND PROPERTY OBJECT_DEPENDS ${resources})

      foreach(resource ${resources})
        get_filename_component(name ${resource} NAME)
        string(REGEX REPLACE "[-\\.]" "_" name ${name})
        set(name ${namespace}_${name})

        file(APPEND ${resources_file} "
  .global ${name}_data
  .align  4
${name}_data:
  .incbin \"${resource}\"
${name}_end:
  .byte   0
  .global ${name}_size
  .align  4
${name}_size:
  .long    ${name}_end - ${name}_data
")
      endforeach()

      # Silence linker warning about missing .note.GNU-stack section in the .s
      # file by disabling exectuable stack.
      target_link_options(${target} PRIVATE -z noexecstack)
    endforeach()

  elseif(CMAKE_SYSTEM_NAME STREQUAL Windows)

    # Generate an .rc file including each resource from each namespace.
    set(resources_file ${CMAKE_CURRENT_BINARY_DIR}/${target}-resources.rc)
    file(WRITE ${resources_file} "\
// Copyright (C) Codeplay Software Limited
//
// Licensed under the Apache License, Version 2.0 (the \"License\") with LLVM
// Exceptions; you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://github.com/codeplaysoftware/oneapi-construction-kit/blob/main/LICENSE.txt
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an \"AS IS\" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations
// under the License.
//
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

// This file is automatically generated during CMake configuration.

")

    foreach(namespace ${args_NAMESPACES})
      get_target_property(header_file resources-${namespace} RC_HEADER_FILE)
      file(APPEND ${resources_file} "\
#include \"${header_file}\"
")
    endforeach()

    file(APPEND ${resources_file} "\n")

    foreach(namespace ${args_NAMESPACES})
      get_target_property(resources resources-${namespace} RESOURCES)
      set_property(SOURCE ${resources_file} APPEND PROPERTY OBJECT_DEPENDS ${resources})

      foreach(resource ${resources})
        get_filename_component(name ${resource} NAME)
        string(REGEX REPLACE "[-\\.]" "_" name ${name})
        set(cname ${namespace}_${name})
        string(TOUPPER ${cname} CNAME)

        file(APPEND ${resources_file} "\
${CNAME}_ID RCDATA \"${resource}\"
")

        # Increment the resource compiler ID counter.
        math(EXPR id_counter "${id_counter} + 1")
      endforeach()
    endforeach()

  elseif(CMAKE_SYSTEM_NAME STREQUAL Darwin)

    set(resources_file ${CMAKE_CURRENT_BINARY_DIR}/${target}-resources.s)
    file(WRITE ${resources_file} "\
  .const_data
")

    foreach(namespace ${args_NAMESPACES})
      get_target_property(resources resources-${namespace} RESOURCES)
      set_property(SOURCE ${resources_file} APPEND PROPERTY OBJECT_DEPENDS ${resources})

      foreach(resource ${resources})
        get_filename_component(name ${resource} NAME)
        string(REGEX REPLACE "[-\\.]" "_" name ${name})
        set(name ${namespace}_${name})

        file(APPEND ${resources_file} "
  .global _${name}_data
  .align 4
_${name}_data:
  .incbin \"${resource}\"
_${name}_end:
  .byte 0

  .global _${name}_size
  .align 4
_${name}_size:
  .long _${name}_end - _${name}_data
")

      endforeach()
    endforeach()
  else()
    message(FATAL_ERROR
      "ResourceCompiler doesn't not yet support ${CMAKE_SYSTEM_NAME}")
  endif()

  target_sources(${target} PRIVATE ${resources_file})
  if(CMAKE_CXX_COMPILER_ID MATCHES Clang)
    # Clang warns when command-line arguments are passed to .s files and are
    # not used. In combination with warnings as errors this breaks the build so
    # we disable this warning for our .s resource file.
    set_source_files_properties(${resources_file} PROPERTIES
      COMPILE_DEFINITIONS "" COMPILE_FLAGS "-Wno-unused-command-line-argument")
  endif()
endfunction()
