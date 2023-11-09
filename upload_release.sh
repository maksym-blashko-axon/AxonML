#!/bin/bash

# Replace with your values
GITHUB_USERNAME="maksym-blashko-axon"
GITHUB_REPO="AxonML"
RELEASE_TAG="1.0.0"
RELEASE_NOTES="Release version 1.0.0"

WORK_DIR=`pwd`
RELEASE_DIR=$WORK_DIR/dist/Release
POD_NAME=${GITHUB_REPO}.xcframework
PACKAGE_NAME=${POD_NAME}.zip

ASSET_PATH="$RELEASE_DIR/$PACKAGE_NAME"

# Obtain a GitHub access token from your account settings
# Or you can use the GITHUB_TOKEN environment variable
GITHUB_TOKEN="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"

# Create a release
release_response=$(curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" \
     -d "{\"tag_name\":\"$RELEASE_TAG\",\"name\":\"$RELEASE_TAG\",\"body\":\"$RELEASE_NOTES\"}" \
     "https://api.github.com/repos/$GITHUB_USERNAME/$GITHUB_REPO/releases")

# Check if the release was created successfully
if [[ $release_response == *"message"* ]]; then
  error_message=$(echo $release_response | jq -r .message)
  error_code=$(echo $release_response | jq -r '.errors[0].code')
  echo "Error creating release (Code: $error_code): $error_message"
  exit 1
fi

# Get the ID of the created release
RELEASE_ID=$(echo $release_response | jq -r .id)

# Upload release assets
upload_response=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
     -H "Content-Type: application/zip" --data-binary "@$ASSET_PATH" \
     "https://uploads.github.com/repos/$GITHUB_USERNAME/$GITHUB_REPO/releases/$RELEASE_ID/assets?name=$(basename $PACKAGE_NAME)")

# Check if the assets were uploaded successfully
if [[ $upload_response == *"message"* ]]; then
  error_message=$(echo $upload_response | jq -r .message)
  echo "Error uploading release asset: $error_message"
  exit 1
fi

# Remove temporary files if needed
rm -f "$ASSET_PATH"

echo "Release $RELEASE_TAG has been created and assets have been uploaded."
