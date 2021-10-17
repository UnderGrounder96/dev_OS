#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script builds bundled dev_OS tools
# ==============================================================================

set -euo pipefail

COMMON="${1}"

source $COMMON
unset BTARGET

function install_man(){
    _logger_info "Installing man pages"

    cd /source

    pushd man-pages-*/
      make prefix=/usr install
    popd
}

function install_iana(){
      _logger_info "Installing man pages"

      pushd iana-etc-*/
        cp -fuv services protocols /etc
      popd
}

function install_glibc(){
    _logger_info "Installing GlibC"

    # creates glibc extra configuration folders
    mkdir -vp /usr/lib/locale /var/cache/nscd /etc/ld.so.conf.d

    pushd glibc-*/
      sed -i '/NOTIFY_REMOVED)/s/)/ \&\& data.attr != NULL)/' \
        sysdeps/unix/sysv/linux/mq_notify.c

      cd build

      ../configure --prefix=/usr          \
          --enable-stack-protector=strong \
          --with-headers=/usr/include     \
          --enable-kernel=3.2             \
          --disable-werror                \
          libc_cv_slibdir=/usr/lib

      make
      # make check || true

      # disables warnings about missing ld.so.conf
      touch /etc/ld.so.conf

      # skips "Perl" sanity check
      sed -i '/test-installation/s@$(PERL)@echo not running@' ../Makefile

      make install

      # fix hardcoded path in ldd script
      sed -i '/RTLDLIST=/s@/usr@@g' /usr/bin/ldd

      # install configuration files for nscd
      cp -fuv ../nscd/nscd.conf /etc/nscd.conf
      install -Dv -m 644 ../nscd/nscd.tmpfiles /usr/lib/tmpfiles.d/nscd.conf
      install -Dv -m 644 ../nscd/nscd.service /usr/lib/systemd/system/nscd.service

      # install locales for important test cases
      localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
      localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
      localedef -i de_DE -f ISO-8859-1 de_DE
      localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
      localedef -i de_DE -f UTF-8 de_DE.UTF-8
      localedef -i el_GR -f ISO-8859-7 el_GR
      localedef -i en_GB -f ISO-8859-1 en_GB
      localedef -i en_GB -f UTF-8 en_GB.UTF-8
      localedef -i en_HK -f ISO-8859-1 en_HK
      localedef -i en_PH -f ISO-8859-1 en_PH
      localedef -i en_US -f ISO-8859-1 en_US
      localedef -i en_US -f UTF-8 en_US.UTF-8
      localedef -i es_ES -f ISO-8859-15 es_ES@euro
      localedef -i es_MX -f ISO-8859-1 es_MX
      localedef -i fa_IR -f UTF-8 fa_IR
      localedef -i fr_FR -f ISO-8859-1 fr_FR
      localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
      localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
      localedef -i is_IS -f ISO-8859-1 is_IS
      localedef -i is_IS -f UTF-8 is_IS.UTF-8
      localedef -i it_IT -f ISO-8859-1 it_IT
      localedef -i it_IT -f ISO-8859-15 it_IT@euro
      localedef -i it_IT -f UTF-8 it_IT.UTF-8
      localedef -i ja_JP -f EUC-JP ja_JP
      localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true
      localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
      localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
      localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
      localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
      localedef -i se_NO -f UTF-8 se_NO.UTF-8
      localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
      localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
      localedef -i zh_CN -f GB18030 zh_CN.GB18030
      localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
      localedef -i zh_TW -f UTF-8 zh_TW.UTF-8


      # ---- Configuring GlibC ----

      # adds required nsswitch.conf
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

      # configures the Dynamic Loader
      tee /etc/ld.so.conf <<EOF
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

# Add an include directory
include /etc/ld.so.conf.d/*.conf
EOF
    popd

    # Adding time zone data
    ZONEINFO=/usr/share/zoneinfo
    mkdir -vp $ZONEINFO/{posix,right}

    for tz in etcetera southamerica northamerica europe africa antarctica  \
      asia australasia backward; do

      zic -L /dev/null   -d $ZONEINFO       ${tz}
      zic -L /dev/null   -d $ZONEINFO/posix ${tz}
      zic -L leapseconds -d $ZONEINFO/right ${tz}
    done

    cp -fuv zone.tab zone1970.tab iso3166.tab $ZONEINFO
    zic -d $ZONEINFO -p America/New_York

    # set time zone info
    ln -sfv /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
    unset ZONEINFO
}

function main(){
    _logger_info "Executing lib/tools.sh"

    install_man
    install_iana
    install_glibc

    exit 0
}

main