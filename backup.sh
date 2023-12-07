#!/bin/bash

# Variables for date components
DAY=$(date +"%d")
MONTH=$(date +"%m")
YEAR=$(date +"%Y")
TIMESTAMP=$(date +"%s")

# File name format: backup_DAY_MONTH_YEAR_TIMESTAMP.sql
FILENAME="backup_${DAY}_${MONTH}_${YEAR}_${TIMESTAMP}.sql"

# PostgreSQL credentials and database details
PG_USER="postgres"
PG_DB="nsapoold07"

# Export command (Update the path to pg_dump if necessary)
pg_dump -U $PG_USER -t user $PG_DB > $FILENAME

# Optional: Print the name of the backup file
echo "Backup created: $FILENAME"
