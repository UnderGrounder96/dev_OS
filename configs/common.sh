#!/usr/bin/env bash

# author		      @undergrounder96
# description     Helper file
# ==============================================================================

set -euo pipefail

# build variables
BUSER="byol"
BROOT="/build"
BTARGET="x86_64-BROOT-linux-gnu"
BVERSION="1.0.0"

# functions
function _logger_info(){
    echo -e "\n[$(date '+%d/%b/%Y %T')]: $*...\n"
}

export -f _logger_info
export BUSER BROOT BTARGET BVERSION
