# Description of backupFilesToFileLu.sh
The backupFilesToFileLu.sh script automates the backup process to FileLu (https://filelu.com), a remote file-hosting service.

It generates and uploads backups, and deletes old ones based on a defined retention period, helping to manage storage space by removing older backups. This ensures only the most recent backups are kept on the server.

*Screenshot demo from cron job email:*

![image](https://github.com/user-attachments/assets/cdc8d533-0cbc-4b75-891a-bee3fe0f3b1d)


# Usage Possibilities
- Automate backups on any system capable of running bash scripts.
- Schedule periodic backups via cron jobs for web hosting.

# Installation Guide
1. **Verify your configurations**: Set your configurations at the top of the script.
2. **Place the script**: Store the script in your desired location.
3. **Add Execute permissions**: Make the script executable.
   ```
   chmod +x backupFilesToFileLu.sh
   ```
4. **Run**: Schedule it or run it from the command line.
   - Command line example:
   ```
   ./backupFilesToFileLu.sh
   ```
   - Cron jobs example:
   ```
   0 0 * * *     /home/account_name/backupFilesToFileLu.sh
   ```

# Configuration
Set your configurations at the top of the script:

- `DAYS_TO_KEEP=3`: Number of days to keep backups
- `FOLDER_TO_BACKUP="/home/account_name/public_html"`: Directory to back up
- `BACKUP_FOLDER="/home/account_name/backups_tmp"`: Folder for storing backups (e.g., /tmp)
- `BACKUP_DELETE=true`: Set to true to delete local backup files after upload
- `BACKUP_FILENAMEPREFIX="backup_"`: Common prefix for all backup filenames
- `BACKUP_FILENAME="$(date +%Y%m%d_%H%M%S)"`: Filename with automatically generated timestamp
- `FILELU_API_KEY="filelu_api_key"`: Your Filelu API key (https://filelu.com/account/)
- `FILELU_FOLDER_NAME="backups"`: Folder name on Filelu root for storing backups

# My FileLu affiliate link
You can register FREE for 10GB or use my referral link bellow to earn additional storage space.
https://filelu.com/5153524955.html 
