#!/usr/bin/env bash
# vim: ai ts=4 sts=4 et sw=4
#
#     This file is part of hleroy/backup-s3. backup-s3 periodically backs up
#     a postgres database and/or data folder(s) to Amazon S3.
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
	echo "[CRITICAL] List failed."
	awk 'NR>L-4 && NR<L+4 { printf "%-5d%3s%s\n",NR,(NR==L?">>>":""),$0 }' L=$1 $0
}
trap 'err $LINENO' ERR

# Check if S3 environment variable are set
if [[ -z $S3_ACCESS_KEY_ID || -z $S3_SECRET_ACCESS_KEY || -z $S3_BUCKET || -z $S3_REGION ]]; then
	echo "[WARNING] Missing S3 environment variable(s)."
	: ${S3_ACCESS_KEY_ID?"You need to set the S3_ACCESS_KEY_ID environment variable."}
	: ${S3_SECRET_ACCESS_KEY?"You need to set the S3_SECRET_ACCESS_KEY environment variable."}
	: ${S3_BUCKET?"You need to set the S3_BUCKET environment variable."}
	: ${S3_REGION?"You need to set the S3_REGION environment variable."}
	exit 1
fi

# Export environment vars needed for aws tools
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

echo "[INFO] Listing last 10 backups from $S3_BUCKET in $S3_REGION"
echo ""

# List postgres backups if DB_NAME is set
if [[ ! -z $DB_NAME ]]; then
	echo "=== PostgreSQL Database Backups ==="

	# List all postgres backups, sort by date (newest first), take last 10
	POSTGRES_BACKUPS=$(aws s3 ls s3://$S3_BUCKET/postgres/ | sort -r | head -n 10)

	if [[ -z "$POSTGRES_BACKUPS" ]]; then
		echo "  No database backups found."
	else
		{
			echo "  Timestamp               Size       Filename"
			echo "  ----------------------  ---------  --------------------------------------------------"
			echo "$POSTGRES_BACKUPS" | while read -r line; do
				# Parse the line: date time size filename
				DATE=$(echo $line | awk '{print $1}')
				TIME=$(echo $line | awk '{print $2}')
				SIZE=$(echo $line | awk '{print $3}')
				FILENAME=$(echo $line | awk '{print $4}')

				# Strip the .sql.gz extension to get the restore filename
				RESTORE_NAME=$(echo $FILENAME | sed 's/\.sql\.gz$//')

				printf "%s %s %s %s\n" "$DATE" "$TIME" "$SIZE" "$RESTORE_NAME"
			done
		} | column -t
	fi
	echo ""
fi

# List data backups if DATA_PATH is set
if [[ ! -z $DATA_PATH ]]; then
	echo "=== Data Backups ==="

	# List all data backups, sort by date (newest first), take last 10
	DATA_BACKUPS=$(aws s3 ls s3://$S3_BUCKET/data/ | sort -r | head -n 10)

	if [[ -z "$DATA_BACKUPS" ]]; then
		echo "  No data backups found."
	else
		{
			echo "  Timestamp               Size       Filename"
			echo "  ----------------------  ---------  --------------------------------------------------"
			echo "$DATA_BACKUPS" | while read -r line; do
				# Parse the line: date time size filename
				DATE=$(echo $line | awk '{print $1}')
				TIME=$(echo $line | awk '{print $2}')
				SIZE=$(echo $line | awk '{print $3}')
				FILENAME=$(echo $line | awk '{print $4}')

				# Strip the .tar extension to get the restore filename
				RESTORE_NAME=$(echo $FILENAME | sed 's/\.tar$//')

				printf "%s %s %s %s\n" "$DATE" "$TIME" "$SIZE" "$RESTORE_NAME"
			done
		} | column -t
	fi
	echo ""
fi

echo "[INFO] To restore a backup, run:"
echo "       docker-compose run --rm backup restore <FILENAME>"
