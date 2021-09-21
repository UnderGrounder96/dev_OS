#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script builds toolchains
# ==============================================================================

set +euo pipefail # strict mode disabled due to possible make fail

COMMON=${1}

source $COMMON
source ~/.bashrc

LOG_FILE="$BROOT/logs/temp_toolchain-$(date '+%F_%T').log"

function clean_cwd(){
    _logger_info "Removing everything from $PWD"

    local cwd=$PWD

    cd $cwd/..
    sudo rm -rf $cwd
    mkdir -vp $cwd
    cd $cwd
}

function compile_binutils(){
    _logger_info "Compiling binutils"

    ../binutils-2.36.1/configure \
      --prefix=/tools            \
      --with-sysroot=$BROOT      \
      --with-lib-path=/tools/lib \
      --target=$BTARGET          \
      --disable-nls              \
      --disable-werror

    make --debug --jobs 9

    case $(uname -m) in
        x86_64)
            mkdir -v /tools/lib && ln -sv lib /tools/lib64
            ;;
    esac

    make --debug install
}

function complice_gcc(){
    _logger_info "Compiling gcc"

    cd ../gcc-10.2.0/

    sudo mv -v ../mpfr-*.*.*/ mpfr/
    sudo mv -v ../gmp-*.*.*/ gmp/
    sudo mv -v ../mpc-*.*.*/ mpc/

    for file in $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h); do
        sudo cp -uv $file{,.orig}
        sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' -e 's@/usr@/tools@g' $file.orig | sudo tee $file 1>/dev/null
        echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' | sudo tee -a $file 1>/dev/null
        sudo touch $file.orig
    done

    cd ../build

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

    make --debug --jobs 9

    make --debug install
}

function main(){
    compile_binutils
    clean_cwd

    complice_gcc
    clean_cwd

    exit 0
}

main 2>&1 | tee -a $LOG_FILE
