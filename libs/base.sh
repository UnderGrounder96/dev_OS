#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script builds the base dev_OS
# ==============================================================================

set -euo pipefail

COMMON="${1}"

source $COMMON
unset BTARGET

function creating_os_dirs() {
    _logger_info "Creating OS dirs"

    mkdir -vp /{{,s}bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
    mkdir -vp /{media/{floppy,cdrom},srv}

    mkdir -vp /usr/libexec
    mkdir -vp /usr/{,local/}{{,s}bin,include,lib,src}
    mkdir -vp /usr/{,local/}share/{color,dict,doc,info,locale,misc,terminfo,zoneinfo,man/man{1..8}}

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

function main(){
    _logger_info "Executing lib/base.sh"

    creating_os_dirs

    exit 0
}

main
