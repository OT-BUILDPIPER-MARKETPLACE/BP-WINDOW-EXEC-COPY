#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/git-functions.sh


if [ -z "$FERNET_KEY" ]; then
  logErrorMessage "FERNET_KEY is not set"
  exit 1
fi

TARGET_USERNAME=$(python3 - <<PY
import os, json
from cryptography.fernet import Fernet

data = json.loads(os.environ['CREDENTIAL_MANAGEMENT'])
fernet = Fernet(os.environ['FERNET_KEY'].encode())

val = data["integration_1"].get("CREDENTIAL_USERNAME")

if val:
    print(fernet.decrypt(val.encode()).decode())
else:
    print("")
PY
)

TARGET_PASSWORD=$(python3 - <<PY
import os, json
from cryptography.fernet import Fernet

data = json.loads(os.environ['CREDENTIAL_MANAGEMENT'])
fernet = Fernet(os.environ['FERNET_KEY'].encode())

val = data["integration_1"].get("CREDENTIAL_PASSWORD")

if val:
    print(fernet.decrypt(val.encode()).decode())
else:
    print("")
PY
)

TARGET_TOKEN=$(python3 - <<PY
import os, json
from cryptography.fernet import Fernet

data = json.loads(os.environ['CREDENTIAL_MANAGEMENT'])
fernet = Fernet(os.environ['FERNET_KEY'].encode())

val = data["integration_1"].get("CREDENTIAL_ACCESS_TOKEN_OR_KEY")

if val:
    print(fernet.decrypt(val.encode()).decode())
else:
    print("")
PY
)

TARGET_KEY_VALUE=$(python3 - <<PY
import os, json

data = json.loads(os.environ['CREDENTIAL_MANAGEMENT'])

val = data["integration_1"].get("CREDENTIAL_KEY_VALUE_PAIR")

print("" if val is None else val)
PY
)

export TARGET_USERNAME
export TARGET_PASSWORD
export TARGET_TOKEN
export TARGET_KEY_VALUE


if [ "$DEBUG" = true ]; then
  set -x
fi

TARGET_USERNAME="$TARGET_USERNAME"
TARGET_PASSWORD="$TARGET_PASSWORD"
TARGET_IP="$TARGET_IP"

if [ -z "$TARGET_USERNAME" ] || [ -z "$TARGET_IP" ] || [ -z "$TARGET_PASSWORD" ]; then
  logErrorMessage "Target Server credentials are missing"
  exit 1
fi

SOURCE_PATH="${SOURCE_PATH}"
FOLDER_NAME="${FOLDER_NAME}"
DEST_PATH="${DEST_PATH}"
BACKUP_DIR="${BACKUP_DIR}"
RETENTION_COUNT="${RETENTION_COUNT}"


ESCAPED_SOURCE=$(printf '%s\\%s' "$SOURCE_PATH" "$FOLDER_NAME" | sed 's#\\#\\\\#g')
ESCAPED_DEST=$(printf '%s' "$DEST_PATH" | sed 's#\\#\\\\#g')
ESCAPED_BACKUP=$(printf '%s' "$BACKUP_DIR" | sed 's#\\#\\\\#g')

logInfoMessage "Source: $ESCAPED_SOURCE"

if [ -n "$ESCAPED_SOURCE" ] && [ -n "$ESCAPED_DEST" ] && [ -n "$ESCAPED_BACKUP" ]; then
  logInfoMessage "Source: $ESCAPED_SOURCE"
  logInfoMessage "Destination: $ESCAPED_DEST"
  add_event "FETCHING SOURCE PATH" "Successful" "Source path retrieved successfully" "Source: $ESCAPED_SOURCE"
  add_event "FETCHING DESTINATION PATH" "Successful" "Destination path retrieved successfully" "Destination: $ESCAPED_DEST"
  add_event "FETCHING BACKUP PATH" "Successful" "Backup path retrieved successfully" "Backup: $ESCAPED_BACKUP"
else
  logErrorMessage "Source or Destination path is empty"
   add_event "FETCHING SOURCE PATH" "Failed" "Source or Destination path is missing" "Source: $ESCAPED_SOURCE, Destination: $ESCAPED_DEST, Backup: $ESCAPED_BACKUP"
  exit 1
fi



SOURCE_PATH_ESCAPED=$(printf '%s' "$SOURCE_PATH" | sed 's#\\#\\\\#g')
DEST_PATH_ESCAPED=$(printf '%s' "$DEST_PATH" | sed 's#\\#\\\\#g')
BACKUP_DIR_ESCAPED=$(printf '%s' "$BACKUP_DIR" | sed 's#\\#\\\\#g')


sleep "${SLEEP_DURATION}"


if [ "$BACKUP_EXISTING" = "true" ]; then
#   sshpass -p "$TARGET_PASSWORD" ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_IP" \
#   "powershell -Command \"\$dt=Get-Date -Format 'yyyyMMdd_HHmmss'; New-Item -ItemType Directory -Path '$BACKUP_DIR_ESCAPED' -Force | Out-Null; \$tarFile='$BACKUP_DIR_ESCAPED\\\\$FOLDER_NAME'+'_'+\$dt+'.tar'; Write-Host 'Creating TAR:' \$tarFile; tar -cvf \$tarFile -C '$SOURCE_PATH_ESCAPED' '$FOLDER_NAME'; Write-Host '===== DONE ====='\""

add_event "RETENTION COUNT" "Successful" "Retention count for backups retrieved successfully" "Retention Count: $RETENTION_COUNT"

sshpass -p "$TARGET_PASSWORD" ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_IP" \
"powershell -NoProfile -ExecutionPolicy Bypass -Command \"\$dt=Get-Date -Format 'yyyyMMdd_HHmmss'; New-Item -ItemType Directory -Path '$BACKUP_DIR_ESCAPED' -Force | Out-Null; \$tarFile='$BACKUP_DIR_ESCAPED\\\\$FOLDER_NAME'+'_'+\$dt+'.tar'; Write-Host ('Creating TAR: ' + \$tarFile); tar -cvf \$tarFile -C '$SOURCE_PATH_ESCAPED' '$FOLDER_NAME'; Write-Host ('Applying retention (keep latest $RETENTION_COUNT files)...'); \$files=Get-ChildItem -Path '$BACKUP_DIR_ESCAPED' -Filter '*.tar' | Sort-Object LastWriteTime -Descending; Write-Host ('Total files: ' + \$files.Count); if (\$files.Count -gt $RETENTION_COUNT) { \$files | Select-Object -Skip $RETENTION_COUNT | ForEach-Object { Write-Host ('Deleting: ' + \$_.FullName); Remove-Item -LiteralPath \$_.FullName -Force } } else { Write-Host 'No old backups to delete' }; Write-Host '===== DONE ====='\""

  logInfoMessage "Backup completed at $ESCAPED_BACKUP"
  add_event "ARTIFACT BACKUP PATH" "Successful" "Backup of existing codebase completed successfully" "Backup Location: $ESCAPED_BACKUP"
else
  logWarningMessage "Skipping backup"
  add_event "ARTIFACT BACKUP PATH" "Warning" "Backup of existing codebase skipped as BACKUP_EXISTING is not set to true" "Backup Location: $ESCAPED_BACKUP"
fi

logInfoMessage "Starting robocopy from [$ESCAPED_SOURCE] to [$ESCAPED_DEST]"
add_event "ARTIFACT COPY" "Successful" "Code deployment started using robocopy" "Source: $ESCAPED_SOURCE, Destination: $ESCAPED_DEST"

sshpass -p "$TARGET_PASSWORD" ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_IP" \
"robocopy \"$SOURCE_PATH_ESCAPED\\$FOLDER_NAME\" \"$DEST_PATH_ESCAPED\" /E /COPYALL /R:1 /W:1"

EXIT_CODE=$?

if [ $EXIT_CODE -le 7 ]; then
    TASK_STATUS=0
add_event "ARTIFACT DEPLOYMENT" "Successful" "Code deployed successfully to target path using robocopy" "Source: $ESCAPED_SOURCE, Destination: $ESCAPED_DEST"
else
    TASK_STATUS=1
    logErrorMessage "Robocopy failed with exit code $EXIT_CODE"
    add_event "ARTIFACT DEPLOYMENT" "Failed" "Code deployment failed during robocopy execution" "Source: $ESCAPED_SOURCE, Destination: $ESCAPED_DEST"
fi
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}

