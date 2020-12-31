#
# Copyright © 2020 Dmitry Yudin. All rights reserved.
# Licensed under the Apache License, Version 2.0
#
set -eu

dirScript=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

DIR_BUILD_LOCAL=$dirScript
DIR_CMAKELIST=.
BUILD_FLAGS=

usage()
{
    local targets=$(list_targets)
    cat <<-EOT
    CMake wrapper to compile project for a predefined set of targets.

    Usage:
        $(basename $0) --target <name> [opt]
        $(basename $0) index

    Options:
        -h|--help          Print help
        -p|--print         Print output binary directory
        -d|--demangle      Print target name (from index)
        -t|--target <name> Build target
        -r|--rebuild       Cleanup output directory before build
        -a|--app <name>    Only build selected application
        -f|--file <path>   Path to 'CMakeList.txt' (default: .)
        --local <path>     'build.local' file directory (default: <cmake-it>)
        -Dkey=val          CMake flags
        index              Target index

$targets

      MSVC    [  a]               <= Generate project for x64
              [ aa]               <= Generate & open
              [  b]               <= Generate project for x86
              [ bb]               <= Generate & open

    Example:
        build.sh 1
        build.sh aa
        build.sh --target x64-cl --app test
EOT
}

list_targets()
{
    cat <<-EOT
    Available targets:
      Host    [  1] x64-msvc
              [  2] x64-cl        <= same as MSVC, but Ninja
              [  3] x64-gcc       <= DIR_GCC
              [  4] x64-clang     <= DIR_LLVM
      Linux   [  5] arm64-gcc     <= DIR_GCC_ARM{64,32}_LINUX ['arm64-v8a', 'aarch64']
              [  6] arm64-clang   <= DIR_GCC_ARM{64,32}_LINUX + DIR_LLVM_ARM
      Android [  7] arm64-ndk     <= DIR_NDK

      Host    [ 10] x32-msvc
              [ 20] x32-cl
              [ 30] x32-gcc
              [ 40] x32-clang
      Linux   [ 50] arm32-gcc     <= ['armeabi-v7a + NEON + hard-float']
              [ 60] arm32-clang
      Android [ 70] arm32-ndk
EOT
}

entrypoint()
{
    local rebuild=false print_only=false demangle_only=false target= msvc_open=0 msvc_build=1
    local start_sec=$SECONDS

    [[ $# == 0 ]] && usage && return 1

    while [[ $# -gt 0 ]]; do
        local nargs=2
        case $1 in
            -h|--help)      usage && return;;
            -r|--rebuild)   rebuild=true; nargs=1;;
            -a|--app)       APP=$2;;
            -p|--print)     print_only=true; nargs=1;;
            -d|--demangle)  demangle_only=true; nargs=1;;
            -t|--target)    target=$2;;
             a) target=x64-msvc; msvc_build=0; nargs=1;;
             b) target=x32-msvc; msvc_build=0; nargs=1;;
            aa) target=x64-msvc; msvc_open=1; nargs=1;;
            bb) target=x32-msvc; msvc_open=1; nargs=1;;
            [0-9]|[0-9][0-9]|[0-9][0-9][0-9])
                index_to_target "$1"; target=$REPLY
                [[ -z $target ]] && error_exit "unrecognized target index '$1'"
                nargs=1
            ;;
            -f|file)        DIR_CMAKELIST=$2;;
            --local)        DIR_BUILD_LOCAL=$2;;
            -D*)            BUILD_FLAGS="$BUILD_FLAGS $1"; nargs=1;; # TODO: push back to $@
            *) error_exit "unrecognized option '$1'";;
        esac
        shift $nargs
    done
    [[ -z "$target" ]] && usage && error_exit "'target' not set"

    [[ "$target" == list ]] && list_targets && return

    local script= bits= dirOut=
    case $target in
        x64-msvc)       bits=64; script=generate_msvc;          dirOut=.build/msvc-x$bits;;
        x32-msvc)       bits=32; script=generate_msvc;          dirOut=.build/msvc-x$bits;;
        x64-cl)         bits=64; script=build_cl;               dirOut=.build/cl-x$bits;;
        x32-cl)         bits=32; script=build_cl;               dirOut=.build/cl-x$bits;;
        x64-gcc)        bits=64; script=build_gcc;              dirOut=.build/gcc-x$bits;;
        x32-gcc)        bits=32; script=build_gcc;              dirOut=.build/gcc-x$bits;;
        x64-clang)      bits=64; script=build_clang;            dirOut=.build/clang-x$bits;;
        x32-clang)      bits=32; script=build_clang;            dirOut=.build/clang-x$bits;;
        arm64-gcc)      bits=64; script=build_arm_linux_gcc;    dirOut=.build/arm${bits}_linux_gcc;;
        arm32-gcc)      bits=32; script=build_arm_linux_gcc;    dirOut=.build/arm${bits}_linux_gcc;;
        arm64-clang)    bits=64; script=build_arm_linux_clang;  dirOut=.build/arm${bits}_linux_clang;;
        arm32-clang)    bits=32; script=build_arm_linux_clang;  dirOut=.build/arm${bits}_linux_clang;;
        arm64-ndk)      bits=64; script=build_ndk;              dirOut=.build/arm${bits}_ndk;;
        arm32-ndk)      bits=32; script=build_ndk;              dirOut=.build/arm${bits}_ndk;;
        *) error_exit "unrecognized target '$target'";;
    esac

    if $print_only; then
        case $target in *-msvc) dirOut=$dirOut/Release;; esac
        echo "$dirOut"
        return
    fi

    $demangle_only && echo "$target" && return

    local prms_file=$DIR_BUILD_LOCAL/build.local
    if [[ -f "$prms_file" ]]; then
        . "$prms_file"
    else
        error_exit "'$prms_file' not found"
    fi

    $rebuild && rm -rf "$dirOut"

    case $target in *-msvc) script="$script $msvc_open $msvc_build";; esac
    $script $bits "$dirOut" $BUILD_FLAGS

    local timestamp
    timestampStr $((SECONDS - start_sec)); timestamp=$REPLY
    echo "$timestamp Successfully built [$dirOut]"
}

index_to_target()
{
    local index=$1; shift
    local target=
    case $index in
         a) target=x64-msvc; msvc_build=1;;
         b) target=x32-msvc; msvc_build=1;;
        aa) target=x64-msvc; msvc_open=1;;
        bb) target=x32-msvc; msvc_open=1;;
         1) target=x64-msvc;;
        10) target=x32-msvc;;
         2) target=x64-cl;;
        20) target=x32-cl;;
         3) target=x64-gcc;;
        30) target=x32-gcc;;
         4) target=x64-clang;;
        40) target=x32-clang;;
         5) target=arm64-gcc;;
        50) target=arm32-gcc;;
         6) target=arm64-clang;;
        60) target=arm32-clang;;
         7) target=arm64-ndk;;
        70) target=arm32-ndk;;
    esac
    REPLY=$target
}

generate_msvc()
{
    local msvc_open=$1; shift
    local msvc_build=$1; shift
    local bits=$1; shift
    local dirOut=$1; shift

    local arch=
    [[ $bits == 32 ]] && arch=Win32 || arch=x64

    cmake -A $arch -B "$dirOut" -S "$DIR_CMAKELIST" \
        -DCMAKE_C_COMPILER=cl \
        -DCMAKE_CXX_COMPILER=cl \
        "$@"

    [[ $msvc_open == 1 ]] && cmake --open "$dirOut" && return

    [[ $msvc_build == 1 ]] && cmake --build "$dirOut" --config Release && return
}

build_cl()
{
    local bits=$1; shift
    local dirOut=$1; shift

    local DIR_MSVC=
    DIR_MSVC=$(vswhere -latest -property installationPath)

    local vcvars=
    [[ $bits == 32 ]] && vcvars=32 || vcvars=64

    mkdir -p $dirOut
    cat <<-EOT> __run_cmake__.bat
        @call "$DIR_MSVC/VC/Auxiliary/Build/vcvars$vcvars.bat" || exit /B 1
        @call cmake -G Ninja -B $dirOut -S "$DIR_CMAKELIST" ^
            -DCMAKE_BUILD_TYPE=release ^
            -DCMAKE_C_COMPILER=cl ^
            -DCMAKE_CXX_COMPILER=cl || ^
        exit /B 1

        @call cmake --build $dirOut ${APP:+ --target $APP} || exit /B 1
EOT
    ./__run_cmake__.bat
    rm __run_cmake__.bat
}

build_gcc()
{
    local bits=$1; shift
    local dirOut=$1; shift

    update_path DIR_GCC bin

    local cflags=
    [[ $bits == 32 ]] && cflags=-m32 || cflags=-m64

    cmake -G Ninja -B "$dirOut" -S "$DIR_CMAKELIST" \
        -DCMAKE_BUILD_TYPE=release \
        -DCMAKE_C_COMPILER=gcc \
        -DCMAKE_CXX_COMPILER=g++ \
        -DCMAKE_C_FLAGS="$cflags" \
        -DCMAKE_CXX_FLAGS="$cflags" \
        "$@"

    cmake --build "$dirOut" ${APP:+ --target $APP}
}

build_clang()
{
    local bits=$1; shift
    local dirOut=$1; shift

    update_path DIR_LLVM bin

    local cflags=
    [[ $bits == 32 ]] && cflags=-m32 || cflags=-m64

    cmake -G Ninja -B "$dirOut" -S "$DIR_CMAKELIST" \
        -DCMAKE_BUILD_TYPE=release \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_C_FLAGS="$cflags" \
        -DCMAKE_CXX_FLAGS="$cflags" \
        "$@"

    cmake --build "$dirOut" ${APP:+ --target $APP}
}

build_arm_linux_gcc()
{
    local bits=$1; shift
    local dirOut=$1; shift

    if [[ $bits == 32 ]]; then
        update_path DIR_GCC_ARM32_LINUX bin
        dirGCC=$DIR_GCC_ARM32_LINUX
    else
        update_path DIR_GCC_ARM64_LINUX bin
        dirGCC=$DIR_GCC_ARM64_LINUX
    fi
    local arch= prefix= cflags=
    if [[ $bits == 32 ]]; then
        arch=armeabi-v7a
        prefix=$PREF_GCC_ARM32_LINUX
        cflags="-march=armv7-a -mfpu=neon" #"-marm"
    else
        arch=aarch64
        prefix=$PREF_GCC_ARM64_LINUX
        cflags=
    fi

    cmake -G Ninja -B $dirOut -S "$DIR_CMAKELIST" \
        -DCMAKE_BUILD_TYPE=release \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR="$arch" \
        -DCMAKE_CROSSCOMPILING=TRUE \
        -DCMAKE_C_COMPILER=$prefix-gcc \
        -DCMAKE_CXX_COMPILER=$prefix-g++ \
        -DCMAKE_C_FLAGS="$cflags" \
        -DCMAKE_CXX_FLAGS="$cflags" \
        -DCMAKE_SYSROOT="$dirGCC/$prefix/libc" \
        "$@"

    cmake --build "$dirOut" ${APP:+ --target $APP}
}

build_arm_linux_clang()
{
    local bits=$1; shift
    local dirOut=$1; shift
    local dirGCC=

    update_path DIR_LLVM_ARM bin
    if [[ $bits == 32 ]]; then
        update_path DIR_GCC_ARM32_LINUX bin
        dirGCC=$DIR_GCC_ARM32_LINUX
    else
        update_path DIR_GCC_ARM64_LINUX bin
        dirGCC=$DIR_GCC_ARM64_LINUX
    fi

    local arch= prefix= cflags=
    if [[ $bits == 32 ]]; then
        arch=armeabi-v7a
        prefix=$PREF_GCC_ARM32_LINUX
        cflags="--target=$prefix -march=armv7-a -mfpu=neon -marm"
    else
        arch=aarch64
        prefix=$PREF_GCC_ARM64_LINUX
        cflags="--target=$prefix"
    fi

    local gcc=
    for f in $(find "$dirGCC" -name "$prefix*-gcc*" -executable); do
        [[ ${#gcc} -eq 0 || ${#gcc} -gt ${#f} ]] && gcc=$f
    done
    [[ -z $gcc ]] && error_exit "can't find GNU compiler with '$prefix' prefix in a '$dirGCC' directory"

    cmake -G Ninja -B "$dirOut" -S "$DIR_CMAKELIST" \
        -DCMAKE_BUILD_TYPE=release \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR="$arch" \
        -DCMAKE_CROSSCOMPILING=TRUE \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_C_FLAGS="$cflags" \
        -DCMAKE_CXX_FLAGS="$cflags" \
        -DCMAKE_ASM_COMPILER=$gcc \
        -DCMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN="$dirGCC" \
        -DCMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN="$dirGCC" \
        -DCMAKE_SYSROOT="$dirGCC/$prefix/libc" \
        "$@"

    cmake --build $dirOut ${APP:+ --target $APP}
}

build_ndk()
{
    local bits=$1; shift
    local dirOut=$1; shift

    update_path DIR_NDK

    local arch=
    [[ $bits == 32 ]] && arch="armeabi-v7a with NEON" || arch=arm64-v8a
#
# ftell0, fseek0 ... require API >= 24
#
    cmake -G Ninja -B $dirOut -S "$DIR_CMAKELIST" \
        -DCMAKE_BUILD_TYPE=release \
        -DANDROID_ABI="$arch" \
        -DANDROID_NATIVE_API_LEVEL=24 \
        -DANDROID_NDK=$DIR_NDK \
        -DCMAKE_TOOLCHAIN_FILE="$DIR_NDK/build/cmake/android.toolchain.cmake" \
        "$@"

    cmake --build "$dirOut" ${APP:+ --target $APP}
}

error_exit()
{
    echo "error: $*" >&2
    exit 1
}

timestampStr()
{
    local dt=$1; shift
    local hr=$(( dt/60/60 )) min=$(( (dt/60) % 60 )) sec=$(( dt % 60 ))
    [[ ${#min} == 1 ]] && min=0$min
    [[ ${#sec} == 1 ]] && sec=0$sec
    [[ ${#hr}  == 1 ]] && hr=0$hr
    REPLY="$hr:$min:$sec"
}

update_path()
{
    local var=$1; shift
    local subfolder=${1:-}
    eval "local val=\"\${$var:-}\""
    [[ -z "$val" ]] && error_exit "'$var' not set"
    [[ ! -d "$val" ]] && error_exit "'$var=$val' not found"
    local dir=$val/$subfolder
    [[ ! -d "$dir" ]] && error_exit "\$$var/$subfolder=$dir' not found"
    case ${OS-:} in *_NT) dir=$(cygpath -p "$dir");; esac
    export PATH="$dir:$PATH"
}

cmake() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" command cmake "$@"; }

entrypoint "$@"
