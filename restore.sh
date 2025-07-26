#!/bin/bash

source ./backup_restore_lib.sh

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_dir> <restore_dir> <decryption_key>"
    exit 1
fi

validate_restore_params "$@"
restore "$@"
