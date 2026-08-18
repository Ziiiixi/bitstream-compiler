cmake_minimum_required(VERSION 3.20)

project(BitstreamMLIR LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS NO)

find_package(MLIR REQUIRED CONFIG)
find_package(LLVM REQUIRED CONFIG)

message(STATUS "Using MLIRConfig.cmake in: ${MLIR_DIR}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}")
list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")

include(TableGen)
include(AddLLVM)
include(AddMLIR)
include(HandleLLVMOptions)

include_directories(${LLVM_INCLUDE_DIRS})
include_directories(${MLIR_INCLUDE_DIRS})
include_directories(${PROJECT_SOURCE_DIR}/include)
include_directories(${PROJECT_BINARY_DIR}/include)

add_definitions(${LLVM_DEFINITIONS})

add_subdirectory(include)
add_subdirectory(lib)
add_subdirectory(tools)

find_program(LLVM_LIT
  NAMES llvm-lit lit lit.py
  PATHS
    "${LLVM_TOOLS_BINARY_DIR}"
    "${LLVM_BINARY_DIR}/utils/lit"
    "${LLVM_DIR}/../../../build/utils/lit")
find_program(LLVM_FILECHECK
  NAMES FileCheck
  PATHS
    "${LLVM_TOOLS_BINARY_DIR}"
    "${LLVM_BINARY_DIR}/bin")
get_filename_component(LLVM_SHARED_LIBRARY_DIR
  "${LLVM_DIR}/../../../../x86_64-linux-gnu" ABSOLUTE)
set(BITSTREAM_LIT_LLVM_LIB_DIRS "${LLVM_SHARED_LIBRARY_DIR}")
if(LLVM_LIBRARY_DIRS)
  string(APPEND BITSTREAM_LIT_LLVM_LIB_DIRS ":${LLVM_LIBRARY_DIRS}")
endif()
if(LLVM_LIT AND LLVM_FILECHECK)
  add_custom_target(check-bitstream
    COMMAND ${CMAKE_COMMAND} -E env
            BITSTREAM_OPT=$<TARGET_FILE:bitstream-opt>
            FILECHECK=${LLVM_FILECHECK}
            LLVM_LIB_DIR=${BITSTREAM_LIT_LLVM_LIB_DIRS}
            ${LLVM_LIT} -sv ${PROJECT_SOURCE_DIR}/test
    DEPENDS bitstream-opt
    USES_TERMINAL)
else()
  message(WARNING
    "check-bitstream is disabled: llvm-lit and FileCheck are both required")
endif()
