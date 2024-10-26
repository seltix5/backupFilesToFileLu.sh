#!/bin/bash

######################################################
#  Script by : https://github.com/seltix5/backupFilesToFileLu.sh
#  Date: 26 Oct 2024
#  Permissions required: 744 ( chmod +x backupFilesToFileLu.sh )
#  Cron example: 0 0 * * *     /home/account_name/backupFilesToFileLu.sh
#  FileLu API doc: https://filelu.com/pages/api/
#  FileLu API key: https://filelu.com/account/
######################################################

# Configuration
DAYS_TO_KEEP=3

FOLDER_TO_BACKUP="/home/account_name/public_html"

BACKUP_FOLDER="/home/account_name/backups_tmp" # Folder where backups will be stored, you may use "/tmp"
BACKUP_DELETE=true # Delete local backup after upload?

BACKUP_FILENAMEPREFIX="backup_" # Common file name prefix for all backup files
BACKUP_FILENAME="$(date +%Y%m%d_%H%M%S)"

FILELU_API_KEY="filelu_api_key"
FILELU_FOLDER_NAME="backups" # Folder name in root of FileLu


# Step 1: Create backup
mkdir -p "$BACKUP_FOLDER" # Create backup folder if it doesn't exist

FULL_BACKUP_FILENAME="${BACKUP_FILENAMEPREFIX}${BACKUP_FILENAME}.tar.gz"

tar -czvf "$BACKUP_FOLDER/$FULL_BACKUP_FILENAME" -C "$FOLDER_TO_BACKUP" . # Create a tar.gz archive of the folder to backup


# Step 2: Select a server that is ready to accept an upload
UPLOAD_SERVER_RESPONSE=$(curl -s "https://filelu.com/api/upload/server?key=$FILELU_API_KEY")

# Extract sess_id and upload URL using grep
SESS_ID=$(echo "$UPLOAD_SERVER_RESPONSE" | grep -oP '"sess_id":"\K[^"]+')
UPLOAD_URL=$(echo "$UPLOAD_SERVER_RESPONSE" | grep -oP '"result":"\K[^"]+')

echo "Upload session ID: $SESS_ID"
echo "Upload URL: $UPLOAD_URL"

# Check if the session ID and upload URL were successfully retrieved
if [[ -z "$SESS_ID" || -z "$UPLOAD_URL" ]]; then
    echo "Error: Failed to obtain upload server. Response: $UPLOAD_SERVER_RESPONSE"
    exit 1
fi


# Step 3: Upload the file to the selected server
UPLOAD_RESPONSE=$(curl -s -F "sess_id=$SESS_ID" -F "utype=prem" -F "file_0=@$BACKUP_FOLDER/$FULL_BACKUP_FILENAME" "$UPLOAD_URL")

#echo "Upload Response: $UPLOAD_RESPONSE"

# Check if the upload was successful using the file status
FILE_STATUS=$(echo "$UPLOAD_RESPONSE" | grep -oP '"file_status":"\K[^"]+')

if [[ "$FILE_STATUS" != "OK" ]]; then
    echo "Error: File upload failed. Response: $UPLOAD_RESPONSE"
    exit 1
fi

FILE_CODE=$(echo "$UPLOAD_RESPONSE" | grep -oP '"file_code":"\K[^"]+')
FILE_URL="https://filelu.com/$FILE_CODE"

# Check if the file was uploaded successfully
if [[ -z "$FILE_CODE" ]]; then
    echo "Error: File upload failed. Response: $UPLOAD_RESPONSE"
    exit 1
fi

printf "Uploaded successfully:\n FILE: $FULL_BACKUP_FILENAME\n URL: $FILE_URL\n"


# Step 4: Get the folder ID for the destination folder on FileLu
FOLDER_LIST_RESPONSE=$(curl -s "https://filelu.com/api/folder/list?key=$FILELU_API_KEY")
FOLDER_JSON=$(echo "$FOLDER_LIST_RESPONSE" | grep -oP '\{[^{}]*"name":"'"$FILELU_FOLDER_NAME"'"[^{}]*\}' | head -1)
FOLDER_ID=$(echo "$FOLDER_JSON" | grep -oP '"fld_id":\K[0-9]+')

#echo "Folders list Response: $FOLDER_LIST_RESPONSE"
#echo "Folder json: $FOLDER_JSON"
echo "Remote folder ID: $FOLDER_ID"

# If the folder doesn't exist, create it
if [[ -z "$FOLDER_ID" ]]; then
    CREATE_FOLDER_RESPONSE=$(curl -s "https://filelu.com/api/folder/create?parent_id=0&name=$FILELU_FOLDER_NAME&key=$FILELU_API_KEY")
	FOLDER_ID=$(echo "$CREATE_FOLDER_RESPONSE" | grep -oP '"fld_id":"\K[0-9]+')
	
	#echo "Folder create Response: $CREATE_FOLDER_RESPONSE"
    echo "Remote folder created with ID: $FOLDER_ID"
fi


# Step 5: Move the uploaded file to the specified folder
MOVE_RESPONSE=$(curl -s "https://filelu.com/api/file/set_folder?file_code=$FILE_CODE&fld_id=$FOLDER_ID&key=$FILELU_API_KEY")

# echo "File move Response: $MOVE_RESPONSE"
echo "Uploaded file moved to: {$FOLDER_ID} $FILELU_FOLDER_NAME/$FULL_BACKUP_FILENAME"


# Step 6: Auto-delete old backups on FileLu
FILES_LIST_RESPONSE=$(curl -s "https://filelu.com/api/file/list?key=$FILELU_API_KEY")

#echo "Files list Response: $FILES_LIST_RESPONSE"

# Iterate through files and delete those older than DAYS_TO_KEEP
FILELU_FILES_COUNT=0
echo "$FILES_LIST_RESPONSE" | grep -oP '"file_code":"\K[^"]+' | while read -r REMOTE_FILE_CODE; do
	CURRENT_DATE=$(date +%s)
	
    FILE_UPLOAD_JSON=$(echo "$FILES_LIST_RESPONSE" | grep -oP '\{[^{}]*"file_code":"'"$REMOTE_FILE_CODE"'"[^{}]*\}' | head -1)
	FILE_UPLOAD_NAME=$(echo "$FILE_UPLOAD_JSON" | grep -oP '"name":"\K[^"]+')
	FILE_UPLOAD_DATE=$(echo "$FILE_UPLOAD_JSON" | grep -oP '"uploaded":"\K[^"]+')
    FILE_UPLOAD_TIMESTAMP=$(date -d "$FILE_UPLOAD_DATE" +%s)
    FILE_AGE_DAYS=$(( (CURRENT_DATE - FILE_UPLOAD_TIMESTAMP) / 86400 ))
	
    if [[ "$FILE_AGE_DAYS" -gt "$DAYS_TO_KEEP" ]]; then
        DELETE_RESPONSE=$(curl -s "https://filelu.com/api/file/remove?file_code=$REMOTE_FILE_CODE&remove=1&key=$FILELU_API_KEY")
		
		#echo "Deleted file Response: $DELETE_RESPONSE" # {"server_time":"2024-10-26 18:08:28","status":200,"msg":"OK"}
		
		FILE_STATUS=$(echo "$DELETE_RESPONSE" | grep -oP '"file_status":"\K[^"]+')

		if [[ "$FILE_STATUS" != "OK" ]]; then
			echo "Error: File delete failed. Response: $DELETE_RESPONSE"
			exit 1
		fi
		
		echo "Deleted remote file: {$REMOTE_FILE_CODE} $FILE_UPLOAD_NAME, date: $FILE_UPLOAD_DATE, days: $FILE_AGE_DAYS/$DAYS_TO_KEEP days"
    else
		FILELU_FILES_COUNT=$((FILELU_FILES_COUNT + 1))
		
		echo "Remote file info $FILELU_FILES_COUNT: {$REMOTE_FILE_CODE} $FILE_UPLOAD_NAME, date: $FILE_UPLOAD_DATE, days: $FILE_AGE_DAYS/$DAYS_TO_KEEP days"		
    fi
done

echo "Remote auto-clean complete (max days: $DAYS_TO_KEEP)."


# Step 7: Auto-delete old local backups
if [ "$BACKUP_DELETE" = true ]; then
	rm "$BACKUP_FOLDER/$FULL_BACKUP_FILENAME"
	
	echo "Local temp backup deleted: $BACKUP_FOLDER/$FULL_BACKUP_FILENAME"
else
    find "$BACKUP_FOLDER" -type f -name "$BACKUP_FILENAMEPREFIX*.tar.gz" -mtime +$DAYS_TO_KEEP -exec rm {} \;
	
	echo "Local auto-clean complete (max days: $DAYS_TO_KEEP)."
fi


# Complete
echo "Backup process completed."
