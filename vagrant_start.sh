#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script boots the VM and trigger build/bin.sh
# ==============================================================================

set -euo pipefail

source config/common.sh

function vagrant_destroy(){
    _logger_info "WARNING: Destroying Virtual Machine"
    vagrant destroy -f
}

trap vagrant_destroy EXIT


function main(){
    [ -f Vagrantfile ] || {
      _logger_info "There is no Vagrantfile"; exit 1
    }

    export VAGRANT_EXPERIMENTAL="disks"

    _logger_info "Starting the vagrant machine"
    vagrant up

    _logger_info "Running build.sh"
    vagrant ssh -c "bash /vagrant/build/bin.sh"

    _logger_info "Aquiring build.log"
    vagrant scp ":/vagrant/logs/*.log*" logs/ # if scp below v0.5, see https://github.com/hashicorp/vagrant/issues/12504
}

vagrant_destroy
main
