#!/bin/bash

source ./backup_restore_lib.sh

if [ $# -eq 0 ]; then
    echo "Usage: $0 <source_dir> <backup_dir> <encryption_key> <days>"
    exit 1
fi

validate_backup_params "$@"
backup "$@"
