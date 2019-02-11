# Simple Dropbox Backup

A simple bash script for backup up directories to Dropbox

## Setup

1. Go to https://www.dropbox.com/developers/apps and setup an API v2 app with full  access to your Dropbox account
2. Configure the appropriate variables in the header of `backup.sh`
3. Run `chmod o+x ./backup.sh`
4. Launch the script with `./backup.sh` or add it to a scheduled cron
5. Profit

This script is overly simple and assumes your settings are correct; there is currently no error checking.

## To-do

1. Delete backup files after reaching a certain age
2. Maybe some other stuff
