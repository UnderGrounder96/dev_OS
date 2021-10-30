#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script kickstarts the dev_OS development
# ==============================================================================

set -euo pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."
LOG_FILE="$ROOT_DIR/logs/kickstart-$(date '+%F_%T').log"

source $ROOT_DIR/configs/common.sh

function deps_install(){
    env ROOT_DIR="$ROOT_DIR" bash $ROOT_DIR/build/deps.sh
}

function temp-tools_build(){
    cd $BROOT/source

    sudo -u $BUSER env -i ROOT_DIR="$ROOT_DIR"  \
      bash $ROOT_DIR/build/temp-tools.sh $ROOT_DIR/configs/common.sh
}

function build_OS(){
    cd $BROOT

    env ROOT_DIR="$ROOT_DIR"  \
      bash $ROOT_DIR/build/build.sh $ROOT_DIR/configs/common.sh
}

function main(){
    deps_install

    temp-tools_build

    build_OS

    # reboot

    exit 0
}

main 2>&1 | tee -a $LOG_FILE
