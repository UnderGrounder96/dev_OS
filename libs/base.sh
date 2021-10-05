#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script builds the base dev_OS
# ==============================================================================

set -euo pipefail

COMMON="${1}"

source $COMMON
unset BTARGET

function clean_cwd(){
    _logger_info "Removing everything from $PWD"

    local cwd=$PWD

    cd $cwd/..
    rm -rf $cwd
    mkdir -vp $cwd
    cd $cwd
}

function creating_os_dirs() {
    _logger_info "Creating OS dirs"

    cd /source/build

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

function install_man_pages(){
    _logger_info "Installing man-pages"

    pushd ../man-pages-*
      make --jobs 9 install
    popd
}

function install_glibc(){
    _logger_info "Installing GlibC"

    # create glibc extra configuration folders
    mkdir -vp /var/cache/nscd /usr/lib/locale /etc/ld.so.conf.d

    pushd ../glibc-*/
      sed -e '402a\      *result = local->data.services[database_index];' \
        -i nss/nss_database.c
    popd

    ../glibc-*/configure --prefix=/usr  \
      --disable-werror                  \
      --enable-kernel=3.2               \
      --enable-stack-protector=strong   \
      --with-headers=/tools/include

    make --jobs 9

    make --jobs 9 check || true

    touch /etc/ld.so.conf

    # skips unneeded sanity check
    sed '/test-installation/s@$(PERL)@echo not running@' -i ../glibc-*/Makefile

    make --jobs 9 install

    cp -fuv ../glibc-*/nscd/nscd.conf /etc/nscd.conf


    # install the locales that can make the system respond in a different language
    localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
    localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
    localedef -i de_DE -f ISO-8859-1 de_DE
    localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
    localedef -i de_DE -f UTF-8 de_DE.UTF-8
    localedef -i el_GR -f ISO-8859-7 el_GR
    localedef -i en_GB -f UTF-8 en_GB.UTF-8
    localedef -i en_HK -f ISO-8859-1 en_HK
    localedef -i en_PH -f ISO-8859-1 en_PH
    localedef -i en_US -f ISO-8859-1 en_US
    localedef -i en_US -f UTF-8 en_US.UTF-8
    localedef -i es_MX -f ISO-8859-1 es_MX
    localedef -i fa_IR -f UTF-8 fa_IR
    localedef -i fr_FR -f ISO-8859-1 fr_FR
    localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
    localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
    localedef -i it_IT -f ISO-8859-1 it_IT
    localedef -i it_IT -f UTF-8 it_IT.UTF-8
    localedef -i ja_JP -f EUC-JP ja_JP
    localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true
    localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
    localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
    localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
    localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
    localedef -i zh_CN -f GB18030 zh_CN.GB18030
    localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS

    # ---- Configuring GlibC ----

    # Adding nsswitch.conf
    tee /etc/nsswitch.conf <<EOF
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

    # Configuring the Dynamic Loader
    tee /etc/ld.so.conf <<EOF
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

# Add an include directory
include /etc/ld.so.conf.d/*.conf
EOF

    # Adding time zone data
    pushd /source
      ZONEINFO=/usr/share/zoneinfo
      mkdir -vp $ZONEINFO/{posix,right}

      for tz in etcetera southamerica northamerica europe africa \
        antarctica asia australasia backward; do

        zic -L /dev/null   -d $ZONEINFO       ${tz}
        zic -L /dev/null   -d $ZONEINFO/posix ${tz}
        zic -L leapseconds -d $ZONEINFO/right ${tz}
      done

      cp -fuv zone.tab zone1970.tab iso3166.tab $ZONEINFO
      zic -d $ZONEINFO -p America/New_York

      # set time zone info
      ln -sfv /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
      unset ZONEINFO
    popd
}

function main(){
    _logger_info "Executing lib/base.sh"

    creating_os_dirs
    clean_cwd

    create_essential_files

    install_man_pages

    install_glibc

    exit 0
}

main
