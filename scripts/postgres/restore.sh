#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: RESTORE_CONFIRM=<database> restore.sh /backups/<file>.dump" >&2
    exit 2
fi
if [ "${RESTORE_CONFIRM:-}" != "$PGDATABASE" ]; then
    echo "Set RESTORE_CONFIRM=$PGDATABASE to acknowledge the destructive restore." >&2
    exit 2
fi

backup_file="$1"
test -f "$backup_file"
pg_restore --list "$backup_file" >/dev/null
pg_restore --clean --if-exists --no-owner --dbname="$PGDATABASE" "$backup_file"
