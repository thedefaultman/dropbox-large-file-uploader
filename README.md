# Dropbox Large File Uploader GitHub Action

This action uploads large files to Dropbox using the Dropbox API, handling file uploads in chunks and managing OAuth 2.0 tokens.

## Inputs

- `app_key`: **Required**. The Dropbox API app key.
- `app_secret`: **Required**. The Dropbox API app secret.
- `refresh_token`: **Required**. The Dropbox API refresh token.
- `file_path`: **Required**. The path to the file to upload.
- `dropbox_path`: **Required**. The destination path in Dropbox.

## Example Usage

```yaml
uses: your-username/dropbox-large-file-uploader@v1
with:
  app_key: ${{ secrets.DROPBOX_APP_KEY }}
  app_secret: ${{ secrets.DROPBOX_APP_SECRET }}
  refresh_token: ${{ secrets.DROPBOX_REFRESH_TOKEN }}
  file_path: './build.zip'
  dropbox_path: '/your/path/on/dropbox/build.zip'