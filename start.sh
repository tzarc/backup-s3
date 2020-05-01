#!/usr/bin/env bash
# vim: ai ts=4 sts=4 et sw=4
#
#     This file is part of hleroy/backup-s3. backup-s3 periodically backs up
#     a database (postgres or mysql) and/or data folder(s) to Amazon S3.
#     Copyright © 2012 Hervé Le Roy
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <https://www.gnu.org/licenses/>.


# Interrupt the script on error (set -e) and print an error message (trap)
set -eo pipefail
err() {
    echo "[CRITICAL] Backup container didn't start properly."
    awk 'NR>L-4 && NR<L+4 { printf "%-5d%3s%s\n",NR,(NR==L?">>>":""),$0 }' L=$1 $0
}
trap 'err $LINENO' ERR

# Check if environment variable are set
: ${S3_ACCESS_KEY_ID?"You need to set the S3_ACCESS_KEY_ID environment variable."}
: ${S3_SECRET_ACCESS_KEY?"You need to set the S3_SECRET_ACCESS_KEY environment variable."}
: ${S3_BUCKET?"You need to set the S3_BUCKET environment variable."}
: ${S3_REGION?"You need to set the S3_REGION environment variable."}

# We need at least a path or a database to backup
if [[ -z $DATA_PATH && -z $DB_ENGINE ]]; then
  echo "[WARNING] Nothing to backup. Exiting."
  exit 1
fi

# Check that database host, name and credentials are set
if [[ $DB_ENGINE == "postgres" || $DB_ENGINE == "mysql" ]]; then
  : ${DB_NAME?"You need to set the DB_NAME environment variable."}
  : ${DB_HOST?"You need to set the DB_HOST environment variable."}
  : ${DB_USER?"You need to set the DB_USER environment variable."}
  : ${DB_PASS?"You need to set the DB_PASS environment variable."}
fi

CRON_SCHEDULE=${CRON_SCHEDULE:-0 0 * * *}

if [[ "$1" == 'no-cron' ]]; then

    # Run backup now
    exec /backup.sh

elif [[ "$1" == 'restore' ]]; then

    # Restore backup
    exec /restore.sh $2

else

    # Schedule backup with cron

    # Create logfile
    LOGFIFO='/var/log/cron.fifo'
    if [[ ! -e "$LOGFIFO" ]]; then
        mkfifo "$LOGFIFO"
    fi

    # Save env vars
    printenv | sed 's/^\(.*\)\=\(.*\)$/export \1\="\2"/g' > env.sh

    # Setup crontab
    echo -e "SHELL=/bin/bash\nBASH_ENV=/env.sh\n$CRON_SCHEDULE /backup.sh > $LOGFIFO 2>&1" | crontab -
    crontab -l
    cron

    # Listen on the logs for changes
    tail -f "$LOGFIFO"
fi
