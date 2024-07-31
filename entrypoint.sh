#!/bin/bash

# Function to obtain a new access token using the refresh token
get_access_token() {
  echo "Obtaining new access token..."
  apiToken=$(curl -s -X POST https://api.dropbox.com/oauth2/token \
    -u "${INPUT_APP_KEY}:${INPUT_APP_SECRET}" \
    -d grant_type=refresh_token \
    -d refresh_token=${INPUT_REFRESH_TOKEN} | jq -r '.access_token')

  if [ -z "$apiToken" ]; then
    echo "Failed to obtain access token."
    exit 1
  fi
}

# Check for required inputs
if [[ -z "$INPUT_APP_KEY" || -z "$INPUT_APP_SECRET" || -z "$INPUT_REFRESH_TOKEN" || -z "$INPUT_FILE_PATH" || -z "$INPUT_DROPBOX_PATH" ]]; then
  echo "Required inputs are missing."
  exit 1
fi

# Obtain the access token
get_access_token

# Start the upload session
sessionId=$(curl -s -X POST https://content.dropboxapi.com/2/files/upload_session/start \
  --header "Authorization: Bearer ${apiToken}" \
  --header "Dropbox-API-Arg: {\"close\": false}" \
  --header "Content-Type: application/octet-stream" | jq -r '.session_id')

if [ -z "$sessionId" ]; then
  echo "Failed to start upload session."
  exit 1
fi

# Calculate file size and define chunk size
totalFileSize=$(wc -c <"$INPUT_FILE_PATH")
chunkSize=150000000  # 150 MB

# Split the file into chunks using BusyBox-compatible syntax
chunkDir="chunks"
if [ ! -d "${chunkDir}" ]; then
  mkdir ${chunkDir}
fi
split -b ${chunkSize} "$INPUT_FILE_PATH" ./${chunkDir}/chunk_

# Upload chunks to Dropbox
offset=0
for file in $(ls -v ./${chunkDir}/)  # -v for natural sort order in BusyBox
do
  response=$(curl -s -X POST https://content.dropboxapi.com/2/files/upload_session/append_v2 \
    --header "Authorization: Bearer ${apiToken}" \
    --header "Dropbox-API-Arg: {\"cursor\": {\"session_id\": \"${sessionId}\",\"offset\": ${offset}},\"close\": false}" \
    --header "Content-Type: application/octet-stream" \
    --data-binary @"$file")

  # Handle incorrect offset error by retrying with the correct offset
  if echo "$response" | grep -q "incorrect_offset"; then
    correct_offset=$(echo "$response" | jq -r '.error.lookup_failed.correct_offset')
    echo "Incorrect offset detected. Adjusting to correct offset: $correct_offset"
    offset=$correct_offset
  else
    offset=$((offset + chunkSize))
  fi
done

# Finalize the upload session
curl -s -X POST https://content.dropboxapi.com/2/files/upload_session/finish \
  --header "Authorization: Bearer ${apiToken}" \
  --header "Dropbox-API-Arg: {\"cursor\": {\"session_id\": \"${sessionId}\",\"offset\": ${totalFileSize}},\"commit\": {\"path\": \"${INPUT_DROPBOX_PATH}\",\"mode\": \"add\",\"autorename\": true,\"mute\": false,\"strict_conflict\": false}}" \
  --header "Content-Type: application/octet-stream"

# Clean up the chunk directory
cd ..
rm -rf ${chunkDir}

echo "File uploaded successfully to Dropbox at ${INPUT_DROPBOX_PATH}"
