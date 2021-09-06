#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script builds toolchains
# ==============================================================================

set +euo pipefail # strict mode disabled due to possible make fail

COMMON=${1}

source $COMMON
source ~/.bashrc

function clean_cwd(){
    _logger_info "Removing everything from $PWD"
    sudo rm -rf {*,.*}
}

function compile_binutils(){
    _logger_info "Compiling binutils"

    ../binutils-2.36.1/configure \
      --prefix=/tools \
      --with-sysroot=$BROOT \
      --with-lib-path=/tools/lib \
      --target=$BTARGET  \
      --disable-nls \
      --disable-werror

    make --debug --jobs 9

    case $(uname -m) in
        x86_64)
            mkdir -v /tools/lib && ln -sv lib /tools/lib64
            ;;
    esac

    make --debug install
}

function main(){
    compile_binutils
    clean_cwd
}

main
