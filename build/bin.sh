#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script kickstarts the dev_OS development
# ==============================================================================

set -euo pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."
LOG_FILE="$ROOT_DIR/logs/build-$(date '+%F_%T').log"

export ROOT_DIR

source $ROOT_DIR/config/common.sh

function prepare_tmp_dir(){
    _logger_info "Preparing tmp dir"
    export TMP_DIR=$(mktemp -d)
    pushd "$TMP_DIR"
}

function clean_tmp_dir(){
    _logger_info "Cleaning tmp dir"
    popd
    # rm -rf "$TMP_DIR"
}


function deps_install(){
    bash $ROOT_DIR/build/deps.sh
}

function setup_build(){
    cd $BROOT/source/build
    sudo -u $BUSER env ROOT_DIR="$ROOT_DIR" bash $ROOT_DIR/build/setup.sh $ROOT_DIR/config/common.sh
}

function main(){
    prepare_tmp_dir

    deps_install

    setup_build

    clean_tmp_dir
    exit 0
}


main 2>&1 | tee -a $LOG_FILE
