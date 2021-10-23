#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script builds dev_OS
# ==============================================================================

set -euo pipefail

COMMON="${1}"

source $COMMON
unset BTARGET

LOG_FILE="$ROOT_DIR/logs/build-$(date '+%F_%T').log"

function create_kernel_dirs(){
    _logger_info "Creating kernel file system dirs"

    mkdir -vp $BROOT/{dev,proc,sys,run}
}

function create_device_nodes(){
    _logger_info "Creating initial device nodes"

    mknod -m 600 $BROOT/dev/console c 5 1
    mknod -m 666 $BROOT/dev/null c 1 3
}

function mount_build_dirs(){
    _logger_info "Mounting Virtual Kernel file system"

    mount -v --bind /dev $BROOT/dev # populate /dev

    mount -vt devpts devpts $BROOT/dev/pts
    mount -vt proc proc $BROOT/proc
    mount -vt sysfs sysfs $BROOT/sys
    mount -vt tmpfs tmpfs $BROOT/run

    if [ -h $BROOT/dev/shm ]; then
      mkdir -vp $BROOT/$(readlink $BROOT/dev/shm)
    fi
}

function changing_build_ownership(){
    _logger_info "Changing $BROOT ownership"

    # copy lib,config files to be used inside chroot jail
    cp -rfuv $ROOT_DIR/{libs,configs} $BROOT

    chown -R root: $BROOT/{boot,usr,lib,var,etc,tools,{,s}bin}

    case $(uname -m) in
      x86_64)
        chown -R root: $BROOT/lib64
        ;;
    esac
}

function restore_temp-tools(){
    _logger_info "Restoring build temptools"

    tar -xpf $ROOT_DIR/backup/backup*$BVERSION*.tar*
}

function buid_tmp_OS(){
    _logger_info "Building temporary OS"

    # build temp_OS in chroot environment
    chroot "$BROOT" /usr/bin/env -i  HOME="/root"     \
      TERM="$TERM"  PS1="(dev_OS chroot) \u:\w\$ \n"  \
      PATH="/usr/bin:/usr/sbin" /bin/bash --login +h  \
      -c "sh /libs/base.sh /configs/common.sh"
}

function backup_tmp_OS(){
    _logger_info "Backing up tmp OS"

    umount $BROOT/dev{/pts,}
    umount $BROOT/{proc,sys,run}

    tar --exclude={"source","libs","configs","backup"} -cJpf $ROOT_DIR/backup-temp-OS-$BVERSION.tar.xz .

    mount_build_dirs
}

function build_tools(){
    _logger_info "Building bundled OS tools"

    # build packages in chroot environment
    chroot "$BROOT" /usr/bin/env -i  HOME="/root"     \
      TERM="$TERM"  PS1="(dev_OS chroot) \u:\w\$ \n"  \
      PATH="/usr/bin:/usr/sbin" /bin/bash --login +h  \
      -c "sh /libs/tools.sh /configs/common.sh"
}

function main(){
    create_kernel_dirs

    create_device_nodes

    mount_build_dirs

    changing_build_ownership

    if [ -f "$BROOT/backup/VERSION" ]; then
      restore_temp-tools

    else
      _unload_build_packages

      buid_tmp_OS

      backup_tmp_OS
    fi

    _unload_build_packages

    build_tools

    exit 0
}

main 2>&1 | tee -a $LOG_FILE
