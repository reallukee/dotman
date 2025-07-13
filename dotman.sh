#!/bin/bash

#
# --------------------
# DotMan
# Linux/macOS Launcher
# --------------------
#
# A modular, open-source and multiplatform manager for .NET
#
# https://github.com/reallukee/dotman
#
# By Luca Pollicino (https://github.com/reallukee)
#
# dotman.sh
#
# Licensed under the MIT license!
#

if ! command -v pwsh >/dev/null 2>&1; then
    echo "PowerShell is required!"

    exit 1
fi

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

MODULE="$SCRIPT_DIR/dotman.ps1"

if [[ -f "$MODULE" ]]; then
    pwsh "$MODULE" "$@"
else
    echo "Module is missing!"

    exit 1
fi
