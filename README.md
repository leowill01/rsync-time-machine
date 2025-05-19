# Rsync Time Machine
A Time Machine-like backup utility using rsync that creates space-efficient snapshots with versioning.

## Features
- Incremental backups using rsync
- Space-efficient storage using hard links
- Snapshot-based versioning
- Automatic archiving of deleted/changed files
- Detailed logging of all operations

## Requirements
- macOS with Homebrew
- rsync (installed via Homebrew)
- Common macOS utilities (date, mkdir, ln, rm)

## Installation
1. Ensure rsync is installed:
```bash
brew install rsync
```

2. Clone or download this repository
3. Make the script executable:
```bash
chmod +x rsync-time-machine.sh
```

## Usage
```bash
./rsync-time-machine.sh -s SOURCE_DIR -b BACKUP_DIR [-n]
```

### Options
- `-s, --source-top-dir SOURCE`: Directory to backup
- `-b, --backup-top-dir TARGET`: Directory where backups will be stored
- `-n, --dry-run`: Perform a trial run without making any changes
- `-h, --help`: Display help message

### Example
```bash
./rsync-time-machine.sh -s /Users/me/Documents -b /Volumes/Backup/TimeMachine
```

## Backup Structure
The backup directory will contain:
- `_MIRROR/`: The main backup directory containing the latest snapshot
- `__ARCHIVE/`: Contains previous versions of modified/deleted files
- `__LOGS/`: Detailed logs of each backup operation
- `.__SHADOW/`: Internal directory used for detecting moves and renames

## Notes
- The script automatically creates all necessary directories
- Each backup operation generates a detailed log file
- Hidden files (starting with '.') are excluded by default
- Files deleted from the source are moved to the archive instead of being deleted

# TODO
- add option for 2 separate backup modes: 
	- 1] **single current mirror + deleted archive**
		- (currently implemented) this style maintains a single snapshot of the current state of the folder as it appears when backed up. only deleted or changed files are moved to a timestamped archive folder for retrival if needed.
	- 2] **many full-directory snapshot backups**
		- this style more directly mirrors Apple's *Time Machine* utility there are separate timestamped snapshot folders that include the entire filetree of the source folder as it appeared when backed up.