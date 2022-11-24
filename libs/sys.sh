#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script configures dev_OS
# ==============================================================================

set -euo pipefail

COMMON="${1}"

source $COMMON
unset BTARGET

function configure_global(){
    _logger_info "Configuring system global settings"

    # defines empty password for root - optional
    tee /etc/shadow <<EOF
root::12699:0:::::
EOF

    # configures locale
    tee /etc/locale.conf <<EOF
    LANG="en_GB.UTF-8"
EOF

    # configures shells file
    tee /etc/shells <<EOF
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF

    # configures fstab file
    tee /etc/fstab <<EOF
# Begin /etc/fstab

# file system  mount-point  type     options             dump  fsck(order)

# rootfs         /            auto     defaults            1     1
# /dev/ram        /             auto      defaults              1     1

/dev/sda3      /            xfs      defaults            1     1
/dev/sda1      /boot        xfs      defaults            1     1
/dev/sda2      swap         swap     pri=1               0     0

proc            /proc         proc      nosuid,noexec,nodev   0     0
sysfs           /sys          sysfs     nosuid,noexec,nodev   0     0
devtmpfs        /dev          devtmpfs  mode=0755,nosuid      0     0
devpts          /dev/pts      devpts    gid=5,mode=620        0     0
tmpfs           /run          tmpfs     defaults              0     0

# End /etc/fstab
EOF

    # configures inputrc file
    tee /etc/inputrc <<EOF
# Begin /etc/inputrc

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# Completed names which are symbolic links to
# directories have a slash appended.
set mark-symlinked-directories on

# none, visible or audible
set bell-style none

# try to enable the application keypad when it is called.  Some systems
# need this to enable the arrow keys.
# set enable-keypad on

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF
}

function configure_network(){
    _logger_info "Configuring network"

    # sets hostname, needed during boot
    echo "dev-OS" | tee /etc/hostname

    # masks udev's .link to use the classic network interface names
    ln -sfv /dev/null /etc/systemd/network/99-default.link

    # using cloudfare dns
    tee /etc/resolv.conf <<EOF
# Begin /etc/resolv.conf
nameserver 1.1.1.1
nameserver 1.0.0.1
# End /etc/resolv.conf
EOF

    # configures systemd dhcp
    tee /etc/systemd/network/10-eth-dhcp.network <<EOF
[Match]
Name=eth0

[Network]
DHCP=ipv4

[DHCP]
UseDomains=true
EOF
}

function configure_systemd(){
    _logger_info "Configuring systemctl"

    # disables screen clearing at boot time - optional
    # mkdir -vp /etc/systemd/system/getty@tty1.service.d
    # tee /etc/systemd/system/getty@tty1.service.d/noclear.conf << EOF
# [Service]
# TTYVTDisallocate=no
# EOF

    # disables /tmp as tmpfs create - optional
    # ln -sfv /dev/null /etc/systemd/system/tmp.mount

    # enables system-wide process lingering
    sed -i 's/KillUserProcesses=yes/KillUserProcesses=no/' /etc/systemd/logind.conf
}

function configure_kernel(){
    _logger_info "Configuring Linux Kernel"

    pushd source/linux-*/
      # clean source tree
      make mrproper

      # manual configuration - docs: https://kernel.org/doc/html/latest/
      # make menuconfig

      # auto configuration - takes current system into account
      make defconfig

      # semi-manual configuration
      # cp -fuv /configs/kernel.config .config

      make
      make modules_install

      install -d /usr/share/doc/linux-5.13.12
      cp -Rfu Documentation/* /usr/share/doc/linux-*


      # for troubleshooting purposes
      cp -fuv .config /boot/config-5.13.12.devOS.x86_64 # holds kernel settings
      cp -fuv System.map /boot/System.map-5.13.12.devOS.x86_64 # holds kernel symbols
      cp -fuv arch/x86/boot/bzImage /boot/vmlinuz # holds kernel image

      # configures linux module load order
      install -dv -m 755 /etc/modprobe.d
      tee /etc/modprobe.d/usb.conf <<EOF
# Begin /etc/modprobe.d/usb.conf

install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

# End /etc/modprobe.d/usb.conf
EOF
    popd
}

function configure_grub(){
    _logger_info "Configuring GRUB"

    # sets up rescue disc, in case the system won't boot - xorriso was not installed!!!
    # cd /tmp
    # grub-mkrescue --output=grub-img.iso
    # xorriso -as cdrecord -v dev=/dev/cdrw blank=as_needed grub-img.iso

    # overwrites current bootloader
    grub-install /dev/sda

    tee /boot/grub/grub.cfg <<EOF
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod xfs
set root=(hd0,0)

menuentry "Dev-OS GNU/Linux 5.13.12" {
        linux   /vmlinuz root=/dev/sda3 ro
}
EOF
}

function configure_release(){
    _logger_info "Configuring release details"

    echo "dev-OS $BCODENAME" | tee /etc/devOS-release

    tee /etc/lsb-release <<EOF
DISTRIB_ID="dev-OS"
DISTRIB_RELEASE="$BVERSION"
DISTRIB_CODENAME="$BCODENAME"
DISTRIB_DESCRIPTION="Developer OS $BCODENAME"
EOF

    tee /etc/os-release <<EOF
NAME="dev-OS"
VERSION="$BVERSION"
ID="devOS"
PRETTY_NAME="Developer OS"
VERSION_CODENAME="$BCODENAME"
BUG_REPORT_URL="https://github.com/undergrounder96/dev_os/issues/new"
EOF
}

function main(){
    configure_global
    configure_network
    configure_systemd
    configure_kernel
    # configure_grub
    configure_release
}

main
