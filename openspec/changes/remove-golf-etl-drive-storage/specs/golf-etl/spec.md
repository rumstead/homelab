## REMOVED Requirements

### Requirement: Drive Credentials
**Reason**: golf-etl runs in GitHub storage mode only, so the rclone Google Drive token is no longer used.
**Migration**: The pipeline authenticates to GitHub with the deploy key (Requirement: Deploy Key). The `golf-etl-rclone` Secret, `GOLF_REMOTE` and the `RCLONE_*` settings are deleted.
