#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script installs all dependencies
# ==============================================================================

set -euo pipefail

function group_installs(){
    _logger_info "Performing groupinstalls"
    sudo dnf group install -y "C Development Tools and Libraries"
    sudo dnf group install -y "Development Tools"
}

function solo_installs(){
    _logger_info "Performing soloinstalls"
    # sudo dnf install -y texinfo
}

function check_yaac(){
    _logger_info "Checking yaac x bison relation"
    rpm -qf `which yacc`

    sudo dnf remove -y byacc
    sudo dnf reinstall -y bison

    sudo ln -s `which bison` /bin/yacc
}

function main(){
    group_installs
    solo_installs

    check_yaac

    exit 0
}

main