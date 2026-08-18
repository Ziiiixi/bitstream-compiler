import os

import lit.formats

config.name = "Bitstream"
config.test_format = lit.formats.ShTest(True)
config.suffixes = [".mlir"]
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = config.test_source_root

bitstream_opt = os.environ.get("BITSTREAM_OPT", "bitstream-opt")
filecheck = os.environ.get("FILECHECK", "FileCheck")
llvm_lib_dir = os.environ.get("LLVM_LIB_DIR")

if llvm_lib_dir:
    old_ld_library_path = config.environment.get("LD_LIBRARY_PATH", "")
    config.environment["LD_LIBRARY_PATH"] = (
        llvm_lib_dir
        if not old_ld_library_path
        else llvm_lib_dir + os.pathsep + old_ld_library_path
    )
    bitstream_opt = (
        "env LD_LIBRARY_PATH="
        + config.environment["LD_LIBRARY_PATH"]
        + " "
        + bitstream_opt
    )

config.substitutions.append(("bitstream-opt", bitstream_opt))
config.substitutions.append(("FileCheck", filecheck))
