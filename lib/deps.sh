#!/usr/bin/env bash

# author		      @undergrounder96
# description     This script installs all dependencies
# ==============================================================================

set -euo pipefail

# groupinstall
sudo dnf group install -y "C Development Tools and Libraries"
sudo dnf group install -y "Development Tools"

# soloinstall
# sudo dnf install -y texinfo 
