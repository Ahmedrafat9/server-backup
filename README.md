# server-backup
# Backup & Restore Tool

A bash tool to securely backup local files, upload them to EC2 & S3, and restore them when needed.

---

## 📦 Backup

Run:
```bash
./backup.sh <source_dir> <Dest_dir> <Public-key> <days> 
```
Example
```bash
./backup.sh ~/Desktop/bash-task/test-dir ~/Desktop/bash-task/local-ba4ckups "testkey" 7
```

## Restore
Install copy from remote server or s3 bucket
Example
```bash
aws s3 cp s3://ahmedrafat-bashtask/2025-07-26_13-15-49/ ./restore-backup/ --recursive
them
```
Example
```bash
./restore.sh ./restore-backup ./restore-dir/ "testkey"
```
