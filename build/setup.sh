#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script sets up OS build
# ==============================================================================

set -euo pipefail

COMMON="${1}"

source $COMMON
source ~/.bashrc

LOG_FILE="$ROOT_DIR/logs/setup-$(date '+%F_%T').log"

function clean_cwd(){
    _logger_info "Removing everything from $PWD"

    local cwd=$PWD

    cd $cwd/..
    sudo rm -rf $cwd
    mkdir -vp $cwd
    cd $cwd
}

function unload_build_packages(){
    _logger_info "Unloading build packages"

    pushd $BROOT/source
      cp -v $ROOT_DIR/bin/* . # offline packages unloading
      find -name "*.tar*" -exec tar -xf {} \;
    popd
}

function compile_binutils_1(){
    _logger_info "Compiling binutils part 1"

    ../binutils-2.36.1/configure \
      --prefix=/tools            \
      --with-sysroot=$BROOT      \
      --with-lib-path=/tools/lib \
      --target=$BTARGET          \
      --disable-nls              \
      --disable-werror

    make --jobs 9

    mkdir -v /tools/lib && ln -sv lib /tools/lib64

    make install
}

function complice_gcc_1(){
    _logger_info "Compiling gcc part 1"

    pushd $BROOT/source/gcc-10.2.0
      mv -v ../mpfr-*.*.*/ mpfr/
      mv -v ../gmp-*.*.*/ gmp/
      mv -v ../mpc-*.*.*/ mpc/

      for file in $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h); do
          cp -uv $file{,.orig}
          sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' -e 's@/usr@/tools@g' $file.orig > $file
          echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
          touch $file.orig
      done
    popd

    ../gcc-10.2.0/configure                          \
      --target=$BTARGET                              \
      --prefix=/tools                                \
      --with-glibc-version=2.24                      \
      --with-sysroot=$BROOT                          \
      --with-newlib                                  \
      --without-headers                              \
      --with-local-prefix=/tools                     \
      --with-native-system-header-dir=/tools/include \
      --disable-nls                                  \
      --disable-shared                               \
      --disable-multilib                             \
      --disable-decimal-float                        \
      --disable-threads                              \
      --disable-libatomic                            \
      --disable-libgomp                              \
      --disable-libmpx                               \
      --disable-libquadmath                          \
      --disable-libssp                               \
      --disable-libvtv                               \
      --disable-libstdcxx                            \
      --enable-languages=c,c++

    make --jobs 9

    make install
}

function install_kernel_headers(){
    _logger_info "Installing Kernel Header Files"

    pushd $BROOT/source/linux-5.10.17
      make mrproper
      make INSTALL_HDR_PATH=dest headers_install
      cp -rfv dest/include /tools
    popd
}

function compile_glibc(){
    _logger_info "Compiling GNU C Library"

    pushd $BROOT/source/glibc-2.33
      patch -Np1 -i ../glibc-2.33-fhs-1.patch
    popd

    export libc_cv_forced_unwind=yes
    export libc_cv_c_cleanup=yes

    ../glibc-2.33/configure                         \
      --prefix=/tools                               \
      --host=$BTARGET                               \
      --build=$(../glibc-2.33/scripts/config.guess) \
      --enable-kernel=3.2                           \
      --with-headers=/tools/include

    make # --jobs 9 may fail

    make install

    unset libc_cv_forced_unwind
    unset libc_cv_c_cleanup
}

function test_toolchain(){
    _logger_info "Performing Toolchain test"

    echo 'int main(){}' > dummy.c; $BTARGET-gcc dummy.c
    local test_glibc=$(readelf -l a.out | grep ': /tools')

    echo $test_glibc | grep -w "/tools/lib64/ld-linux-x86-64.so.2"

    _logger_info "Sanity check - passed"

    rm -vf dummy.c a.out
}

function compile_glibcpp(){
    _logger_info "Compiling GNU C++ Library"

    ../gcc-10.2.0/libstdc++-v3/configure         \
      --host=$BTARGET                            \
      --prefix=/tools                            \
      --disable-multilib                         \
      --disable-nls                              \
      --disable-libstdcxx-threads                \
      --disable-libstdcxx-pch                    \
      --with-gxx-include-dir=/tools/$BTARGET/include/c++/6.2.0

    make --jobs 9

    make install
}

function main(){
    unload_build_packages

    compile_binutils_1
    clean_cwd

    complice_gcc_1
    clean_cwd

    install_kernel_headers

    compile_glibc
    clean_cwd

    test_toolchain

    compile_glibcpp
    clean_cwd

    exit 0
}

main 2>&1 | sudo -u vagrant tee -a $LOG_FILE
