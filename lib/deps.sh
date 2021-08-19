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

function create_user(){
    _logger_info "Handling build user creation"
    export BUILD_USER="byol"

    sudo useradd --create-home --skel /dev/null $BUILD_USER
    sudo usermod $BUILD_USER -aG wheel

    echo 'exec env -i HOME=$HOME TERM=$TERM PS1="[\u@\h \W]\$\n" /bin/bash' | sudo -u $BUILD_USER tee /home/$BUILD_USER/.bash_profile

    sudo -u $BUILD_USER tee /home/$BUILD_USER/.bashrc <<EOF 1>/dev/null
        set +h # disables history command path
        umask 022 # sets file creation permission
        export LC_ALL=POSIX
        export PATH=/tools/bin:/bin:/usr/bin
EOF
}

function main(){
    group_installs
    solo_installs

    check_yaac

    create_user

    exit 0
}

main