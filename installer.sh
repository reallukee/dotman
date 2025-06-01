#!/bin/bash

if [[ $(uname) == "Darwin" ]]; then
    DOTMAN_PATH="/usr/local/share/dotman"
else
    DOTMAN_PATH="/usr/share/dotman"
fi

if [[ $# -eq 1 ]]; then
    if [[ "$1" == "system" ]]; then
        if [[ $EUID -ne 0 ]]; then
            exit 1
        fi
    fi

    if [[ "$1" == "local" ]]; then
        DOTMAN_PATH="$HOME/.dotman"

        if [[ $EUID -eq 0 ]]; then
            exit 1
        fi
    fi
fi

if [[ $# -eq 2 ]]; then
    if [[ "$1" == "local" ]]; then
        DOTMAN_PATH="$2"
    fi
fi

if [[ ! -d "$DOTMAN_PATH" ]]; then
    mkdir -p "$DOTMAN_PATH"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cp -r "$SCRIPT_DIR"/* "$DOTMAN_PATH"

exit 0
