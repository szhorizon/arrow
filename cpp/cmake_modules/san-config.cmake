#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License. See accompanying LICENSE file.

# Clang does not support using ASAN and TSAN simultaneously.
if ("${ARROW_USE_ASAN}" AND "${ARROW_USE_TSAN}")
  message(SEND_ERROR "Can only enable one of ASAN or TSAN at a time")
endif()

# Flag to enable clang address sanitizer
# This will only build if clang or a recent enough gcc is the chosen compiler
if (${ARROW_USE_ASAN})
  if(NOT (("${COMPILER_FAMILY}" STREQUAL "clang") OR
          ("${COMPILER_FAMILY}" STREQUAL "gcc" AND "${COMPILER_VERSION}" VERSION_GREATER "4.8")))
    message(SEND_ERROR "Cannot use ASAN without clang or gcc >= 4.8")
  endif()
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=address -DADDRESS_SANITIZER")
endif()


# Flag to enable clang undefined behavior sanitizer
# We explicitly don't enable all of the sanitizer flags:
# - disable 'vptr' because it currently crashes somewhere in boost::intrusive::list code
# - disable 'alignment' because unaligned access is really OK on Nehalem and we do it
#   all over the place.
if (${ARROW_USE_UBSAN})
  if(NOT (("${COMPILER_FAMILY}" STREQUAL "clang") OR
          ("${COMPILER_FAMILY}" STREQUAL "gcc" AND "${COMPILER_VERSION}" VERSION_GREATER "4.9")))
    message(SEND_ERROR "Cannot use UBSAN without clang or gcc >= 4.9")
  endif()
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=undefined -fno-sanitize=alignment,vptr -fno-sanitize-recover=all")
endif ()

# Flag to enable thread sanitizer (clang or gcc 4.8)
if (${ARROW_USE_TSAN})
  if(NOT (("${COMPILER_FAMILY}" STREQUAL "clang") OR
          ("${COMPILER_FAMILY}" STREQUAL "gcc" AND "${COMPILER_VERSION}" VERSION_GREATER "4.8")))
    message(SEND_ERROR "Cannot use TSAN without clang or gcc >= 4.8")
  endif()

  add_definitions("-fsanitize=thread")

  # Enables dynamic_annotations.h to actually generate code
  add_definitions("-DDYNAMIC_ANNOTATIONS_ENABLED")

  # changes atomicops to use the tsan implementations
  add_definitions("-DTHREAD_SANITIZER")

  # Disables using the precompiled template specializations for std::string, shared_ptr, etc
  # so that the annotations in the header actually take effect.
  add_definitions("-D_GLIBCXX_EXTERN_TEMPLATE=0")

  # Some of the above also need to be passed to the linker.
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -pie -fsanitize=thread")

  # Strictly speaking, TSAN doesn't require dynamic linking. But it does
  # require all code to be position independent, and the easiest way to
  # guarantee that is via dynamic linking (not all 3rd party archives are
  # compiled with -fPIC e.g. boost).
  if("${ARROW_LINK}" STREQUAL "a")
    message("Using dynamic linking for TSAN")
    set(ARROW_LINK "d")
  elseif("${ARROW_LINK}" STREQUAL "s")
    message(SEND_ERROR "Cannot use TSAN with static linking")
  endif()
endif()


if (${ARROW_USE_COVERAGE})
  if(NOT ("${COMPILER_FAMILY}" STREQUAL "clang"))
    message(SEND_ERROR "You can only enable coverage with clang")
  endif()
  add_definitions("-fsanitize-coverage=trace-pc-guard")

  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize-coverage=trace-pc-guard")
endif()


if ("${ARROW_USE_UBSAN}" OR "${ARROW_USE_ASAN}" OR "${ARROW_USE_TSAN}")
  # GCC 4.8 and 4.9 (latest as of this writing) don't allow you to specify a
  # sanitizer blacklist.
  if("${COMPILER_FAMILY}" STREQUAL "clang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize-blacklist=${BUILD_SUPPORT_DIR}/sanitize-blacklist.txt")
  else()
    message(WARNING "GCC does not support specifying a sanitizer blacklist. Known sanitizer check failures will not be suppressed.")
  endif()
endif()
