#!/usr/bin/env bash

# ABOUT ################################################################
#	Script: rsync-snapshot-backup-v2.sh
#	Author: Leo Williams
#	Date: 2023-08-04 (Please update)
#
#	Purpose:
#		This script provides a Time Machine-like backup mechanism using rsync.
#		It creates versioned snapshots of a source directory. To conserve
#		disk space, files unmodified since the last snapshot are hard-linked
#		from the previous snapshot rather than being copied again.
#
#	Key Features:
#		- Incremental backups
#		- Space-efficient storage using hard links
#		- Snapshot-based versioning
#
#	Dependencies:
#		- rsync (Note: The script is configured to use /opt/homebrew/bin/rsync)
#		- Common macOS utilities (e.g., date, mkdir, ln, rm)

# USAGE #############################################################
	s_help="
USAGE:
	<script.sh> -s SOURCE_TOP_DIR -t BACKUP_TOP_DIR [-n]
OPTIONS:
    -h|--help)                     Display this help message.
    -s|--source-top-dir SOURCE)    Source directory to mirror.
    -b|--backup-top-dir TARGET)    Target directory to put the mirror of the source dir.
    -n|--dry-run)                  Do a dry run of sync operations.
"

	# display help message if no arguments are passed
	if [[ $# -eq 0 ]] ; then
		echo "$s_help"
		exit 1
	fi


# SETUP #############################################################
# ENVIRONMENT ============================================================
	# explicit path to 'rsync' - needed for cronjobs
	RSYNC='/opt/homebrew/bin/rsync'

# ARGUMENTS ============================================================
	while (( $# )) ; do
		case "$1" in
			-s|--source-top-dir) d_sourceTop="${2%/}" ; shift 2 ;;
			-b|--backup-top-dir) d_backupTop="${2%/}" ; shift 2 ;;
			-n|--dry-run) b_doDryRun="yes" ; shift ;;
			-h|--help) echo "$s_help" ; exit 0 ;;
			-*) echo "-------- ERROR: UNRECOGNIZED OPTION" >&2 ; exit 1 ;;
		esac
	done

	# # ................ TESTING .....................
	# # source dir [top dir to back up]
	# 	d_sourceTop='/Users/leo/_TEST/_TEST--rsync-time-machine/1-SOURCE-TOP'
	# # target dir [base of where backup snapshots should go]
	# 	d_backupTop='/Users/leo/_TEST/_TEST--rsync-time-machine/2-BACKUP-TOP'

	# ARG CHECKS -----------------------------------------
		# source dir
		if [[ -z "$d_sourceTop" ]]; then
			echo "-------- ERROR: Source directory not specified." >&2
			echo "$s_help"
			exit 1
		fi

		# target dir
		if [[ -z "$d_backupTop" ]]; then
			echo "-------- ERROR: Target directory not specified." >&2
			echo "$s_help"
			exit 1
		fi


# VARIABLES ============================================================
	# backup mirror for source top
	s_mirror="$(basename "$d_sourceTop")"
	# s_mirror='_MIRROR'
	
	# archive dirname to move deleted/changed files
	s_archive='__ARCHIVE'
	# s_archive='__ARCHIVE'
	# s_archive='~ARCHIVE'

	# shadow directory to store hard links of previous sync so it can detect moves and renames. need alphanumeric prefix that sorts after the main top directory, otherwise rsync will preferentially copy from the shadow dir of hard links, not the real dir.
	# s_shadow='z__SHADOW'
	# s_shadow='__SHADOW'
	# s_shadow='~SHADOW'
	s_shadow='.__SHADOW'

	# logs dir basename
	s_logs='__LOGS'
	# s_logs='__LOGS'
	# s_logs='~LOGS'


	# BACKUP DIR STRUCTURE -----------------------------------------------
	d_backupMirror="${d_backupTop}/${s_mirror}"
	d_backupArchive="${d_backupTop}/${s_archive}"
	d_backupLogs="${d_backupTop}/${s_logs}"

	mkdir -p \
	"$d_backupMirror" \
	"$d_backupArchive" \
	"$d_backupLogs"

# FUNCTIONS ============================================================
	mainBackupSync () {
		$RSYNC \
			`# DRY RUN --------------------------------` \
			$( [[ "$b_doDryRun" == "yes" ]] && printf -- "--dry-run " ) \
			`# LOGGING --------------------------------` \
				--log-file="$f_log" \
				--human-readable \
				--itemize-changes \
				--progress \
				--stats \
				--verbose \
			`# FILE LIST --------------------------------` \
				--include="/$s_shadow" \
				--exclude=".*" `# exclude all hidden files and directories` \
			`# TRANSFER RULES --------------------------------` \
				--archive \
				--one-file-system \
				--xattrs \
				--hard-links \
				--no-inc-recursive \
				--numeric-ids \
			`# BACKUP & DELETIONS --------------------------------` \
				--backup \
				--backup-dir="../${s_archive}/rsync-backup-$(date +'%Y%m%d%H%M%S')" \
				--delete \
				--delete-during \
			`# LOCATIONS --------------------------------` \
				"${d_sourceTop}/" \
				"${d_backupMirror}/"
	}

		# TESTING ........................
			`# LOGGING --------------------------------` \
			`# FILE LIST --------------------------------` \
				# --exclude=/"$d_backupArchive" `# ? not needed since backup dir outside of source dh ?` \
				# --exclude="/$s_shadow" `# ! breaks detecting moves if in main sync !` \
				# --exclude=".*/" \
			`# TRANSFER RULES --------------------------------` \
				# --no-whole-file \
			`# BACKUP & DELETIONS --------------------------------` \
				# --prune-empty-dirs `# * dont want to remove purposeful empty dirs/working dirs`\
				# --backup-dir="${d_backupArchive}/rsync-backup-$(date +%Y-%m-%d-%H%M%S)" \
				# --backup-dir="${s_archive}/rsync-backup-$(date +%Y-%m-%d-%H%M%S)" \
				# --delete-during \
			`# LOCATIONS --------------------------------` \
				# "$d_backupTop"/				

	updateShadowLinks () {
		dir="$1"
		$RSYNC \
			`# DRY RUN --------------------------------` \
			$( [[ "$b_doDryRun" == "yes" ]] && printf -- "--dry-run " ) \
			`# LOGGING --------------------------------` \
				--log-file="$f_log" \
				--human-readable \
				--itemize-changes \
				--progress \
				--stats \
				--verbose \
			`# FILE LIST --------------------------------` \
				--exclude="/${s_shadow}" \
				--exclude="/${s_archive}" \
				--exclude=".*" \
			`# TRANSFER RULES --------------------------------` \
				--archive \
				--link-dest="${dir}" \
			`# BACKUP & DELETIONS --------------------------------` \
				--delete \
				--delete-during \
				--prune-empty-dirs  \
			`# LOCATIONS --------------------------------` \
				"${dir}/" \
				"${dir}/${s_shadow}/"
	}
	# TESTING ...........................
				# --exclude=".DS_Store" \
				# --delete \
				# --exclude=".*/" \
				# --delete-during \

# INITIALIZATION #############################################################
# LOG FILE =============================================
	# make log file
	f_log="${d_backupLogs}/log-rtm-$(date +%Y-%m-%d-%H%M%S)$( [[ "$b_doDryRun" == "yes" ]] && printf -- "--dry-run" ).log"
	touch "$f_log"
	open -g "$f_log"

# CRONJOB & LOCKFILE =============================================
# needs testing
	# # Check if the script is already running
	# if pgrep -f rsync-snapshot-backup-v2.sh > /dev/null; then
	# 	echo "Script is already running."
	# 	exit 1
	# fi

	# LOCKFILE="/tmp/rsync-snapshot-backup.lock"

	# # Check if the lock file exists
	# if [ -e $LOCKFILE ]; then
	# 	echo "Script is already running." | tee -a "$f_log"
	# 	exit 1
	# else
	# 	# Create the lock file
	# 	touch $LOCKFILE
	# fi

	# # Ensure the lock file is removed when the script exits
	# trap "rm -f $LOCKFILE" EXIT


# MAIN #############################################################
	printf -- "\n################################ JOB START ################################\n" | tee -a "$f_log"
	date "+%Y-%m-%dT%H:%M:%S%z" | tee -a "$f_log"

# 0 initial source shadow links dir =============================================
	# if no shadow links dir on source before first sync, make one
	if [[ ! -d "${d_sourceTop}/${s_shadow}" ]] ; then
		echo "--------WARNING: no shadow on source. Making initial shadow links dir." | tee -a "$f_log"
		updateShadowLinks "$d_sourceTop"
	fi

# 1 main sync =============================================
	printf -- "\n################ Step 1: Main transfer sync ################\n\n" | tee -a "$f_log"
	printf -- "\n################ %s ################\n\n" "$(date "+%Y-%m-%dT%H:%M:%S%z")" | tee -a "$f_log"
	mainBackupSync

# 2 update shadow links =============================================
	printf -- "\n################ Step 2: Updating shadow links ################\n\n" | tee -a "$f_log"
	printf -- "\n################ %s ################\n\n" "$(date "+%Y-%m-%dT%H:%M:%S%z")" | tee -a "$f_log"

	# on source
	printf -- "\n================ Step 2.2: Updating shadow links on source ================n\n" | tee -a "$f_log"
	printf -- "\n================ %s ================n\n" "$(date "+%Y-%m-%dT%H:%M:%S%z")" | tee -a "$f_log"
	updateShadowLinks "$d_sourceTop"

	# on backup
	printf -- "\n================ Step 2.2: Updating shadow links on backup ================n\n" | tee -a "$f_log"
	printf -- "\n================ %s ================n\n" "$(date "+%Y-%m-%dT%H:%M:%S%z")" | tee -a "$f_log"
	updateShadowLinks "$d_backupMirror"

# 3 cleanup ===============================================
	printf -- "\n################ Step 3: Cleaning up ################\n\n" | tee -a "$f_log"
	printf -- "\n################ %s ################\n\n" "$(date "+%Y-%m-%dT%H:%M:%S%z")" | tee -a "$f_log"

	# delete shadowlink dirs in backup archive
	find "$d_backupArchive" -type d -name "$s_shadow" \
		-exec /bin/rm -rf '{}' '+'

	# delete .DS_Store files anywhere in archive
	find "$d_backupArchive" -type f -name ".DS_Store" \
		-exec /bin/rm -rf '{}' '+'
	
	# del files in backup archive with >1 link (which means its not really a deleted file)
	find "$d_backupArchive" -type f -links +1 \
		-exec /bin/rm -rf '{}' '+' 
	# ! MUST come after deleting shadow dirs from backup archive otherwise archived files will be linked to the shadow dir in archive and will be removed as mistaken links.

	# del empty folders in backup archive
	find "$d_backupArchive" -type d -empty \
		-exec /bin/rm -rf '{}' '+'

# } &> "$f_log"

# END #############################################################
	printf -- "\n################################ JOB END ################################\n" | tee -a "$f_log"
	date "+%Y-%m-%dT%H:%M:%S%z" | tee -a "$f_log"
