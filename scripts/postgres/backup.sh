#!/bin/sh
set -eu

mkdir -p /backups
while true; do
    timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
    target="/backups/${PGDATABASE}-${timestamp}.dump"
    pg_dump --format=custom --compress=9 --file="$target"
    pg_restore --list "$target" >/dev/null
    find /backups -type f -name "${PGDATABASE}-*.dump" -mtime "+${BACKUP_RETENTION_DAYS}" -delete
    sleep "$BACKUP_INTERVAL_SECONDS"
done
