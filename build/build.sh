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

function configure_tmp-OS(){
    _logger_info "Configuring tmp-OS"

    chroot "$BROOT" /usr/bin/env -i HOME="/root"    \
      TERM="$TERM" PS1="(dev_OS chroot) \u:\w\$ \n" \
      PATH="/usr/bin:/usr/sbin" /bin/bash --login   \
      -c "sh /libs/sys.sh /configs/common.sh"
}

function export-dev_OS(){
    _logger_info "Exporting dev_OS-$BVERSION.iso"

    # clean-ups
    rm -rf $BROOT/{backup,configs,libs,source,tools}

    umount $BROOT/dev{/pts,}
    umount $BROOT/{proc,sys,run}

    pushd /tmp/
      # preparing iso export
      wget -nv $SYSLINUX  && tar -xf syslinux-*.tar*

      mkdir -vp build_iso/isolinux/

      cp -fu syslinux-*/bios/core/isolinux.bin \
        syslinux-*/bios/com32/elflink/ldlinux/ldlinux.c32 \
        build_iso/isolinux/

      cp -Rfu $BROOT/boot build_iso/

      tee build_iso/isolinux/isolinux.cfg <<"EOF"
DEFAULT linux
TIMEOUT 3
PROMPT 0

MENU TITLE Dev-OS GNU/Linux 5.13.12

LABEL linux
    KERNEL /boot/vmlinuz
    APPEND root=/dev/sda5 init=/bin/bash
EOF # initrd=boot/efiboot.img

      # configuring iso export, size (kb)
      local IMAGE_SIZE=9000000
      local RAMDISK=/tmp/ramdisk
      local LOOP_DIR=/tmp/dev/loop0

      # creates loop0 dir and dev
      mkdir -vp $LOOP_DIR
      mknod /dev/loop0 b 7 0

      # creates initial ramdisk file
      dd if=/dev/zero of=$RAMDISK bs=1k count=$IMAGE_SIZE

      # detaches any (virtual) fs from loop device
      losetup --detach /dev/loop0 || true

      # assosiates ramdisk with loop0
      losetup /dev/loop0 $RAMDISK

      # creates ext4 filesystem
      mkfs.ext4 -q -m 0 /dev/loop0 $IMAGE_SIZE

      mount /dev/loop0 $LOOP_DIR
      rm -rf $LOOP_DIR/lost+found

      # copy dev_OS
      cp -dpRfu $BROOT/* $LOOP_DIR

      # show statistics
      df -lh $LOOP_DIR
      du -sh $LOOP_DIR

      # lists system ramdisk to image
      bzip2 --stdout $RAMDISK > build_iso/boot/efiboot.img

      cd build_iso

      # generating iso image
      genisoimage -o devOS-minimal-$BVERSION-$(date +%F)-x86_64.iso \
        -b isolinux/isolinux.bin  -c isolinux/boot.cat -no-emul-boot \
        -boot-info-table -boot-load-size 4 . # -eltorito-alt-boot -e boot/efiboot.img

      # more clean-ups
      umount -v $LOOP_DIR
      losetup --detach /dev/loop0
    popd

    # umount -vR --lazy $BROOT
}

function main(){
    create_kernel_dirs

    create_device_nodes

    mount_build_dirs

    changing_build_ownership

    if compgen -G "$ROOT_DIR/backup/backup-tmp-OS.tar*" >/dev/null; then
      restore tmp-OS

      tar -xf $ROOT_DIR/bin/linux-*.tar* -C $BROOT/source

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

    configure_tmp-OS

    export-dev_OS

    exit 0
}

main 2>&1 | tee -a $LOG_FILE
