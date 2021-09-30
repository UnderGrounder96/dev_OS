#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script builds dev_OS
# ==============================================================================

set -euo pipefail

COMMON="${1}"

source $COMMON
unset BTARGET

LOG_FILE="$ROOT_DIR/logs/build-$(date '+%F_%T').log"

function create_build_dirs(){
    _logger_info "Creating build OS dirs"

    mkdir -pv $BROOT/{dev,proc,sys,run}
}

function create_device_nodes(){
    _logger_info "Creating device nodes"

    mknod -m 600 $BROOT/dev/console c 5 1
    mknod -m 666 $BROOT/dev/null c 1 3
}

function mount_build_dirs(){
    _logger_info "Mounting build dirs"

    mount -v --bind /dev $BROOT/dev
    mount -vt devpts devpts $BROOT/dev/pts --options gid=5,mode=620
    mount -vt proc proc $BROOT/proc
    mount -vt sysfs sysfs $BROOT/sys
    mount -vt tmpfs tmpfs $BROOT/run

    if [ -h $BROOT/dev/shm ]; then
        mkdir -vp $BROOT/$(readlink $BROOT/dev/shm)
    fi
}

function entering_chroot_jail(){
    _logger_info "Entering chroot jail"

    cp -ruv $ROOT_DIR/{libs,configs} $BROOT

    chroot "$BROOT" /tools/bin/env -i                 \
      TERM="$TERM"  PS1="\u:\w\$ "  HOME="/root"      \
      PATH="/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin" \
      /tools/bin/bash --login +h                      \
      -c "sh /libs/base.sh /configs/common.sh"
}

function main(){
    create_build_dirs

    create_device_nodes

    mount_build_dirs

    entering_chroot_jail

    exit 0
}

main 2>&1 | tee -a $LOG_FILE
