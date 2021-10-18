#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script sets up OS build
# ==============================================================================

set -euo pipefail

COMMON="${1}"

source $COMMON
source ~/.bashrc

LOG_FILE="$ROOT_DIR/logs/temp-tools-$(date '+%F_%T').log"

# exits in case there is a temp-tools backup
[ -f "$BROOT/backup/VERSION" ] && exit 0

# --------------------------- STAGE 1 ------------------------------------------

function compile_binutils_1(){
    _logger_info "Compiling binutils pass 1"

    pushd binutils-*/
      mkdir -v build
      cd build

      ../configure --prefix=$BROOT/tools \
        --with-sysroot=$BROOT            \
        --target=$BTARGET                \
        --disable-nls                    \
        --disable-werror

      make
      make install
    popd

    _wipe_tool binutils
}

function compile_gcc_1(){
    _logger_info "Compiling gcc pass 1"

    pushd gcc-*/
      for i in mpfr gmp mpc; do
        mv ../$i-*/ $i
      done

      cd build

      ../configure --prefix=$BROOT/tools               \
        --with-sysroot=$BROOT                          \
        --target=$BTARGET                              \
        --with-glibc-version=2.11                      \
        --with-newlib                                  \
        --without-headers                              \
        --enable-initfini-array                        \
        --disable-nls                                  \
        --disable-shared                               \
        --disable-multilib                             \
        --disable-decimal-float                        \
        --disable-threads                              \
        --disable-libatomic                            \
        --disable-libgomp                              \
        --disable-libquadmath                          \
        --disable-libssp                               \
        --disable-libvtv                               \
        --disable-libstdcxx                            \
        --enable-languages=c,c++

      make
      make install

      cd ..
      cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
        `dirname $($BTARGET-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
    popd
}

function install_kernel_headers(){
    _logger_info "Installing Kernel Header (API) Files"

    pushd linux-*/
      make mrproper
      make headers

      find usr/include -name '.*' -delete
      rm -f usr/include/Makefile

      cp -rfu usr/include $BROOT/usr
    popd
}

function compile_glibc(){
    _logger_info "Compiling GNU C Library"

    pushd glibc-*/
      case $(uname -m) in
        i?86)
          ln -sfv ld-linux.so.2 $BROOT/lib/ld-lsb.so.3
        ;;
        x86_64)
          ln -sfv ../lib/ld-linux-x86-64.so.2 $BROOT/lib64
          ln -sfv ../lib/ld-linux-x86-64.so.2 $BROOT/lib64/ld-lsb-x86-64.so.3
        ;;
      esac

      cd build

      ../configure --prefix=/usr              \
        --host=$BTARGET                       \
        --build=$(../scripts/config.guess)    \
        --enable-kernel=3.2                   \
        --with-headers=$BROOT/usr/include     \
        libc_cv_slibdir=/usr/lib

      make
      make DESTDIR=$BROOT install

      sed '/RTLDLIST=/s@/usr@@g' -i $BROOT/usr/bin/ldd

      $BROOT/tools/libexec/gcc/$BTARGET/*/install-tools/mkheaders
    popd
}

function test_toolchain(){
    _logger_info "Performing Toolchain test"

    echo 'int main(){}' > dummy.c; $BTARGET-gcc dummy.c
    local test_glibc=$(readelf -l a.out | grep '/ld-linux')

    echo $test_glibc | grep -w "/lib64/ld-linux-x86-64.so.2"

    _logger_info "Sanity check - passed"

    rm -f dummy.c a.out
}

function compile_libcpp(){
    _logger_info "Compiling standard C++ Library"

    pushd gcc-*/
      rm -rf build
      mkdir -v build
      cd build

      ../libstdc++-v3/configure --prefix=/usr      \
        --host=$BTARGET                            \
        --build=$(../config.guess)                 \
        --disable-multilib                         \
        --disable-nls                              \
        --disable-libstdcxx-pch                    \
        --with-gxx-include-dir=/tools/$BTARGET/include/c++/11.2.0

      make
      make DESTDIR=$BROOT install
    popd
}

# --------------------------- PACKAGES/UTILS -----------------------------------

function compile_ncurses(){
    _logger_info "Compiling ncurses"

    pushd ncurses-*/
      # ensures that gawk command is found
      sed -i 's/mawk//' configure

      # builds "tic" program on build host
      mkdir -v build
      pushd build
        ../configure
        make -C include
        make -C progs tic
      popd

      ./configure --prefix=/usr      \
        --host=$BTARGET              \
        --build=$(./config.guess)    \
        --mandir=/usr/share/man      \
        --with-manpage-format=normal \
        --with-shared                \
        --without-debug              \
        --without-ada                \
        --without-normal             \
        --enable-widec

      make
      make DESTDIR=$BROOT TIC_PATH=$(pwd)/build/progs/tic install

      # libncurses.so library will be needed by the following built packages
      echo "INPUT(-lncursesw)" > $BROOT/usr/lib/libncurses.so
    popd
}

function compile_bash(){
    _logger_info "Compiling bash"

    pushd bash-*/
      ./configure --prefix=/usr         \
        --host=$BTARGET                 \
        --build=$(support/config.guess) \
        --without-bash-malloc

      make
      make DESTDIR=$BROOT install

      ln -sfv bash $BROOT/bin/sh
    popd
}

function compile_coreutils(){
    _logger_info "Compiling coreutils"

    pushd coreutils-*/
      ./configure --prefix=/usr                 \
        --host=$BTARGET                         \
        --build=$(build-aux/config.guess)       \
        --enable-install-program=hostname       \
        --enable-no-install-program=kill,uptime

      make
      make DESTDIR=$BROOT install

      # moves programs to their final expected locations.
      mv -v $BROOT/usr/bin/chroot $BROOT/usr/sbin

      mkdir -vp $BROOT/usr/share/man/man8
      sed -i 's/"1"/"8"/' $BROOT/usr/share/man/man1/chroot.1
      mv -v $BROOT/usr/share/man/man1/chroot.1 $BROOT/usr/share/man/man8/chroot.8
    popd
}

function compile_file(){
    _logger_info "Compiling file"

    pushd file-*/
      mkdir -v build
      pushd build
        ../configure --disable-libseccomp  \
          --disable-bzlib                  \
          --disable-xzlib                  \
          --disable-zlib
        make
      popd

      ./configure --prefix=/usr   \
        --host=$BTARGET           \
        --build=$(./config.guess)

      make FILE_COMPILE=$(pwd)/build/src/file
      make DESTDIR=$BROOT install
    popd
}

function compile_findutils(){
    _logger_info "Compiling findutils"

    pushd findutils-*/
      ./configure --prefix=/usr         \
        --host=$BTARGET                 \
        --localstatedir=/var/lib/locate \
        --build=$(build-aux/config.guess)

      make
      make DESTDIR=$BROOT install
    popd
}

function compile_gawk(){
    _logger_info "Compiling gawk"

    pushd gawk-*/
      sed -i 's/extras//' Makefile.in

      ./configure --prefix=/usr   \
        --host=$BTARGET           \
        --build=$(./config.guess)

      make
      make DESTDIR=$BROOT install
    popd
}

function compile_make(){
    _logger_info "Compiling make"

    pushd make-*/
      ./configure --prefix=/usr   \
        --host=$BTARGET           \
        --without-guile           \
        --build=$(build-aux/config.guess)

      make
      make DESTDIR=$BROOT install
    popd
}

function compile_xz(){
    _logger_info "Compiling xz"

    pushd xz-*/
      ./configure --prefix=/usr           \
        --host=$BTARGET                   \
        --disable-static                  \
        --build=$(build-aux/config.guess) \
        --docdir=/usr/share/doc/xz-*

      make
      make DESTDIR=$BROOT install
    popd
}

function compile_basic_packages(){
    for pkg in diffutils grep gzip sed; do
      _logger_info "Compiling $pkg"

      pushd $pkg-*/
        ./configure --prefix=/usr \
          --host=$BTARGET

        make
        make DESTDIR=$BROOT install
      popd
    done

    for pkg in m4 patch tar; do
      _logger_info "Compiling $pkg"

      pushd $pkg-*/
        ./configure --prefix=/usr          \
          --host=$BTARGET                  \
          --build=$(build-aux/config.guess)

        make
        make DESTDIR=$BROOT install
      popd
    done
}
# --------------------------- STAGE 2 ------------------------------------------

function compile_binutils_2(){
    _logger_info "Compiling binutils pass 2"

    pushd binutils-*/
      mkdir -v build
      cd build

      ../configure --prefix=/usr   \
        --host=$BTARGET            \
        --build=$(../config.guess) \
        --disable-nls              \
        --enable-shared            \
        --disable-werror           \
        --enable-64-bit-bfd

      make
      make DESTDIR=$BROOT install

      install -v -m 755 libctf/.libs/libctf.so.0.0.0 $BROOT/usr/lib
    popd
}

function compile_gcc_2(){
    _logger_info "Compiling gcc pass 2"

    pushd gcc-*/
      rm -rf build

      mkdir build
      cd build

      # creates symlink that allows posix threads support
      mkdir -vp $BTARGET/libgcc
      ln -sfv ../../../libgcc/gthr-posix.h $BTARGET/libgcc/gthr-default.h

      CC_FOR_TARGET=$BTARGET-gcc ../configure \
          --prefix=/usr                       \
          --host=$BTARGET                     \
          --build=$(../config.guess)          \
          --with-build-sysroot=$BROOT         \
          --enable-initfini-array             \
          --disable-nls                       \
          --disable-multilib                  \
          --disable-decimal-float             \
          --disable-libatomic                 \
          --disable-libgomp                   \
          --disable-libquadmath               \
          --disable-libssp                    \
          --disable-libvtv                    \
          --disable-libstdcxx                 \
          --enable-languages=c,c++

      make
      make DESTDIR=$BROOT install

      ln -sfv gcc $BROOT/usr/bin/cc
    popd
}

function main(){
# ------- STAGE 1 -------

    compile_binutils_1
    compile_gcc_1

    install_kernel_headers

    compile_glibc
    test_toolchain

    compile_libcpp

# ---- PACKAGES/UTILS ----

    compile_ncurses
    compile_bash
    compile_coreutils
    compile_file
    compile_findutils
    compile_gawk
    compile_make
    compile_xz
    compile_basic_packages

# # ------ STAGE 2 -------

    compile_binutils_2
    compile_gcc_2

    test_toolchain

    exit 0
}

main 2>&1 | sudo tee -a $LOG_FILE
