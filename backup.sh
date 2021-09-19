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
    echo "[CRITICAL] Backup failed."
    awk 'NR>L-4 && NR<L+4 { printf "%-5d%3s%s\n",NR,(NR==L?">>>":""),$0 }' L=$1 $0
}
trap 'err $LINENO' ERR

# We need at least a path or a database to backup
if [[ -z $DATA_PATH && -z $DB_ENGINE ]]; then
    echo "[WARNING] Nothing to backup."
    exit 1
fi

# Check if S3 environment variable are set
if [[ -z $S3_ACCESS_KEY_ID || -z $S3_SECRET_ACCESS_KEY  || -z $S3_BUCKET || -z $S3_REGION ]]; then
    echo "[WARNING] Missing S3 environment variable(s)."
    : ${S3_ACCESS_KEY_ID?"You need to set the S3_ACCESS_KEY_ID environment variable."}
    : ${S3_SECRET_ACCESS_KEY?"You need to set the S3_SECRET_ACCESS_KEY environment variable."}
    : ${S3_BUCKET?"You need to set the S3_BUCKET environment variable."}
    : ${S3_REGION?"You need to set the S3_REGION environment variable."}
    exit 1
fi

# Check if database host, name and credentials are set
if [[ $DB_ENGINE == "postgres" || $DB_ENGINE == "mysql" ]]; then
    if [[ -z $DB_NAME || -z $DB_HOST  || -z $DB_USER || -z $DB_PASS ]]; then
        echo "[WARNING] Missing database environment variable(s)."
        : ${DB_NAME?"You need to set the DB_NAME environment variable."}
        : ${DB_HOST?"You need to set the DB_HOST environment variable."}
        : ${DB_USER?"You need to set the DB_USER environment variable."}
        : ${DB_PASS?"You need to set the DB_PASS environment variable."}
        exit 1
    fi
fi

# Export environment vars needed for aws tools
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

# Format backup date
BACKUP_DATE=`date +"%Y-%m-%dT%H:%M:%SZ"`

# Generate random string for uniqueness purposes and so that you can limit the AWS user
# to only be able to put and get (not list) and thus the random string makes it so that,
# were the machine compromised, that AWS account couldn't overwrite old backup files
RAND_STR=$(cat /proc/sys/kernel/random/uuid)

# Dump database
if [[ $DB_ENGINE == "postgres" || $DB_ENGINE == "mysql" ]]; then

  echo "[INFO] Creating dump of ${DB_NAME} database"

  if [ $DB_ENGINE == "postgres" ]; then

      # Create postgres backup
      DB_PORT=${DB_PORT:-5432}
      export PGPASSWORD=$DB_PASS
      POSTGRES_HOST_OPTS="-h $DB_HOST -p $DB_PORT -U $DB_USER"
      pg_dump -Fc $POSTGRES_HOST_OPTS $DB_NAME | gzip > dump.sql.gz

  elif [ $DB_ENGINE == "mysql" ]; then

      # Create mysql backup
      DB_PORT=${DB_PORT:-3306}
      MYSQL_HOST_OPTS="--host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASS"
      mysqldump --opt --add-drop-database --no-tablespaces $MYSQL_HOST_OPTS $DB_NAME | gzip > dump.sql.gz

  fi

# Upload database backup to Amazon S3
echo "[INFO] Uploading database backup to $S3_BUCKET"
cat dump.sql.gz | aws s3 cp - s3://$S3_BUCKET/$DB_ENGINE/$BACKUP_DATE.$RAND_STR.sql.gz || exit 2

fi

# Create data backup
if [[ ! -z $DATA_PATH ]]; then

  # Data path can contain multiple paths separated by colons
  IFS=: read -r -a data_path_array <<<"$DATA_PATH"

  FILE='data.tar'
  # Remove file if it exists
  if [ -f $FILE ] ; then
      rm $FILE
  fi

  echo "[INFO] Creating tar archive"
  for dir in "${data_path_array[@]}"
  do
     echo "[INFO] Adding $dir"
     # tar sometime fails with the error message "file changed as we read it" and it exits with an error code 1
     # the purpose of the code after the tar command is to ignore code 1 and return all other codes
     # Credit: https://stackoverflow.com/questions/20318852/tar-file-changed-as-we-read-it
     tar rf $FILE --warning=no-file-changed --absolute-names "$dir" || ( export ret=$?; [[ $ret -eq 1 ]] || exit "$ret" )
  done

  # Upload data backup to Amazon S3
  echo "[INFO] Uploading data backup to $S3_BUCKET"
  cat $FILE | aws s3 cp - s3://$S3_BUCKET/data/$BACKUP_DATE.$RAND_STR.tar || exit 2

fi

echo "[INFO] Backup uploaded successfully to Amazon S3"
