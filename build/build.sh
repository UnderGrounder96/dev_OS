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

function restore(){
    _logger_info "Restoring ${1}"

    tar -xpf $ROOT_DIR/backup/backup*${1}*.tar*
}

function backup(){
    _logger_info "Backing up ${1}"

    umount $BROOT/dev{/pts,}
    umount $BROOT/{proc,sys,run}

    tar --exclude={"source","libs","configs","backup"} -cJpf $ROOT_DIR/backup-${1}.tar.xz .

    mount_build_dirs
}

function buid_basic_OS(){
    _logger_info "Building basic OS"

    # build basic OS in chroot environment
    chroot "$BROOT" /usr/bin/env -i  HOME="/root"     \
      TERM="$TERM"  PS1="(dev_OS chroot) \u:\w\$ \n"  \
      PATH="/usr/bin:/usr/sbin" /bin/bash --login +h  \
      -c "sh /libs/base.sh /configs/common.sh"
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
    if compgen -G "$ROOT_DIR/backup/backup-tmp-OS.tar*" >/dev/null; then
      restore tmp-OS

    else
      if compgen -G "$ROOT_DIR/backup/backup-basic-OS.tar*" >/dev/null; then
        restore basic-OS

      else
        _unload_build_packages

        buid_basic_OS

        backup basic-OS
      fi

      _unload_build_packages

      build_tools

      backup tmp-OS
    fi

    exit 0
}

main 2>&1 | tee -a $LOG_FILE
