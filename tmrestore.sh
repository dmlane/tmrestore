#!/usr/bin/env bash

#------------------------------------------------------------------------------
#  Restore settings from selected time machine backup
#------------------------------------------------------------------------------

. ~/.local/bin/lib/common.env

CONFIG_DIR=${script_dir}/conf
STAGING_DIR=/tmp/.tmrestore.stage

function get_config {
	export APP=$(crudini --get $1  application name)
	# Files relative to $HOME
	export FILES=$(crudini --get $1 configuration_files 2>/dev/null)
	# Files relative to (normally)  $HOME/.config
	export XDG_FILES=$(crudini --get $1 xdb_configuration_files 2>/dev/null)
}

function choose_backup {

	# If '-f' was given as an option
	[ $replace_restore ] && rm -rf ${STAGING_DIR}

	# Either a disk must be provided *or* a restore must be in staging area
	if [ ! "$tm_disk" ] ; then
		# Check for an existing restore
		[ -d ${STAGING_DIR} ] && return 1
		fail "You must provide a TimeMachine disk"
	fi
	select tm_backupset in $(tmutil listbackups -d $tm_disk -m 2>/dev/null)
	do
		[ $tm_backupset ] && break
	done
	[ ! $tm_backupset ] && fail "No backupsets found on $tm_disk"
	BACKUP_PATH=$(find $tm_backupset -name $USER -type d -maxdepth 4 2>/dev/null|grep "${HOME}\$")
	[ ! "$BACKUP_PATH" ] && fail "Couldn't find '$HOME' in backupset"
	if [ $(wc -l <<<"$BACKUP_PATH") -gt 1 ] ; then
		highlight "There are >1 backup locations found in this backup set - ^Please choose 1^"
		IFS=$'\n'
		select choice in $BACKUP_PATH
		do
			[ $choice ] && break
		done
		[ ! $choice ] && fail "No choice made"
		BACKUP_PATH=$choice
	fi
	BACKUP_PATH=${BACKUP_PATH%$HOME}
	highlight "BACKUP_PATH=^$BACKUP_PATH^"
	return 0
}
function restore_to_stage {
	[ ! -e "$1" ] && return
	target_dir="${2%/*}"
	[ ! -d "$target_dir" ] && mkdir -p "$target_dir"
	if [ -L "$1" ] ; then
		LINKED_TO=$(/usr/bin/readlink "$1")
		echo -en "${YELLOW}Restoring symlink${GREEN}:"
		ln -sv "$LINKED_TO" "$2"
		return
	fi
	tmutil restore "$1" "$2"
}
function process_all_files {
	IFS=$'\n'
	for fn in $3
	do
		full_fn="$2/$fn"
		TARGET_FILE=${STAGING_DIR}${full_fn}
#	FULL_ORIGINAL="$BACKUP_SET$BACKUP_PATH/$original"
		SOURCE_FILE=${BACKUP_PATH}/${full_fn}
		$1 "$SOURCE_FILE" "$TARGET_FILE"

	done
}
function process_all_configs {
	XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-${HOME}/.config}
	for cfg in $(ls ${CONFIG_DIR}/*.cfg|sort)
	do
		get_config $cfg
		highlight "Running ^$1^ for App=^$APP^"
		process_all_files $1 "${HOME}" "$FILES"
		process_all_files $1 "${XDG_CONFIG_HOME}" "$XDG_FILES"
	done

}
while getopts "f" opt
do
	case $opt in
		f) replace_restore=Y ;;
	esac
done
shift  $((OPTIND-1))
[ $# -gt 1 ] && fail "Expected to find 1 parameter only"
tm_disk="$1"

if choose_backup ; then
	highlight "^$tm_backupset^ chosen ($BACKUP_PATH) +++++++++++"  
	rm -rf $STAGING_DIR
	process_all_configs restore_to_stage
else
	highlight "Using ^existing^ restore staging area"
fi
exit
for cfg in $(ls ${CONFIG_DIR}/*.cfg)
do
	get_config $cfg
	process_files
done


