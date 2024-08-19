#!/usr/bin/env bash

set -eu

function usage () {
	echo "Usage: $0 --wwid wwid | --alias alias " 
	exit 1
}

# logging level by defaults: crit, error, warning, notice
VERBOSE="${VERBOSE:-5}"
ME=`basename $0`
current_dir="$(pwd)"

###### LOGGING ######
function log_crit () {
        [ ${VERBOSE} -lt 1 ] && return
        local MESSAGE="$1"
        local FILE_PATH="${2:-/dev/null}"

        FILE_MESSAGE="Critical: $MESSAGE"
        if [ -f "$FILE_PATH" ]; then echo $FILE_MESSAGE >> $FILE_PATH; fi
        local PRI='local7.crit'
        logger -s -p ${PRI} -t ${ME}[$$] -- ${MESSAGE}
}
function log_error () {
        [ ${VERBOSE} -lt 2 ] && return
        local MESSAGE="$1"
        local FILE_PATH="${2:-/dev/null}"

        FILE_MESSAGE="Error: $MESSAGE"
        if [ -f "$FILE_PATH" ]; then echo $FILE_MESSAGE >> $FILE_PATH; fi
        local PRI='local7.error'
        logger -s -p ${PRI} -t ${ME}[$$] -- ${MESSAGE}
}
function log_warning () {
        [ ${VERBOSE} -lt 3 ] && return
        local MESSAGE="$1"
        local FILE_PATH="${2:-/dev/null}"

        FILE_MESSAGE="Warning: $MESSAGE"
        if [ -f "$FILE_PATH" ]; then echo $FILE_MESSAGE >> $FILE_PATH; fi
        local PRI='local7.warning'
        logger -s -p ${PRI} -t ${ME}[$$] -- ${MESSAGE}
}
function log_notice () {
        [ ${VERBOSE} -lt 4 ] && return
        local MESSAGE="$1"
        local FILE_PATH="${2:-/dev/null}"

        FILE_MESSAGE="Notice: $MESSAGE"
        if [ -f "$FILE_PATH" ]; then echo $FILE_MESSAGE >> $FILE_PATH; fi
        local PRI='local7.notice'
        logger -s -p ${PRI} -t ${ME}[$$] -- ${MESSAGE}
}
function log_info () {
        [ ${VERBOSE} -lt 5 ] && return

        local MESSAGE="$1"
        local FILE_PATH="${2:-/dev/null}"
						
        FILE_MESSAGE="Info: $MESSAGE"
        if [ -f "$FILE_PATH" ]; then
			echo $FILE_MESSAGE >> $FILE_PATH
		fi

        local PRI='local7.info'
        logger -s -p ${PRI} -t ${ME}[$$] -- ${MESSAGE}
}
function log_debug () {
        [ ${VERBOSE} -lt 6 ] && return
        local MESSAGE="$1"
        local FILE_PATH="${2:-/dev/null}"

        FILE_MESSAGE="Debug: $MESSAGE"
        if [ -f "$FILE_PATH" ]; then echo $FILE_MESSAGE >> $FILE_PATH; fi
        local PRI='local7.debug'
        logger -s -p ${PRI} -t ${ME}[$$] -- ${MESSAGE}
}
###### LOGGING ######


function is_command_exists() {
	local cmd="$1"

	if ! command -v "$cmd" &>/dev/null; then
		log_error "$cmd is not installed."
		exit 1
	fi

	log_debug "found '$cmd' command"
}

function is_module_loaded () {
	local mod_name="$1"
	if ! lsmod | grep -wq "$mod_name"; then
		log_error "Module $mod_name not loaded"
		exit 1
	fi
}

function is_systemd_service_exists () {
	local service_name="$1"
	if ! systemctl list-unit-files --no-legend "${service_name}.service" &> /dev/null; then
		log_error "systemd service $service_name doesn't exists"
		exit 1
	fi
}

function is_systemd_service_active () {
	local service_name="$1"
	if ! systemctl --quiet is-active "${service_name}.service"; then
		log_error "systemd service $service_name is not active"
		exit 1
	fi
}

function remove_record() {
	# this function make backup and remove mpio records from multipath
	local file="$1"
	local wwid="$2"

    if [ -z "$file" ]; then
        log_crit "Failed to remove record empty 'file' parameter"
        exit 1
    fi

    if [ -z "$wwid" ]; then
        log_crit "Failed to remove record empty 'wwid' parameter"
        exit 1
    fi

    local tmp_dir=$(mktemp -d)
    local curr_date=$(date +%F_%H:%M:%S)
    local file_name=$(basename "$file")
    local bak_file_name="${tmp_dir}/${file_name}_${curr_date}"

	if [ -z "$tmp_dir" ]; then
		log_error "Failed to create temp directory for backup!"
		exit 1
	fi

	log_info "Created directory for backup: $tmp_dir"
	cp "$file" "$bak_file_name"
	if [ ! -f "$bak_file_name" ]; then
		log_error "Failed to create backup file $bak_file_name"
		exit 1
	fi
	log_info "Backup file for $file was created in $bak_file_name"

	sed -i "/multipath {/{:a;N;/}/!ba;/$wwid/d}" "$file" &>/dev/null
}

function clear_mpio_record() {
	local wwid="$1"
	local main_conf="/etc/multipath.conf"
	local conf_dir="/etc/multipath/conf.d"

	# если параметр 'config_dir' существует в /etc/multipath.conf. Используем его
	local check_dir=$(grep -w 'config_dir' "$main_conf" | awk '{print $2}' | tr -d '"')
	if [ -n "$check_dir" ]; then
		conf_dir=$(basename -z ${check_dir}/NULL)
	fi

	# search records inside dropin dir
	if [ -d "$conf_dir" ]; then
		curr_file=$(grep -r "\b$wwid\$" "$conf_dir" | awk -F: '{print $1}')
		if [ -n "$curr_file" ]; then
			remove_record "$curr_file" "$wwid"
		fi
	fi

	# search records inside multipath.conf file
	if grep -wq "$wwid" "$main_conf"; then
		remove_record "$main_conf" "$wwid"
	fi

}

function is_multipath_device () {
	local device="$1"

	if ! multipathd show maps format "%w" | grep -qw "$device"; then
		log_error "Device '$device' not found in multipath"
		return 1
	fi

	return 0
}

function mpio_wwid_to_dm () {
	local wwid="$1"
	
	is_mpio_device_exists "$wwid"

	local dm=$(multipathd show maps format "%d %w" | grep -w "$wwid" | awk '{print $1}')
	if [ -z "$dm" ]; then
			log_error "DM for '$wwid' not found by multipathd "
			exit 1		
	fi
	echo $dm
}

function mpio_alias_to_wwid () {
	local alias="$1"

	local wwid=$(multipathd show maps format "%n %w" | grep -w "$alias" | awk '{print $2}')
	if [ -z "$wwid" ]; then
		log_error "WWID for '$alias' not found in multipath configuration"
		exit 1
	fi

	echo $wwid
}

function mpio_wwid_to_alias () {
	local wwid="$1"

	is_mpio_device_exists "$wwid"

	local alias=$(multipathd show maps format "%n %w" | grep -w "$wwid" | awk '{print $1}')
	if [ -z "$alias" ]; then
			log_error "Alias for '$wwid' not found in multipath configuration"
			exit 1
	elif [ "$wwid" == "$alias" ]; then
			log_warning "The device '$wwid' doesn't have alias"
			echo "$wwid"
	else
		echo $alias
	fi
}

function is_device_busy () {
	# Important!!! It is recommended to perform this check correctly through the device's sysfs
	local device="$1"

	result=$(dmsetup info "$device" | grep -w 'Open count:' | awk '{print $3}')
	if [ "$result" -ne 0 ]; then
		log_error "Error! The device $device has opened processes:"
		dmsetup info "$device"
		exit 1
	fi
}

function is_device_in_lvm () {
        local path="$1"
        local device="$2"

        if [[ $(ls -l /dev/disk/by-id/ | grep lvm-pv.*"$path") ]]; then
                log_error "Error! The device $device is in lvm"
                pvs
                exit 1
        fi
}


function is_mpio_device_exists() {
	local alias_or_wwid="$1"

	if ! multipathd show maps | grep -wq "$alias_or_wwid"; then
			log_error "Search device by '$alias_or_wwid' is failed!"
			exit 1
	fi
}

if [[ $# -lt 2 ]]; then
    usage
fi

mpio_wwid=""
mpio_alias=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--wwid)
			if [[ -n "$mpio_alias" ]]; then
				echo "Error: Cannot use --wwid and --alias together."
				usage
			fi
			mpio_wwid="$2"
			shift 2
		;;

		--alias)
			if [[ -n "$mpio_wwid" ]]; then
				echo "Error: Cannot use --wwid and --alias together."
				usage
			fi
			mpio_alias="$2"
			shift 2
		;;

		*)
			usage
		;;
	esac
done

# need to be root
if [ $EUID -ne 0 ]; then
    log_error "This script must be run as root" 
    exit 125
fi

commands=("dmsetup" "multipathd" "blockdev")
for command in "${commands[@]}"; do
	is_command_exists "$command"
done

MPIO_MOD_NAME="dm_multipath"
MPIO_DAEMON_NAME="multipathd"

is_module_loaded "$MPIO_MOD_NAME"
log_debug "Module $MPIO_MOD_NAME is loaded"

is_systemd_service_exists "$MPIO_DAEMON_NAME"
log_debug "systemd service $MPIO_DAEMON_NAME exists"

is_systemd_service_active "$MPIO_DAEMON_NAME"
log_debug "systemd service $MPIO_DAEMON_NAME is active"

if [ -n "$mpio_alias" ]; then
	multipath_wwid=$(mpio_alias_to_wwid "$mpio_alias")
	multipath_alias="$mpio_alias"
else
	multipath_alias=$(mpio_wwid_to_alias "$mpio_wwid")
	multipath_wwid="$mpio_wwid"
fi

is_multipath_device "$multipath_wwid"
log_debug "The device $multipath_wwid ($multipath_alias) is multipath device"

dm_device="$(mpio_wwid_to_dm $multipath_wwid)"
dm_device_path="/dev/$dm_device"

log_debug "Device wwid:    $multipath_wwid"
log_debug "Device alias:   $multipath_alias"
log_debug "Device dm path: $dm_device_path"

is_device_busy "$dm_device_path"
log_debug "The device $multipath_wwid ($multipath_alias) not busy"

is_device_in_lvm "$dm_device" "$multipath_alias"
log_debug "The device $multipath_wwid ($multipath_alias) not in lvm"

clear_mpio_record "$multipath_wwid"

blockdev --flushbufs "$dm_device_path"
log_info "flushed buffers for $dm_device_path"

paths=($(dmsetup deps -o devname "$dm_device_path" | awk -F: '{print $2}' | tr -d '()'))
for i in "${paths[@]}"; do 
	if [ ! -b "/dev/${i}" ]; then
		log_crit "This is not a block device /dev/${i}. Abort..."
		exit 1
	fi
	echo 1 > /sys/block/${i}/device/delete
done
log_debug "The next paths were removed: ${paths[*]}"
systemctl reload "$MPIO_DAEMON_NAME"

exit 0
