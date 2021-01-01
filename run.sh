#
# Copyright © 2020 Dmitry Yudin. All rights reserved.
# Licensed under the Apache License, Version 2.0
#
set -eu

dirScript=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

DIR_RUN_LOCAL=$dirScript

#
# Runnig ARM32 build on ARM64 host machine: https://askubuntu.com/questions/1090351/can-i-run-an-arm32-bit-app-on-an-arm64bit-platform-which-is-running-ubuntu-16-04
#   dpkg --add-architecture armhf
#   apt-get update
#   apt-get install libc6:armhf libstdc++6:armhf
#   cd /lib && ln -s arm-linux-gnueabihf/ld-2.23.so ld-linux.so.3
#
usage()
{
    local targets=$("$dirScript/build.sh" --target list)

    cat <<-EOT
    Run application on a remote machine.

    Usage:
        $(basename $0) --app test --target <name> [opt]
        $(basename $0) --app test index

    Options:
        -h|--help          Print help
        -t|--target <name> Remote target
        -a|--app <name>    Test to run
        --local <path>     'run.local' file directory (default: <cmake-it>)

$targets

    Target credentials are read from the local shell script 'run-ut.local'.

    Usign SSH for Linux targets and ADB for Android.
EOT
}

entrypoint()
{
    local target= app=

    [[ $# == 0 ]] && usage && return 1

    while [[ $# -gt 0 ]]; do
        local nargs=2
        case $1 in
            -h|--help)      usage && return;;
            -a|--app)       app=$2;;
            -t|--target)    target=$2;;
            --local)        DIR_RUN_LOCAL=$2;;
            [0-9]|[0-9][0-9]|[0-9][0-9][0-9]|a|aa|b|bb)
                target=$("$dirScript/build.sh" $1 --demangle)
                nargs=1
            ;;
            *) error_exit "unrecognized option '$1'";;
        esac
        shift $nargs
    done
    [[ -z "$target" ]] && error_exit "'--target' option not set"
    [[ -z "$app" ]] && error_exit "no application selected selected"
    [[ "$target" == list ]] && "$dirScript/build.sh" --target list && return

    local prms_file=$DIR_RUN_LOCAL/run.local
    if [[ -f "$prms_file" ]]; then
        . "$prms_file"
    else
        error_exit "'$prms_file' not found"
    fi

    local remote=host
    case $target in arm*)  remote=ssh;; esac
    case $target in *-ndk) remote=adb;; esac

#   Do not build here since we do not know 'build.local' file location
#    "$dirScript/build.sh" --target $target --app "$app"

    local dirBin=$("$dirScript/build.sh" --target $target --app $app --print)

    echo "[$remote] $dirBin/$app"
    if [[ "$remote" == host ]]; then
        "$dirBin/$app"
    else
        . "$dirScript/remote_target.sh"
        TARGET_setTarget    $remote "$prms_file"
        TARGET_getExecDir;  remoteDirBin=$REPLY;
        TARGET_exec         "mkdir -p '$remoteDirBin'"
        TARGET_push         "$dirBin/$app" "$remoteDirBin/$app"
        TARGET_exec         "
            chmod +x '$remoteDirBin/$app'
            '$remoteDirBin/$app'
        "
    fi
}

error_exit()
{
    echo "error: $*" >&2
    exit 1
}

entrypoint "$@"
