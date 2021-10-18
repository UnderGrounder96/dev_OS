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

    cp -fuv iana-etc-*/{services,protocols} /etc
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

      pushd /source
        # Adding time zone data
        local ZONEINFO=/usr/share/zoneinfo
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
      popd
    popd
}

function install_bzip2(){
    _logger_info "Installing bzip2"

    pushd bzip2-*/
      patch -Np1 -i ../bzip2-*-install_docs-1.patch

      # ensures that symbolic links have relative path
      sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile

      # corrects man pages location
      sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

      # prepares bzip2 compilation
      make --file Makefile-libbz2_so
      make clean

      # Bzip2 installation
      make
      make PREFIX=/usr install

      cp -afuv libbz2.so.* /usr/lib
      ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so

      cp -fuv bzip2-shared /usr/bin/bzip2
      for i in /usr/bin/{bzcat,bunzip2}; do
        ln -sfv bzip2 $i
      done

      # removes useless static library
      rm -f /usr/lib/libbz2.a
    popd
}

function install_xz(){
    _logger_info "Installing xz"

    pushd xz-*/
      ./configure --prefix=/usr       \
        --disable-static              \
        --docdir=/usr/share/doc/xz-*

      make
      # make check
      make install
    popd
}

function install_zstd(){
    _logger_info "Installing zstd"

    pushd zstd-*/

      make
      # make check
      make prefix=/usr install

      # removes useless static library
      rm -f /usr/lib/libzstd.a
    popd
}

function install_readline(){
    _logger_info "Installing readline"

    pushd readline-*/
      sed -i '/MV.*old/d' Makefile.in
      sed -i '/{OLDSUFF}/c:' support/shlib-install

    ./configure --prefix=/usr             \
      --with-curses                       \
      --disable-static                    \
      --docdir=/usr/share/doc/readline-*

      make SHLIB_LIBS="-lncursesw"
      make SHLIB_LIBS="-lncursesw" install

      install -v -m 644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-*
    popd
}

function install_bc(){
    _logger_info "Installing bc"

    pushd bc-*/

      CC=gcc ./configure --prefix=/usr -G -O3

      make
      # make test
      make install
    popd
}

function install_flex(){
    _logger_info "Installing flex"

    pushd flex-*/
      ./configure --prefix=/usr        \
        --docdir=/usr/share/doc/flex-* \
        --disable-static

      make
      # make check
      make install

      ln -sfv flex /usr/bin/lex
    popd
}

function install_tcl(){
    _logger_info "Installing tcl"

    pushd tcl*/
      SRCDIR=$(pwd)

      cd unix
      ./configure --prefix=/usr       \
        --mandir=/usr/share/man       \
          $([ "$(uname -m)" = x86_64 ] && echo --enable-64bit)

      make

      sed -e "s|$SRCDIR/unix|/usr/lib|" \
        -e "s|$SRCDIR|/usr/include|"  \
        -i tclConfig.sh

      sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.2|/usr/lib/tdbc1.1.2|" \
        -e "s|$SRCDIR/pkgs/tdbc1.1.2/generic|/usr/include|"    \
        -e "s|$SRCDIR/pkgs/tdbc1.1.2/library|/usr/lib/tcl8.6|" \
        -e "s|$SRCDIR/pkgs/tdbc1.1.2|/usr/include|"            \
        -i pkgs/tdbc1.1.2/tdbcConfig.sh

      sed -e "s|$SRCDIR/unix/pkgs/itcl4.2.1|/usr/lib/itcl4.2.1|" \
        -e "s|$SRCDIR/pkgs/itcl4.2.1/generic|/usr/include|"    \
        -e "s|$SRCDIR/pkgs/itcl4.2.1|/usr/include|"            \
        -i pkgs/itcl4.2.1/itclConfig.sh

      unset SRCDIR

      # make test
      make install

      # makes the lib writable to help future stripping
      chmod -v u+w /usr/lib/libtcl8.6.so

      make install-private-headers

      ln -sfv tclsh8.6 /usr/bin/tclsh

      # resolves conflicts with Perl man page
      mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
    popd
}

function install_expect(){
    _logger_info "Installing expect"

    pushd expect*/
      ./configure --prefix=/usr       \
        --mandir=/usr/share/man       \
        --with-tcl=/usr/lib           \
        --enable-shared               \
        --with-tclinclude=/usr/include

      make
      # make test
      make install

      ln -sfv expect5.45.4/libexpect5.45.4.so /usr/lib
    popd
}

function install_dejagnu(){
    _logger_info "Installing dejagnu"

    pushd dejagnu-*/
      mkdir -v build
      cd build

      ../configure --prefix=/usr

      # prepares dejagnu for compilation
      makeinfo --plaintext -o doc/dejagnu.txt ../doc/dejagnu.texi
      makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi

      make install

      install -dv -m 755 /usr/share/doc/dejagnu-1.6.3
      install -v -m 644 doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3

      # make check
    popd
}

function install_basic_packages(){
    _logger_info "Installing zlib"

    for pkg in zlib file m4 psmisc grep libtool autoconf diffutils gzip libpipeline \
    make patch; do
      _logger_info "Compiling $pkg"

      pushd $pkg-*/
        ./configure --prefix=/usr

        make
        # make check
        make install
      popd
    done

    # removes useless static libraries
    rm -f /usr/lib/libz.a
    rm -fv /usr/lib/libltdl.a
}

function install_binutils(){
    _logger_info "Installing binutils"

    expect -c "spawn ls"

    pushd binutils-*/
      patch -Np1 -i ../binutils-*-upstream_fix-1.patch

      # removes empty man pages
      sed -i '63d' etc/texi2pod.pl
      find -name \*.1 -delete

      mkdir -v build
      cd build

      ../configure --prefix=/usr  \
        --enable-gold             \
        --enable-shared           \
        --enable-plugins          \
        --enable-ld=default       \
        --enable-64-bit-bfd       \
        --disable-werror          \
        --with-system-zlib

      make tooldir=/usr
      # make --keep-going check

      make tooldir=/usr install

      # removes useless static libraries
      rm -f /usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.a
    popd
}

function install_gmp(){
    _logger_info "Installing gmp"

    pushd gmp-*/
      cp -fuv configfsf.sub   config.sub
      cp -fuv configfsf.guess config.guess

      ./configure --prefix=/usr     \
        --enable-cxx                \
        --disable-static            \
        --docdir=/usr/share/doc/gmp-* #\
        # --build=x86_64-pc-linux-gnu # uncomment if "Illegal instruction" message appears

      make
      make html

      # make check 2>&1 | tee gmp-check-log
      # awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log

      make install
      make install-html
    popd
}

function install_mpfr(){
    _logger_info "Installing mpfr"

    pushd mpfr-*/
      ./configure --prefix=/usr       \
        --disable-static              \
        --enable-thread-safe          \
        --docdir=/usr/share/doc/mpfr-*

      make
      make html

      # make check

      make install
      make install-html
    popd
}

function install_mpc(){
    _logger_info "Installing mpc"

    pushd mpc-*/
      ./configure --prefix=/usr    \
        --disable-static           \
        --docdir=/usr/share/doc/mpc-*

      make
      # make check
      make install
    popd
}

function install_attr(){
    _logger_info "Install attr"

    pushd attr-*/
      ./configure --prefix=/usr   \
        --sysconfdir=/etc         \
        --disable-static          \
        --docdir=/usr/share/doc/attr-*

      make
      # make check
      make install
    popd
}

function install_acl(){
    _logger_info "Installing ACL"

    pushd acl-*/
      ./configure --prefix=/usr     \
        --disable-static            \
        --docdir=/usr/share/doc/acl-*

      make
      # make check # test cases rely on coreutils installation
      make install
    popd
}

function install_libcap(){
    _logger_info "Install libcap"

    pushd libcap-*/
      # prevents static libraries installation
      sed -i '/install -m.*STA/d' libcap/Makefile

      make prefix=/usr lib=lib
      # make test
      make prefix=/usr lib=lib install

      # changes shared libraries permissions
      chmod -v 755 /usr/lib/lib{cap,psx}.so.2.53
    popd
}

function install_shadow(){
    _logger_info "Installing shadow"

    pushd shadow-*/
      # prevent manual pages installation and groups program
      sed -i 's/groups$(EXEEXT) //' src/Makefile.in
      find man -name Makefile.in -exec \
        sed -e 's/groups\.1 / /' -e 's/getspnam\.3 / /' -e 's/passwd\.5 / /' -i {} \;

      # changes default crypt encprition method to SHA-512, removes /var/spool/mail path
      # and removes /{,s}bin from path because they are symblinks to their /usr/{,s}bin
      sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD SHA512:' \
        -e 's:/var/spool/mail:/var/mail:'                 \
        -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                \
        -i etc/login.defs

      # fixes simple programming error
      sed -e "224s/rounds/min_rounds/" -i libmisc/salt.c

      # this file is hardcoded in some programs
      touch /usr/bin/passwd
      ./configure --sysconfdir=/etc --with-group-name-max-length=32

      make
      make exec_prefix=/usr install
      make -C man install-man

      mkdir -vp /etc/default
      useradd --defaults --gid 999

      # enable shadowed passwords (for users)
      pwconv

      # enable shadowed passwords (for groups)
      grpconv

      # disables CREATE_MAIL_SPOOL
      sed -i 's/yes/no/' /etc/default/useradd

      # passwd root
    popd
}

function install_gcc(){
    _logger_info "Installing GCC"

    pushd gcc-*/
      # fixes an issue breaking libasan.a when using GlibC-2.34
      sed -e '/static.*SIGSTKSZ/d' \
        -e 's/return kAltStackSize/return SIGSTKSZ * 4/' \
        -i libsanitizer/sanitizer_common/sanitizer_posix_libcdep.cpp

      cd build

      LD=ld ../configure --prefix=/usr  \
        --with-system-zlib              \
        --disable-multilib              \
        --disable-bootstrap             \
        --enable-languages=c,c++

      make

      # increases defaul stack, for testing
      # ulimit -s 32768

      # chown -vR tester .
      # su tester -c "PATH=$PATH MAKEFLAGS=$MAKEFLAGS make --keep-going check"
      # ../contrib/test_summary | grep -A7 Summ

      make install

      # removes unneeded directory
      rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/*/include-fixed/bits/

      chown -vR root: /usr/lib/gcc/*linux-gnu/*/include{,-fixed}

      # creates "historical" link
      ln -sfvr /usr/bin/cpp /usr/lib

      # adds a compatibility symlink to enable building programs with Link Time Optimization (LTO)
      ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/*/liblto_plugin.so \
        /usr/lib/bfd-plugins/


      # test_toolchain
      echo 'int main(){}' > dummy.c
      cc dummy.c -v -Wl,--verbose &> dummy.log
      local test_glibc=$(readelf -l a.out | grep ': /lib')

      echo $test_glibc | grep -w "/lib64/ld-linux-x86-64.so.2"

      _logger_info "Sanity check - passed"

      grep -B4 '^ /usr/include' dummy.log
      grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
      grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g'
      grep "/lib.*/libc.so.6 " dummy.log
      grep found dummy.log
      rm -f dummy.{c,log} a.out

      # moves misplaced file
      mkdir -vp /usr/share/gdb/auto-load/usr/lib
      mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
    popd
}

function install_pkg_config(){
    _logger_info "Install pkg-config"

    pushd pkg-config-*/
      ./configure --prefix=/usr    \
        --with-internal-glib       \
        --disable-host-tool        \
        --docdir=/usr/share/doc/pkg-config-*

      make
      # make check
      make install
    popd
}

function install_ncurses(){
    _logger_info "Install ncurses"

    pushd ncurses-*/
      ./configure --prefix=/usr   \
        --mandir=/usr/share/man   \
        --with-shared             \
        --without-debug           \
        --without-normal          \
        --enable-pc-files         \
        --enable-widec

      make
      make install

      # tricks programs into linking with wide-character libraries
      for lib in ncurses form panel menu ; do
        echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
        ln -sfv ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc
      done

      # ensures old programs looking for -lcursesm, are still buildable
      echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
      ln -sfv libncurses.so /usr/lib/libcurses.so

      # removes static library
      rm -f /usr/lib/libncurses++w.a

      # installs ncurses documentation
      mkdir -v       /usr/share/doc/ncurses-6.2
      cp -Rfuv doc/* /usr/share/doc/ncurses-6.2

      # optional - creates non-wide-character ncurses libraries
      make distclean
      ./configure --prefix=/usr   \
        --with-shared             \
        --without-normal          \
        --without-debug           \
        --without-cxx-binding     \
        --with-abi-version=5
      make sources libs
      cp -afuv lib/lib*.so.5* /usr/lib
    popd
}

function install_sed(){
    _logger_info "Installing sed"

    pushd sed-*/
      ./configure --prefix=/usr

      make
      make html

      # chown -vR tester .
      # su tester -c "PATH=$PATH make check"

      make install

      install -d -m 755           /usr/share/doc/sed-4.8
      install -m 644 doc/sed.html /usr/share/doc/sed-4.8
    popd
}

function install_gettext(){
    _logger_info "Installing gettext"

    pushd gettext-*/
      ./configure --prefix=/usr    \
        --disable-static           \
        --docdir=/usr/share/doc/gettext-*

      make
      # make check

      make install
      chmod -v 0755 /usr/lib/preloadable_libintl.so
    popd
}

function install_bison(){
    _logger_info "Installing bison"

    pushd bison-*/
      ./configure --prefix=/usr --docdir=/usr/share/doc/bison-*

      make
      # make check
      make install
    popd
}

function install_bash(){
    _logger_info "Installing bash"

    pushd bash-*/
      ./configure --prefix=/usr    \
        --without-bash-malloc      \
        --with-installed-readline  \
        --docdir=/usr/share/doc/bash-*

      make

      # chown -vR tester .
#       su -s /usr/bin/expect tester << EOF
# set timeout -1
# spawn make tests
# expect eof
# lassign [wait] _ _ _ value
# exit $value
# EOF

      make install

      # SKIP switching to built bash
      # exec /bin/bash --login +h
    popd
}

function main(){
    _logger_info "Executing lib/tools.sh"

    install_man
    install_iana
    install_glibc
    install_bzip2
    install_xz
    install_zstd
    install_readline
    install_bc
    install_flex
    install_tcl
    install_expect
    install_dejagnu
    install_basic_packages
    install_binutils
    install_gmp
    install_mpfr
    install_mpc
    install_attr
    install_acl
    install_libcap
    install_shadow
    install_gcc
    install_pkg_config
    install_ncurses
    install_sed
    install_gettext
    install_bison
    install_bash

    exit 0
}

main