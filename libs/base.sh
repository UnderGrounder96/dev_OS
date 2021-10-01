#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script builds the base dev_OS
# ==============================================================================

set -euo pipefail

COMMON="${1}"

source $COMMON
unset BTARGET

function creating_os_dirs() {
    _logger_info "Creating OS dirs"

    mkdir -vp /{media/{floppy,cdrom},srv}
    mkdir -vp /{{,s}bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}

    mkdir -vp /usr/libexec
    mkdir -vp /usr/{,local/}{{,s}bin,include,lib,src}
    mkdir -vp /usr/{,local/}share/{color,dict,doc,info,locale,misc}
    mkdir -vp /usr/{,local/}share/{terminfo,zoneinfo,man/man{1..8}}

    mkdir -vp /var/{lib/{color,misc,locate},opt,cache,local,log,mail,spool}

    install -dv -m 0750 /root
    install -dv -m 1777 /tmp /var/tmp

    ln -sfv /run /var/run
    ln -sfv /run/lock /var/lock

    case $(uname -m) in
      x86_64)
        ln -sfv lib /lib64
        ln -sfv lib /usr/lib64
        ln -sfv lib /usr/local/lib64
      ;;
    esac
}

function create_essential_files(){
    _logger_info "Creating essential OS files and symlinks"

    touch /var/log/{btmp,lastlog,faillog,wtmp}

    chmod -v 664  /var/log/lastlog
    chmod -v 600  /var/log/btmp

    ln -sfv /tools/bin/perl /usr/bin
    ln -sfv /tools/bin/{bash,cat,echo,pwd,stty} /bin
    ln -sfv /tools/lib/libgcc_s.so{,.1} /usr/lib
    ln -sfv /tools/lib/libstdc++.so{,.6} /usr/lib
    ln -sfv bash /bin/sh

    # create symlink for list of the mounted file systems
    ln -sfv /proc/self/mounts /etc/mtab

    # create default users
    tee /etc/passwd <<EOF
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF

    # create default groups
    tee /etc/group <<EOF
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
nogroup:x:99:
users:x:999:
EOF

    chgrp -v utmp /var/log/lastlog
}

function main(){
    _logger_info "Executing lib/base.sh"

    creating_os_dirs

    create_essential_files

    exit 0
}

main
