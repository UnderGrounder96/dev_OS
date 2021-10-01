#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script performs initial setup and installs dependencies
# ==============================================================================

set -euo pipefail

LOG_FILE="$ROOT_DIR/logs/dependencies-$(date '+%F_%T').log"

function group_installs(){
    _logger_info "Performing groupinstalls"

    dnf group install -y "Development Tools"
    dnf group install -y "C Development Tools and Libraries"
}

function solo_installs(){
    _logger_info "Performing soloinstalls"

    dnf install -y dosfstools # ms-dos fs tools, mkvfat
}

function check_yaac(){
    _logger_info "Checking yaac x bison relation"

    rpm -qf `which yacc`

    dnf remove -y byacc
    dnf reinstall -y bison

    ln -sfv `which bison` /bin/yacc
}

function create_temp-build_user(){
    _logger_info "Handling build user creation"

    useradd --create-home --skel /dev/null --gid wheel $BUSER

    echo "$BUSER    ALL=(ALL) NOPASSWD:    ALL" | tee -a /etc/sudoers

    echo 'exec env -i HOME=$HOME TERM=$TERM PS1="[\u@\h \W]\$\n" /bin/bash' | sudo -u $BUSER tee /home/$BUSER/.bash_profile

    sudo -u $BUSER tee /home/$BUSER/.bashrc <<EOF 1>/dev/null
set +h # disables history command path
umask 022 # sets file creation permission
LC_ALL=POSIX
BROOT=/build
BTARGET=x86_64-BROOT-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LC_ALL BROOT BTARGET PATH
EOF
}

function create_temp-build_dirs(){
    _logger_info "Creating build directories"

    mkdir -vp $BROOT/{boot,source/build,tools/lib}
    chown -vR $BUSER $BROOT
    ln -sfv $BROOT/tools / # '/tools' -> '$BROOT/tools'

    install -dv -m 1777 $BROOT/backup
}

function mount_build_disk(){
    _logger_info "Handling build_disk"

    install -dv -m 1777 $BROOT # sets sticky bit, prevents 'others' from deleting files

    # Labeling build_disk
    parted --script /dev/sdb mklabel gpt

    # EFI/GRUB partition
    parted --script /dev/sdb mkpart primary 0% 120MB
    parted --script /dev/sdb set 1 bios_grub on # enables bios_grub flag in part1
    mkfs.fat /dev/sdb1

    # '/boot' partition
    parted --script /dev/sdb mkpart primary 120MB 666MB
    mkfs.xfs -L DESTBOOT /dev/sdb2

    # '/' root file system partition
    parted --script /dev/sdb mkpart primary 666MB 28GB
    mkfs.xfs -L DESTROOT /dev/sdb3
    mount -t xfs --label DESTROOT $BROOT

    # swap partition
    parted --script /dev/sdb mkpart primary 28GB  100%
    mkswap --label DESTSWAP /dev/sdb4
    swapon LABEL=DESTSWAP

    create_temp-build_dirs # first mount $BROOT, then create folders

    mount -t xfs --label DESTBOOT $BROOT/boot

    # for persistent mount
    echo "LABEL=DESTROOT $BROOT xfs defaults 0 0" | tee -a /etc/fstab
    echo "LABEL=DESTBOOT $BROOT/boot xfs defaults 0 0" | tee -a /etc/fstab


    _logger_info "Sanity check"

    mount | grep 'sdb'
    swapon | grep 'sdb'
    lsblk
}

function unload_build_packages(){
    _logger_info "Unloading build packages"

    pushd $BROOT/source
      sudo -u $BUSER cp -fuv $ROOT_DIR/bin/* . # offline packages unloading
      sudo -u $BUSER find -name "*.tar*" -exec tar -xf {} \; -delete
    popd
}

function restore_temp-tools(){
    if [ -f "$ROOT_DIR/backup/backup-temp-tools-$BVERSION.tar.xz" ]; then
      _logger_info "Restoring build temptools"

      cd $BROOT

      tar -xpf $ROOT_DIR/backup/backup*$BVERSION*.tar*

      echo $BVERSION > $BROOT/backup/VERSION
    fi
}

function main(){
    group_installs

    solo_installs

    check_yaac

    create_temp-build_user

    mount_build_disk

    unload_build_packages

    restore_temp-tools

    exit 0
}

main 2>&1 | tee -a $LOG_FILE
