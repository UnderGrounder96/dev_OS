#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script kickstarts the dev_OS development
# ==============================================================================

set -euo pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."
LOG_FILE="$ROOT_DIR/logs/build-$(date '+%F_%T').log"

export ROOT_DIR LOG_FILE

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
    bash $ROOT_DIR/lib/deps.sh
}

function main(){
    prepare_tmp_dir

    deps_install

    clean_tmp_dir
    exit 0
}


main 2>&1 | tee -a $LOG_FILE