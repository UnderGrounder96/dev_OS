#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script installs all dependencies
# ==============================================================================

set -euo pipefail

LOG_FILE="$ROOT_DIR/logs/dependencies-$(date '+%F_%T').log"

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

    sudo ln -vs `which bison` /bin/yacc
}

function create_build_user(){
    _logger_info "Handling build user creation"

    sudo useradd --create-home --skel /dev/null $BUSER
    sudo usermod $BUSER -aG wheel

    echo "$BUSER    ALL=(ALL) NOPASSWD:    ALL" | sudo tee -a /etc/sudoers

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

function create_build_dirs(){
    _logger_info "Creating build directories"

    sudo mkdir -vp $BROOT/{boot,source/build,logs,tools}
    sudo ln -vs $BROOT/tools / # '/tools' -> '$BROOT/tools'
    sudo chmod -vR 1777 $BROOT # sets sticky bit, prevents 'others' from deleting files
    sudo chown -vh $BUSER /tools # first we change the ownership of the symbolic link
    sudo chown -vR $BUSER $BROOT
}

function mount_build_disk(){
    _logger_info "Handling build_disk"

    sudo mkdir -vp $BROOT

    # Labeling build_disk
    sudo parted --script /dev/sdb mklabel gpt

    # EFI/GRUB partition
    sudo parted --script /dev/sdb mkpart primary 0% 120MB
    sudo parted --script /dev/sdb set 1 bios_grub on # enables bios_grub flag in part1
    sudo mkfs.ext4 -L DESTGRUB /dev/sdb1

    # '/boot' partition
    sudo parted --script /dev/sdb mkpart primary 120MB 666MB
    sudo mkfs.xfs -L DESTBOOT /dev/sdb2

    # '/' root file system partition
    sudo parted --script /dev/sdb mkpart primary 666MB 28GB
    sudo mkfs.xfs -L DESTROOT /dev/sdb3
    sudo mount -t xfs --label DESTROOT $BROOT

    # swap partition
    sudo parted --script /dev/sdb mkpart primary 28GB  100%
    sudo mkswap --label DESTSWAP /dev/sdb4
    sudo swapon LABEL=DESTSWAP


    create_build_dirs # fisrt mount $BROOT, then create folders

    sudo mount -t xfs --label DESTBOOT $BROOT/boot

    # for persistent mount
    echo "LABEL=DESTROOT $BROOT xfs defaults 0 0" | sudo tee -a /etc/fstab
    echo "LABEL=DESTBOOT $BROOT/boot xfs defaults 0 0" | sudo tee -a /etc/fstab


    _logger_info "Sanity check"
    mount | grep 'sdb'
    lsblk
}

function main(){
    group_installs
    solo_installs

    check_yaac

    create_build_user

    mount_build_disk

    exit 0
}

main 2>&1 | tee -a $LOG_FILE