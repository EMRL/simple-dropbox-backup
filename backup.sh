#!/bin/bash
export TERM=${TERM:-dumb}
TODAY="$(date +%Y-%m-%d)"
	
################################ USER SETINGS #################################

# Name this backup
BACKUP_NAME="Web Backup"

# Root path of all backup
ROOT_BACKUP_PATH="/path/to/backup/root"

# Directories within ROOT_BACKUP_PATH to recursively backup
# format is (directory directory directory)
BACKUP_SOURCE=(directory directory directory)

# Dropbox app token
TOKEN="################################################################"

# Drob=pbox path for backup uploads
DROPBOX_PATH="/backup/path"

# Comman seperated list of emails to receive notification - leave blank 
# to disable
NOTIFICATION_EMAIL="you@domain.com"

# Email the notificatios will be sent from
NOTIFICATION_FROM_EMAIL="you@domain.com"

# Notification label, usually something like [BACKUP] - this is pre-pended to 
# the subject line
NOTIFICTION_LABEL="[BACKUP]"

# Slack (See https://YOURTEAMNAME.slack.com/apps/manage/custom-integration to 
# learn how to get started) - leave this blank to disable 
NOTIFICATION_SLACK="https://hooks.slack.com/services/#########/#########/########################"

####################### NO NEED TO EDIT BELOW THIS LINE #######################

# Main application
function main() {
	get_dependencies	# Make sure we have what we need to run
	backup 				# Run the backup and upload
	filecount			# Count number of backup files 
	email_notify		# Build and send email
	slack_notify		# Build and send Slack webhook
	cleanup 			# Clean up leftovers
}

function get_dependencies() {
	SENDMAIL_CMD="$(which sendmail)"
	CURL_CMD="$(which curl)"
	WGET_CMD="$(which wget)"
	TAR_CMD="$(which tar)"
}

function backup() {
	echo "${ROOT_BACKUP_PATH}" >> "/tmp/bu-dropbox.log"
	
	# Loops through the variables
	for i in "${BACKUP_SOURCE[@]}" ; do
		TAR_FILE="${i}-${TODAY}.tgz"
		make_tarball
	done
	echo -e "" >> /tmp/bu-dropbox.log
	echo "Backup complete."
}

function make_tarball() {
	echo "Creating ${TAR_FILE}..."
	"${TAR_CMD}" cfz "/tmp/${TAR_FILE}" "${ROOT_BACKUP_PATH}/${i}" 2> /dev/null & spinner $!

	echo "Pushing ${TAR_FILE} to Dropbox..."
	"${CURL_CMD}" -s -o /dev/null -X POST https://content.dropboxapi.com/2/files/upload \
		--header "Authorization: Bearer ${TOKEN}" \
		--header "Dropbox-API-Arg: {\"path\": \"${DROPBOX_PATH}/${TAR_FILE}\",\"mode\": \"add\",\"autorename\": true,\"mute\": false}" \
		--header "Content-Type: application/octet-stream" \
		--data-binary @"/tmp/${TAR_FILE}" 2> /dev/null & spinner $!

	# Cleanup and log
	[[ -w "${ROOT_BACKUP_PATH}/${i}" ]] && rm -f "/tmp/${TAR_FILE}"
	echo "   ${TAR_FILE}" >> /tmp/bu-dropbox.log
	PAYLOAD=$(</tmp/bu-dropbox.log)	# Create notification payload
}

function filecount() {
	# Get the number of files backed up, assuming *.tgz
	FILES=$(grep -c "tgz" "/tmp/bu-dropbox.log")

	# Build the correct text string
	if [[ -z "${FILES}" ]]; then
		FILES_SUMMARY="Nothing to backup"
	else
		if [[ "${FILES}" -gt "1" ]]; then
			FILES_LABEL="files"
		else
			FILES_LABEL="file"
		fi
		FILES_SUMMARY="${FILES} ${FILES_LABEL} uploaded to Dropbox"
		FILES_SUMMARY_FULL="${FILES_SUMMARY}\nhttps://www.dropbox.com/home${DROPBOX_PATH}"
	fi
}

function email_notify() {
	if [[ -n "${NOTIFICATION_EMAIL}" ]] && [[ -n "${FILES}" ]]; then
		(
		echo "From: ${NOTIFICATION_FROM_EMAIL} <${NOTIFICATION_FROM_EMAIL}>"
		echo "To: ${NOTIFICATION_EMAIL}"
		echo "Subject: ${NOTIFICTION_LABEL} ${BACKUP_NAME}"
		echo "Content-Type: text/plain"
		echo
		echo "${BACKUP_NAME}"
		echo "---------------------"
		echo "${PAYLOAD}"
		echo
		echo -e "${FILES_SUMMARY_FULL}"
		) | "${SENDMAIL_CMD}" -t
	fi
}

function slack_notify() {
	if [[ -n "${NOTIFICATION_SLACK}" ]] && [[ -n "${FILES}" ]]; then
		# Someday icon  may change if an error check is added
		SLACK_ICON=":heavy_check_mark:"
		SLACK_MESSAGE="*${BACKUP_NAME}*: ${FILES_SUMMARY} (<https://www.dropbox.com/home${DROPBOX_PATH}|View>)"
		"${CURL_CMD}" -s -X POST --data "payload={\"text\": \"${SLACK_ICON} ${SLACK_MESSAGE}\"}" "${NOTIFICATION_SLACK}" > /dev/null
	fi
}

# Progress spinner; we'll see if this works
function spinner() {
	if [[ "${QUIET}" != "1" ]]; then
		local pid=$1
		local delay=0.15
		# Is there a better way to format this thing?  It's wonky
		local spinstr='|/-\'
		tput civis;
		
		while [[ "$(ps a | awk '{print $1}' | grep ${pid})" ]]; do
	  		local temp=${spinstr#?}
	  		printf "Working... %c  " "$spinstr"
	  		local spinstr=$temp${spinstr%"$temp"}
	  		sleep $delay
	  		printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
		done
		
		printf "            \b\b\b\b\b\b\b\b\b\b\b\b"
		tput cnorm;
  	fi
}

function cleanup() {
	# Cleanup
	[[ -w "/tmp/bu-dropbox.log" ]] && rm -f "/tmp/bu-dropbox.log"
}

# Run the app
main
