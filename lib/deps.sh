#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script installs all dependencies
# ==============================================================================

set -euo pipefail

function group_installs(){
    _logger_info "Performing groupinstalls"
    sudo dnf group install -y "C Development Tools and Libraries"
    sudo dnf group install -y "Development Tools"
}

function solo_installs(){
    _logger_info "Performing soloinstalls"
    # sudo dnf install -y texinfo
}

function check_yaac(){
    _logger_info "Checking yaac x bison relation"
    rpm -qf `which yacc`

    sudo dnf remove -y byacc
    sudo dnf reinstall -y bison

    sudo ln -s `which bison` /bin/yacc
}

function create_user(){
    _logger_info "Handling build user creation"
    export BUILD_USER="byol"

    sudo useradd --create-home --skel /dev/null $BUILD_USER
    sudo usermod $BUILD_USER -aG wheel

    echo 'exec env -i HOME=$HOME TERM=$TERM PS1="[\u@\h \W]\$\n" /bin/bash' | sudo -u $BUILD_USER tee /home/$BUILD_USER/.bash_profile

    sudo -u $BUILD_USER tee /home/$BUILD_USER/.bashrc <<EOF 1>/dev/null
        set +h # disables history command path
        umask 022 # sets file creation permission
        export LC_ALL=POSIX
        export BROOT=/build
        export PATH=/tools/bin:/bin:/usr/bin
EOF
}

function build_disk_mount(){
    _logger_info "Handling build_disk"
    export BROOT="/build"

    sudo mkdir -vp $BROOT/boot

    # Labeling build_disk
    sudo parted --script /dev/sdb mklabel gpt

    # EFI/GRUB partition
    sudo parted --script /dev/sdb mkpart primary 0% 120MB
    sudo parted --script /dev/sdb set 1 bios_grub on # enables bios_grub flag in part1
    sudo mkfs.ext4 -L DESTGRUB /dev/sdb1

    # '/boot' partition
    sudo parted --script /dev/sdb mkpart primary 120MB 666MB
    sudo mkfs.xfs -L DESTBOOT /dev/sdb2
    sudo mount -t xfs --label DESTBOOT $BROOT/boot

    # '/' root file system partition
    sudo parted --script /dev/sdb mkpart primary 666MB 28GB
    sudo mkfs.xfs -L DESTROOT /dev/sdb3
    sudo mount -t xfs --label DESTROOT $BROOT

    # swap partition
    sudo parted --script /dev/sdb mkpart primary 28GB  100%
    sudo mkswap --label DESTSWAP /dev/sdb4
    sudo swapon LABEL=DESTSWAP


    _logger_info "Sanity check"
    mount | grep 'sdb'
    lsblk

    sleep 15s
}


function main(){
    group_installs
    solo_installs

    check_yaac

    create_user

    build_disk_mount

    exit 0
}

main