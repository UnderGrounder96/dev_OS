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

    bash $ROOT_DIR/extras/version-check.sh
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
BTARGET=$(uname -m)-BROOT-linux-gnu
PATH=$BROOT/tools/bin:/usr/bin
if [ ! -L /bin ]; then PATH=$PATH:/bin; fi
CONFIG_SITE=$BROOT/usr/share/config.site
export LC_ALL BROOT BTARGET PATH CONFIG_SITE
EOF

    # this file could potentially break the build, restore it once build is done
    [ ! -f /etc/bash.bashrc ] || mv -v /etc/bash.bashrc{,.NOUSE}
}

function create_temp-build_dirs(){
    _logger_info "Creating build directories"

    mkdir -vp $BROOT/{boot,backup,etc,var,tools}
    mkdir -vp $BROOT/{source,usr/{{,s}bin,lib{,exec}}}

    for dir in {,s}bin lib; do
      ln -sfv {usr/,$BROOT/}$dir
    done

    case $(uname -m) in
      x86_64)
        mkdir -vp $BROOT/usr/lib64
        ln -sfv {usr/,$BROOT/}lib64
      ;;
    esac

    chown -vR $BUSER $BROOT
}

function mount_build_disk(){
    _logger_info "Handling build_disk"

    mkdir -vp $BROOT

    parted --script /dev/sdb mklabel gpt # Labeling build_disk

    parted --script /dev/sdb mkpart primary 0% 120MB
    parted --script /dev/sdb set 1 bios_grub on # enables bios_grub flag in part1
    parted --script /dev/sdb mkpart primary 120MB 666MB
    parted --script /dev/sdb mkpart primary 666MB 48GB
    parted --script /dev/sdb mkpart primary 48GB  100%

    mkfs.fat /dev/sdb1 # EFI/GRUB partition
    mkfs.xfs -L DESTBOOT /dev/sdb2  # '/boot' partition
    mkfs.xfs -L DESTROOT /dev/sdb3 # '/' root file system partition

    mkswap --label DESTSWAP /dev/sdb4 # swap partition
    swapon LABEL=DESTSWAP

    # first mount $BROOT, then create folders
    mount -t xfs --label DESTROOT $BROOT

    create_temp-build_dirs

    mount -t xfs --label DESTBOOT $BROOT/boot

    # for persistent mount
    echo "LABEL=DESTROOT $BROOT xfs defaults 0 0" | tee -a /etc/fstab
    echo "LABEL=DESTBOOT $BROOT/boot xfs defaults 0 0" | tee -a /etc/fstab


    _logger_info "Sanity check"

    mount | grep 'sdb'
    swapon | grep 'sdb'
    lsblk
}

function check_for_backup(){
    if compgen -G "$ROOT_DIR/backup/backup*.tar*" >/dev/null; then
      _logger_info "Backup exists! Creating $BROOT/backup/VERSION"

      echo $BVERSION > $BROOT/backup/VERSION
    fi
}

function main(){
    group_installs

    solo_installs

    check_yaac

    create_temp-build_user

    mount_build_disk

    check_for_backup

    exit 0
}

main 2>&1 | tee -a $LOG_FILE
