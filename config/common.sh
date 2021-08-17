#!/usr/bin/env bash

# author		      @undergrounder96
# description     Helper file
# ==============================================================================

set -euo pipefail

function _logger_info(){
    echo -e "\n[$(date '+%d/%b/%Y %T')]: $*...\n"
}

export -f _logger_info
