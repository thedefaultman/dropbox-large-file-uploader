#!/bin/bash

set -e

# Check for required inputs
if [[ -z "$INPUT_APP_KEY" || -z "$INPUT_APP_SECRET" || -z "$INPUT_REFRESH_TOKEN" || -z "$INPUT_FILE_PATH" || -z "$INPUT_DROPBOX_PATH" ]]; then
  echo "Required inputs are missing."
  exit 1
fi

# Fetch a new access token using the refresh token
ACCESS_TOKEN=$(curl -s -X POST https://api.dropbox.com/oauth2/token \
  -u "$INPUT_APP_KEY:$INPUT_APP_SECRET" \
  -d grant_type=refresh_token \
  -d refresh_token=$INPUT_REFRESH_TOKEN | jq -r '.access_token')

# Check if access token was obtained
if [ -z "$ACCESS_TOKEN" ]; then
  echo "Failed to obtain access token."
  exit 1
fi

# File to upload
FILE_SIZE=$(stat -c%s "$INPUT_FILE_PATH")
CHUNK_SIZE=157286400  # 150 MB

# Start the upload session
SESSION_ID=$(curl -s -X POST https://content.dropboxapi.com/2/files/upload_session/start \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "Dropbox-API-Arg: {\"close\": false}" \
  --header "Content-Type: application/octet-stream" \
  --data-binary @<(head -c $CHUNK_SIZE "$INPUT_FILE_PATH") | jq -r '.session_id')

if [ -z "$SESSION_ID" ]; then
  echo "Failed to start upload session."
  exit 1
fi


# Upload remaining chunks
OFFSET=$CHUNK_SIZE
while [ $OFFSET -lt $FILE_SIZE ]; do
  curl -s -X POST https://content.dropboxapi.com/2/files/upload_session/append_v2 \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Dropbox-API-Arg: {\"cursor\": {\"session_id\": \"$SESSION_ID\", \"offset\": $OFFSET}, \"close\": false}" \
    --header "Content-Type: application/octet-stream" \
    --data-binary @<(tail -c +$((OFFSET + 1)) "$INPUT_FILE_PATH" | head -c $CHUNK_SIZE)
  OFFSET=$((OFFSET + CHUNK_SIZE))
done

# Finish the upload session
curl -s -X POST https://content.dropboxapi.com/2/files/upload_session/finish \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "Dropbox-API-Arg: {\"cursor\": {\"session_id\": \"$SESSION_ID\", \"offset\": $OFFSET}, \"commit\": {\"path\": \"$INPUT_DROPBOX_PATH\", \"mode\": \"add\", \"autorename\": true, \"mute\": false}}" \
  --header "Content-Type: application/octet-stream"
