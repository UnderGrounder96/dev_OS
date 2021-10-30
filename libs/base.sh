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

    cd /source

    mkdir -vp /{boot,home,mnt,opt,srv}
    mkdir -vp /{lib/firmware,etc/{opt,sysconfig},media/{floppy,cdrom}}

    mkdir -vp /usr/local/{{,s}bin,lib}
    mkdir -vp /usr/{local,share}/games
    mkdir -vp /usr/{,local/}{include,src}
    mkdir -vp /usr/{,local/}share/{color,dict,doc,info,locale,misc}
    mkdir -vp /usr/{,local/}share/{terminfo,zoneinfo,man/man{1..8}}

    mkdir -vp /var/{cache,local,log,mail,opt,spool,lib/{color,misc,locate}}

    install -dv -m 0750 /root
    install -dv -m 1777 /tmp /var/tmp

    ln -sfv /run /var/run
    ln -sfv /run/lock /var/lock
}

function create_essential_files(){
    _logger_info "Creating essential OS files and symlinks"

    # creates system logs
    touch /var/log/{btmp,lastlog,faillog,wtmp}

    chmod -v 600  /var/log/btmp
    chmod -v 664  /var/log/lastlog

    # creates symlink for (old-way) mounted file systems
    ln -sfv /proc/self/mounts /etc/mtab

    # creates basic hosts file
    tee /etc/hosts <<EOF
127.0.0.1  localhost.localdomain localhost localhost4 $(hostname)
::1        localhost.localdomain localhost localhost6
EOF

    # create default users - added "tester"
    tee /etc/passwd <<EOF
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/bin/false
systemd-bus-proxy:x:72:72:systemd Bus Proxy:/:/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/bin/false
systemd-network:x:76:76:systemd Network Management:/:/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/bin/false
systemd-oom:x:81:81:systemd Out Of Memory Daemon:/:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
tester:x:101:101::/dev/null:/bin/bash
EOF

    # create default groups - added "tester"
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
kvm:x:61:
systemd-bus-proxy:x:72:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
uuidd:x:80:
systemd-oom:x:81:81:
wheel:x:97:
nogroup:x:99:
users:x:999:
tester:x:101:
EOF

    chgrp -v utmp /var/log/lastlog
}

# ---------------------------- PACKAGES/UTILS ---------------------------------

function install_libcpp(){
    _logger_info "Installing Libstd++"

    pushd gcc-*/
      ln -sfv gthr-posix.h libgcc/gthr-default.h

      cd build

      CXXFLAGS="-g -O2 -D_GNU_SOURCE"            \
        ../libstdc++-v3/configure --prefix=/usr  \
        --host=$(uname -m)-BROOT-linux-gnu       \
        --disable-nls                            \
        --disable-multilib                       \
        --disable-libstdcxx-pch

      make
      make install
    popd
}

function install_gettext(){
    _logger_info "Installing gettext"

    pushd gettext-*/
      ./configure --disable-shared

      make
      cp -fuv gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
    popd
}

function install_bison(){
    _logger_info "Installing bison"

    pushd bison-*/
      ./configure --prefix=/usr \
        --docdir=/usr/share/doc/bison-*

      make
      make install
    popd
}

function install_perl(){
    _logger_info "Installing perl"

    pushd perl-*/
      # -des: Defaults for all items; Ensures completion of all tasks;
      #  and Silences non-essential output.
      sh Configure -des -Dprefix=/usr -Dvendorprefix=/usr \
        -Dprivlib=/usr/lib/perl5/5.34/core_perl           \
        -Darchlib=/usr/lib/perl5/5.34/core_perl           \
        -Dsitelib=/usr/lib/perl5/5.34/site_perl           \
        -Dsitearch=/usr/lib/perl5/5.34/site_perl          \
        -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl       \
        -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl

      make
      make install
    popd
}

function install_python3(){
    _logger_info "Installing python3"

    pushd Python-*/
      ./configure --prefix=/usr \
        --enable-shared         \
        --without-ensurepip

      make
      make install
    popd
}

function install_texinfo(){
    _logger_info "Installing texinfo"

    pushd texinfo-*/
      sed -i 's/__attribute_nonnull__/__nonnull/' \
        gnulib/lib/malloc/dynarray-skeleton.c

      ./configure --prefix=/usr

      make
      make install
    popd
}

function install_util_linux(){
    _logger_info "Installing util-linux"

    pushd util-linux-*/
      mkdir -vp /var/lib/hwclock

      ADJTIME_PATH="/var/lib/hwclock/adjtime"     \
        ./configure --libdir=/usr/lib             \
        --docdir=/usr/share/doc/util-linux-*      \
        --disable-chfn-chsh                       \
        --disable-login                           \
        --disable-nologin                         \
        --disable-su                              \
        --disable-setpriv                         \
        --disable-runuser                         \
        --disable-pylibmount                      \
        --disable-static                          \
        --without-python                          \
        runstatedir=/run

      make
      make install
    popd
}

# --------------------------- CLEANING ---------------------------------

function compilation_stripping(){
    _logger_info "Compilation Cleaning"

    rm -rf /tools /usr/share/{info,man,doc}/*

    find /usr/lib{,exec} -name \*.la -delete
}

function main(){
    _logger_info "Executing lib/base.sh"

    creating_os_dirs

    create_essential_files

    # ------- BUILD PKGS -------

    install_libcpp
    install_gettext
    install_bison
    install_perl
    install_python3
    install_texinfo
    install_util_linux

    # ------- CLEANING ---------
    compilation_stripping

    exit 0
}

main
