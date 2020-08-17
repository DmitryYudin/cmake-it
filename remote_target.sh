#
# Copyright © 2020 Dmitry Yudin. All rights reserved.
# Licensed under the Apache License, Version 2.0
#

#
# This script is for the sourcing
#

# Methods to work with remote target. (Android)
#   TARGET_setTarget      - set credentials
#   TARGET_getExecDir     - directory we can execute from
#   TARGET_getDataDir     - '/sdcard' for Android
#   TARGET_getFingerprint - device info
#   TARGET_pull           - to move folder content use 'cp src/. dst' syntax
#   TARGET_push           -                                   ^ this guy
#   TARGET_pushFileOnce   - 'push' without overwrite
#
TARGET_setTarget() # <adb|ssh> [remote.local]
{
    local target=$1; shift
    local prms_script=${1:-}

    ADB_SERIAL=; SSH_IP=; SSH_OPTIONS="-P 22"
    if [[ -n "$prms_script" ]]; then
        . "$prms_script"
        ADB_SERIAL=${serial:-}
        # Do not use '-batch' option here since we have to change remote
        # fingerprint with OS reinstall. This case we just accept new suggested id.
        SSH_IP=${ip:-}
        SSH_OPTIONS="$SSH_OPTIONS ${user:+ -l $user} ${passw:+ -pw $passw}"
    fi

    if [[ $target == adb ]]; then
        if command -p adb 1>/dev/null 2>&1; then
            HOST_ADB=adb
        else
            # Try default location if not found in $PATH
            if [[ -z "${ANDROID_HOME:-}" ]]; then
                case ${OS:-} in
                    *_NT) ANDROID_HOME=$LOCALAPPDATA/Android/Sdk;;
                    *) ANDROID_HOME=/Users/$(whoami)/Library/Android/sdk;;
                esac
            fi
            HOST_ADB=$ANDROID_HOME/platform-tools/adb
            [[ ! -x "${HOST_ADB:-}" ]] && echo "error: 'adb' not found" >&2 && return 1
        fi

        adb() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" command "$HOST_ADB" "$@"; }

        export ANDROID_SERIAL=$ADB_SERIAL  # used by adb
        export HOST_ADB
        export -f adb

        TARGET_getExecDir()     { _adb_getExecDir "$@"; }
        TARGET_getDataDir()     { _adb_getDataDir "$@"; }
        TARGET_getFingerprint() { _adb_getFingerprint "$@"; }
        TARGET_pull()           { _adb_pull "$@"; }
        TARGET_push()           { _adb_push "$@"; }
        TARGET_pushFileOnce()   { _adb_pushFileOnce "$@"; }
        TARGET_exec()           { _adb_exec "$@"; }
    elif [[ $target == ssh ]]; then
        [[ -z "${SSH_IP:-}" ]] && echo "error: IP is empty, can't ssh" >&2 && return 1
        export SSH_IP
        export SSH_OPTIONS
        TARGET_getExecDir()     { _ssh_getExecDir "$@"; }
        TARGET_getDataDir()     { _ssh_getDataDir "$@"; }
        TARGET_getFingerprint() { _ssh_getFingerprint "$@"; }
        TARGET_pull()           { _ssh_pull "$@"; }
        TARGET_push()           { _ssh_push "$@"; }
        TARGET_pushFileOnce()   { _ssh_pushFileOnce "$@"; }
        TARGET_exec()           { _ssh_exec "$@"; }
        pscp()  { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" command pscp "$@"; }
        plink() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" command plink "$@"; }
        ssh()   { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" command ssh "$@"; }
        export -f pscp
        export -f plink
        export -f ssh
    else
        echo "error: unknown remote target '$target'" >&2
        return 1
    fi

    export -f \
        TARGET_getExecDir \
        TARGET_getDataDir \
        TARGET_pull \
        TARGET_push \
        TARGET_pushFileOnce \
        TARGET_exec
}

#  _____ ____  _____
# |  _  |    \| __  |
# |     |  |  | __ -|
# |__|__|____/|_____|
#
_adb_getExecDir()
{
    REPLY=/data/local/tmp
}
_adb_getDataDir()
{
    REPLY="$(adb shell -n echo \$EXTERNAL_STORAGE)"
    REPLY=${REPLY%%$'\r'}
}
_adb_getFingerprint()
{
    REPLY=$( _adb_exec "
        board=\$(getprop ro.board.platform)       # kirin970
        cpuabi=\$(getprop ro.product.cpu.abi)     # arm64-v8a
        model=\$(getprop ro.product.model)        # CLT-AL00
        brand=\$(getprop ro.product.brand)        # HUAWEI
        name=\$(getprop ro.config.marketing_name) # HUAWEI P20 Pro
        echo \"\$board:\$cpuabi:\$brand:\$model:\$name\"
    ")
}
_adb_pull()
{
    local remoteSrc=$1; shift
    local localDst=$1; shift

    adb pull "$remoteSrc" "$localDst"
}
_adb_push()
{
    local localSrc=$1; shift
    local remoteDst=$1; shift

    adb push "$localSrc" "$remoteDst"
}
_adb_pushFileOnce()
{
    local localSrc=$1; shift
    local remoteDst=$1; shift # maybe directory

    REPLY=$(_adb_exec "
        filepath=$remoteDst; [[ -d $remoteDst ]] && filepath=\"$remoteDst/$(basename $localSrc)\"
        [[ ! -e \$filepath ]] && rm -f \$filepath.stamp 2>/dev/null || true
        [[ ! -e \$filepath.stamp ]] && exit 0
        echo ok
    ")
    [[ "$REPLY" == ok ]] && return

    _adb_push "$localSrc" "$remoteDst"
    _adb_exec "
        filepath=$remoteDst; [[ -d $remoteDst ]] && filepath=\"$remoteDst/$(basename $localSrc)\"
        date > \$filepath.stamp
    "
}
_adb_exec()
{
    adb shell -n "set -e; $@"
}

#  _____ _____ _____
# |   __|   __|  |  |
# |__   |__   |     |
# |_____|_____|__|__|
#
_ssh_getExecDir()
{
#   REPLY=/home/$SSH_USER
    REPLY=$(_ssh_exec "pwd")
    REPLY=${REPLY%%$'\r'}
}
_ssh_getDataDir()
{
    _ssh_getExecDir
}
_ssh_getFingerprint()
{
    REPLY=TODO
}
#
# Copy the content of 'src' folder into 'dst' folder as 'copy src proto:dst'
#
# Assume 'dst' exists otherwise pscp does not work.
#
#   src  |          dst content
# ending | cp          adb          pscp
# -------+--------------------------------
# "/"    | dst/src/*   dst/src/*    dst/*
# "/."   | dst/*       dst/*        -        <-- recognize this case and
# "/*"   | -           -            dst/*  <---/ replace '/.' with '/*' for pscp
#
# ^ The is also applicible for pulling data from a remote machine to a host system
#
_ssh_pull()
{
    local remoteSrc=${1//\\//}; shift
    local localDst=$1; shift
    remoteSrc=${remoteSrc/%\/./\/*}
    pscp $SSH_OPTIONS -r "$SSH_IP:$remoteSrc" "$localDst"
}
_ssh_push()
{
    local localSrc=${1//\\//}; shift
    local remoteDst=$1; shift
    localSrc=${localSrc/%\/./\/*}
    pscp $SSH_OPTIONS -r "$localSrc" "$SSH_IP:$remoteDst"
}
_ssh_pushFileOnce()
{
    local localSrc=$1; shift
    local remoteDst=$1; shift # maybe directory

    REPLY=$(TARGET_exec "
        filepath=$remoteDst; [[ -d $remoteDst ]] && filepath=\"$remoteDst/$(basename $localSrc)\"
        [[ ! -e \$filepath ]] && rm -f \$filepath.stamp 2>/dev/null || true
        [[ ! -e \$filepath.stamp ]] && exit 0
        echo ok
    ")
    [[ "$REPLY" == ok ]] && return

    _ssh_push "$localSrc" "$remoteDst"
    _ssh_exec "
        filepath=$remoteDst; [[ -d $remoteDst ]] && filepath=\"$remoteDst/$(basename $localSrc)\"
        date > \$filepath.stamp
    "
}
_ssh_exec()
{
    plink -batch $SSH_OPTIONS $SSH_IP "set -e; $@"
}
