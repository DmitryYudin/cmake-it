#
# Copyright © 2020 Dmitry Yudin. All rights reserved.
# Licensed under the Apache License, Version 2.0
#
set -eu

dirScript=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

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
    Build and execute unit-test on a remote machine.

    Usage:
        $(basename $0) --target <name> [opt]
        $(basename $0) index

    Options:
        -h|--help          Print help
        -t|--target <name> Remote target
        -a|--app <name>    Test to run

$targets

    Target credentials are read from the local shell script 'run-ut.local'.

    Usign SSH for Linux targets and ADB for Android.
EOT
}

entrypoint()
{
    local target= app_cmd=

    [[ $# == 0 ]] && usage && return 1

    while [[ $# -gt 0 ]]; do
        local nargs=2
        case $1 in
            -h|--help)      usage && return;;
            -a|--app)       app_cmd=$2;;
            -t|--target)    target=$2;;
            [0-9]|[0-9][0-9]|[0-9][0-9][0-9]|a|aa|b|bb)
                target=$("$dirScript/build.sh" $1 --demangle)
                nargs=1
            ;;
            *) error_exit "unrecognized option '$1'";;
        esac
        shift $nargs
    done
    [[ -z "$target" ]] && error_exit "'--target' option not set"
    [[ "$target" == list ]] && "$dirScript/build.sh" --target list && return

    local prms_file=./run.local
    if [[ -f "$prms_file" ]]; then
        . "$prms_file"
        [[ -n "${app_cmd:-}" ]] && app=$app_cmd # override script value
    else
        error_exit "'$prms_file' not found"
    fi
    [[ -z "${app:-}" ]] && error_exit "no app selected"

    local remote=host
    case $target in arm*)  remote=ssh;; esac
    case $target in *-ndk) remote=adb;; esac

    "$dirScript/build.sh" --target $target --app "$app"

    local dirBin=$("$dirScript/build.sh" --target $target --app "$app" --print)

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
