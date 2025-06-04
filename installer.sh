#!/bin/bash

#
# --------------------
# DotMan Installer
# Linux/macOS Launcher
# --------------------
#
# A modular, open-source and multiplatform manager for .NET
#
# https://github.com/reallukee/dotman
#
# By Luca Pollicino (https://github.com/reallukee)
#
# installer.sh
#
# Licensed under the MIT license!
#

if ! command -v pwsh >/dev/null 2>&1; then
    echo "PowerShell is required!"

    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

module="$SCRIPT_DIR/installer.ps1"

if [[ -f "$module" ]]; then
    pwsh "$module" "$@"
else
    echo "Module is missing!"

    exit 1
fi
