#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script kickstarts the dev_OS development
# ==============================================================================
exit 1;
set -euo pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."
LOG_FILE="$ROOT_DIR/logs/bin-$(date '+%F_%T').log"

source $ROOT_DIR/configs/common.sh

function deps_install(){
    env ROOT_DIR="$ROOT_DIR" bash $ROOT_DIR/build/deps.sh
}

function setup_build(){
    cd $BROOT/source/build

    sudo -u $BUSER env ROOT_DIR="$ROOT_DIR"  \
      bash $ROOT_DIR/build/setup.sh $ROOT_DIR/configs/common.sh
}

function build_OS(){
    env ROOT_DIR="$ROOT_DIR"  \
      bash $ROOT_DIR/build/build.sh $ROOT_DIR/configs/common.sh
}

function main(){
    deps_install

    setup_build

    build_OS

    exit 0
}

main 2>&1 | tee -a $LOG_FILE
