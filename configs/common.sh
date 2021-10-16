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

function _unload_build_packages(){
    _logger_info "Unloading build packages"

    pushd $BROOT/source
      sudo -u $BUSER cp -fuv $ROOT_DIR/bin/* . # offline packages unloading
      sudo -u $BUSER find -name "*.tar*" -exec tar -xf {} \;

      pushd glibc-*/
        patch -Np1 -i ../glibc-*-fhs-1.patch
      popd
    popd
}

export -f _logger_info _unload_build_packages
export BUSER BROOT BTARGET BVERSION MAKEFLAGS CONFIG_SITE
