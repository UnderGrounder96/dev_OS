#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script boots the VM and trigger build/bin.sh
# ==============================================================================

set -euo pipefail

EXIT_BUILD_STATUS=0

source configs/common.sh

function vagrant_destroy(){
    _logger_info "WARNING: Destroying Virtual Machine"
    vagrant destroy -f
}

# trap vagrant_destroy EXIT


function main(){
    [ -f Vagrantfile ] || {
      _logger_info "There is no Vagrantfile"; exit 1
    }

    export VAGRANT_EXPERIMENTAL="disks"

    _logger_info "Starting the vagrant machine"
    vagrant up

    _logger_info "Running build.sh"
    vagrant ssh -c "sudo bash /vagrant/build/kickstart.sh" || {
        EXIT_BUILD_STATUS=$?
        _logger_info "ERROR: Build failed, please analyze the logs"
    }

    _logger_info "Acquiring build logs"
    vagrant scp ":/vagrant/logs/*.log*" logs/ # if scp below v0.5, see https://github.com/hashicorp/vagrant/issues/12504

    _logger_info "WARNING: Backing up build toolchain"
    vagrant scp ":/vagrant/backup*.tar*" backup/ || {
        _logger_info "ERROR: Build toolchain was not backed up"
    }

    exit $EXIT_BUILD_STATUS
}
rm -rf logs/*
vagrant_destroy
main
