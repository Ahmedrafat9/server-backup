#!/bin/bash

validate_backup_params() {
    if [ $# -ne 4 ]; then
        echo "Usage: $0 <source_dir> <backup_dir> <recipient> <days>"
        exit 1
    fi

    SRC_DIR="$1"
    BACKUP_DIR="$2"
    RECIPIENT="$3"
    DAYS="$4"

    if [ ! -d "$SRC_DIR" ]; then
        echo "Error: Source directory '$SRC_DIR' does not exist."
        exit 1
    fi

        if [ ! -d "$BACKUP_DIR" ]; then
            echo "Backup directory '$BACKUP_DIR' does not exist. Creating it now..."
            mkdir -p "$BACKUP_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create backup directory '$BACKUP_DIR'."
            exit 1
        fi
    fi


    if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
        echo "Error: Number of days must be a non-negative integer."
        exit 1
    fi
}

backup() {
    SRC_DIR="$1"
    BACKUP_DIR="$2"
    RECIPIENT="$3"
    DAYS="$4"

    DATE_STR=$(date +"%Y-%m-%d_%H-%M-%S")
    NEW_BACKUP_DIR="$BACKUP_DIR/$DATE_STR"
    mkdir -p "$NEW_BACKUP_DIR"

    echo "Starting backup at $DATE_STR"

    # Backup directories
    for dir in "$SRC_DIR"/*/; do
        [ -d "$dir" ] || continue
        DIR_NAME=$(basename "$dir")

        FILES=$(find "$dir" -type f -mtime -"$DAYS")
        if [ -z "$FILES" ]; then
            echo "No recent files in directory '$DIR_NAME' to backup."
            continue
        fi

        TAR_NAME="${DIR_NAME}_${DATE_STR}.tgz"
        TAR_PATH="$NEW_BACKUP_DIR/$TAR_NAME"

        echo "Archiving directory '$DIR_NAME'..."
        tar -czf "$TAR_PATH" -C "$SRC_DIR" "$DIR_NAME"
        if [ -f "$TAR_PATH" ]; then
            echo "Encrypting archive '$TAR_NAME' with recipient '$RECIPIENT'..."
            gpg --batch --yes --encrypt --recipient "$RECIPIENT" "$TAR_PATH"
            rm "$TAR_PATH"
        else
            echo "⚠️ Archive not created for $DIR_NAME, skipping encryption."
        fi
    done

    # Backup standalone files
    TEMP_TAR="$NEW_BACKUP_DIR/files_${DATE_STR}.tar"
    FIRST=1
    for file in "$SRC_DIR"/*; do
        [ -f "$file" ] || continue
        if ! find "$file" -mtime -"$DAYS" | grep -q .; then
            continue
        fi

        if [ $FIRST -eq 1 ]; then
            tar -cf "$TEMP_TAR" -C "$SRC_DIR" "$(basename "$file")"
            FIRST=0
        else
            tar -rf "$TEMP_TAR" -C "$SRC_DIR" "$(basename "$file")"
        fi
    done

    if [ -f "$TEMP_TAR" ]; then
        echo "Compressing and encrypting standalone files archive..."
        gzip "$TEMP_TAR"
        gpg --batch --yes --encrypt --recipient "$RECIPIENT" "${TEMP_TAR}.gz"
        rm -f "${TEMP_TAR}.gz"
    else
        echo "No standalone files to backup."
    fi

    echo "Copying backup to remote server..."
    scp -i ~/Downloads/blogkey.pem -r "$NEW_BACKUP_DIR" ubuntu@ec2-54-237-128-209.compute-1.amazonaws.com:/home/ubuntu/backup/
    aws s3 cp "$NEW_BACKUP_DIR" s3://ahmedrafat-bashtask/$DATE_STR/ --recursive
    rm -rf "$NEW_BACKUP_DIR"
    echo "Backup completed successfully."
}

validate_restore_params() {
    if [ $# -ne 3 ]; then
        echo "Usage: $0 <backup_dir> <restore_dir> <private_key>"
        exit 1
    fi

    BACKUP_DIR="$1"
    RESTORE_DIR="$2"
    PRIVATE_KEY="$3"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Error: Backup directory '$BACKUP_DIR' does not exist."
        exit 1
    fi

    if [ ! -d "$RESTORE_DIR" ]; then
        echo "Error: Restore directory '$RESTORE_DIR' does not exist."
        exit 1
    fi
}

restore() {
    BACKUP_DIR="$1"
    RESTORE_DIR="$2"
    PRIVATE_KEY="$3"

    TEMP_DIR="$RESTORE_DIR/temp_restore"
    mkdir -p "$TEMP_DIR"

    echo "Starting restore from '$BACKUP_DIR' into '$RESTORE_DIR'..."

    for file in "$BACKUP_DIR"/*.gpg; do
        BASENAME=$(basename "$file" .gpg)
        echo "Decrypting $BASENAME.gpg ..."
        gpg --batch --yes -o "$TEMP_DIR/$BASENAME" -d "$file"
    done

    for file in "$TEMP_DIR"/*; do
        if [[ "$file" == *.tgz ]]; then
            echo "Extracting $file ..."
            tar -xzf "$file" -C "$RESTORE_DIR"
        elif [[ "$file" == *.tar.gz ]]; then
            echo "Extracting compressed $file ..."
            gunzip "$file"
            tar_file="${file%.gz}"
            tar -xf "$tar_file" -C "$RESTORE_DIR"
            rm -f "$tar_file"
        elif [[ "$file" == *.tar ]]; then
            echo "Extracting tar $file ..."
            tar -xf "$file" -C "$RESTORE_DIR"
        else
            echo "Unknown archive format: $file"
        fi
        rm -f "$file"
    done

    rmdir "$TEMP_DIR"
    echo "Restore completed successfully."
}
