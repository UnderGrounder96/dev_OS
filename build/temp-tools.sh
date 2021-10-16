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

function wipe_tool(){
    _logger_info "Removing everything from ${1}"

    rm -rf ${1}*/
    tar -xf ${1}*.tar*
}

# --------------------------- STAGE 1 ------------------------------------------

function compile_binutils_1(){
    _logger_info "Compiling binutils pass 1"

    pushd binutils-*/
      mkdir -v build
      cd build

      ../configure --prefix=/tools   \
        --with-sysroot=$BROOT        \
        --target=$BTARGET            \
        --disable-nls                \
        --disable-werror

      make
      make install
    popd

    wipe_tool binutils
}

function compile_gcc_1(){
    _logger_info "Compiling gcc pass 1"

    pushd gcc-*/
      mv -v ../mpfr-*/ mpfr/
      mv -v ../gmp-*/ gmp/
      mv -v ../mpc-*/ mpc/

      case $(uname -m) in
        x86_64)
          sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
        ;;
      esac

      mkdir -v build
      cd build

    ../configure --prefix=/tools                     \
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

      mkdir -v build
      cd build

      # ensures 'ldconfig' and 'sln' utilites are installed into /usr/sbin
      echo "rootsbindir=/usr/sbin" > configparms

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

    wipe_tool gcc
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
    _logger_info "Compiling binutils part 2"

    export CC=$BTARGET-gcc
    export AR=$BTARGET-ar
    export RANLIB=$BTARGET-ranlib

    ../binutils-*/configure      \
      --prefix=/tools            \
      --disable-nls              \
      --disable-werror           \
      --with-lib-path=/tools/lib \
      --with-sysroot

    make

    make install

    make --directory ld clean
    make --directory ld LIB_PATH=/usr/lib:/lib

    cp -fuv ld/ld-new /tools/bin
}

function compile_gcc_2(){
    _logger_info "Compiling gcc part 2"

    pushd $BROOT/source/gcc-10.2.0
      cat gcc/limitx.h gcc/glimits.h gcc/limity.h >  \
        `dirname $($BTARGET-gcc -print-libgcc-file-name)`/include-fixed/limits.h
    popd

    export CC=$BTARGET-gcc
    export CXX=$BTARGET-g++
    export AR=$BTARGET-ar
    export RANLIB=$BTARGET-ranlib

    ../gcc-10.2.0/configure                          \
      --prefix=/tools                                \
      --with-local-prefix=/tools                     \
      --with-native-system-header-dir=/tools/include \
      --enable-languages=c,c++                       \
      --disable-libstdcxx-pch                        \
      --disable-multilib                             \
      --disable-bootstrap                            \
      --disable-libgomp

    make

    make install

    ln -sfv gcc /tools/bin/cc

    unset CC CXX AR RANLIB
}

# --------------------------- CLEANING/BACKUP -----------------------------------

function compilation_stripping(){
    _logger_info "Compilation Cleaning"

    strip --strip-debug /tools/lib/* || true
    /usr/bin/strip --strip-unneeded /tools/{,s}bin/* || true

    rm -rf /tools/{,share}/{info,man,doc}

    find /tools/lib{,exec} -name \*.la -delete
}

function backup_temp-tools(){
    _logger_info "Backing up build temptools"

    cd $BROOT

    sudo rm -rf $BROOT/source
    mkdir -v $BROOT/source

    _unload_build_packages

    sudo chown -R root: $BROOT/tools

    sudo tar --ignore-failed-read --exclude="source" -cJpf $ROOT_DIR/backup-temp-tools-$BVERSION.tar.xz .
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

#     compile_binutils_2
#     clean_cwd

#     compile_gcc_2
#     clean_cwd

#     test_toolchain

# --- CLEANING/BACKUP ---
#     compilation_stripping
#     backup_temp-tools

    exit 0
}

main 2>&1 | sudo tee -a $LOG_FILE
