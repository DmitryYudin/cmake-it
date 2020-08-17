CMake-It
========

Using CMake with the platform's default toolchain is as easy is as running `cmake .`, but changing the default toolchain or cross-compiling requires to pass toolchain specific options to `cmake`. There are two ways to accomplish this: create `toolchain file`
```
cmake -DCMAKE_TOOLCHAIN_FILE=crosscompile.cmake
```
or pass all options directly from the command line
```
cmake -S <path to CMakeLists.txt> \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER=<path_to_gcc>/arm-linux-gnueabi-gcc \
    ...

```
Both variants are almost equivalent.

This project exposes `build.sh` script incorporates all the magic required to compile cmake-project with `cl`, `gcc`, `clang` for `Intel` and `ARM` CPUs.


### How to use

Create `build.local` file (see example):
```
DIR_NDK=C:/android/ndk-r21d
DIR_GCC=C:/mingw
DIR_LLVM=C:/llvm/10.0.0
DIR_LLVM_ARM=$DIR_LLVM
...
```

Execute from `CMakeLists.txt` file directory:
```
# Build with selected toolchain
build.sh x64-cl
build.sh x64-gcc
build.sh x64-clang
build.sh arm64-ndk
build.sh arm64-gcc
...

# Run compiled executable
run.sh x64-cl       # run local (i.e. host machine)
run.sh arm64-ndk    # run using ADB
run.sh arm64-gcc    # run using SSH
run.sh arm64-clang
...

```

### Prerequisites

[cmake](https://github.com/Kitware/CMake/releases), [vswhere](https://github.com/microsoft/vswhere/releases), [ninja](https://github.com/ninja-build/ninja/releases)
