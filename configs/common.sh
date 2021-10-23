#!/usr/bin/env bash

# author		      @undergrounder96
# description     Helper file
# ==============================================================================

# build variables
BUSER="byol"
BROOT="/build"
BTARGET="$(uname -m)-BROOT-linux-gnu"
BVERSION="1.0.0"
MAKEFLAGS="--jobs 9"
CONFIG_SITE=$BROOT/usr/share/config.site

# helper function
function _logger_info(){
    echo -e "\n[$(date '+%d/%b/%Y %T')]: $*...\n"
}

function _wipe_tool(){
    _logger_info "Removing everything from ${1}"

    cd $BROOT/source
    rm -rf ${1}*/
    tar -xf ${1}*.tar*
}

function _unload_build_packages(){
    _logger_info "Unloading build packages"

    rm -rf $BROOT/source/*

    pushd $BROOT/source
      cp -fuv $ROOT_DIR/bin/* . # offline packages unloading
      find -name "*.tar*" -exec tar -xf {} \;

      pushd binutils-*/
        mkdir -vp build
      popd

      pushd glibc-*/
        mkdir -vp build

        # ensures 'ldconfig' and 'sln' utilites are installed into /usr/sbin
        echo "rootsbindir=/usr/sbin" > build/configparms

        patch -Np1 -i ../glibc-*-fhs-1.patch
      popd

      pushd gcc-*/
        mkdir -vp build

        case $(uname -m) in
          x86_64)
            sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
          ;;
        esac
      popd
    popd
}

export -f _logger_info _unload_build_packages
export BUSER BROOT BTARGET BVERSION MAKEFLAGS CONFIG_SITE
