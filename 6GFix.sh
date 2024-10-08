#!/bin/sh
###################################################################
# 6GHzFix.sh (6GHzFix)
#
# Original Creation Date: 2024-Aug-07 by @ExtremeFiretop.
# Last Modified: 2024-Aug-07
###################################################################

# Define a log file location
LOGFILE="/jffs/scripts/nvram_output.log"

# Function to log messages with timestamps
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# Overwrite the log file if it already exists
: > "$LOGFILE"

# Log script start
log_message "Starting 6GHz Fix"

log_message "SLEEPING"
sleep 300

# Verify environment and permissions
log_message "Current user: $(whoami)"
log_message "Current directory: $(pwd)"
log_message "Shell: $SHELL"

# Retrieve NVRAM variables matching the pattern wlc*_closed
wlc_closed_values=$(nvram show | grep -E '^wlc[0-9]*_closed=')
log_message "Debug: Found wlc_closed_values: $wlc_closed_values"

# Process each wlc*_closed variable
set -f  # Disable filename expansion (globbing)
IFS="
"
for line in $wlc_closed_values; do
  # Check if line is not empty
  if [ -z "$line" ]; then
    log_message "Warning: Empty line encountered in wlc_closed_values"
    continue
  fi

  # Extract the variable name
  var_name=$(echo "$line" | cut -d'=' -f1)
  log_message "Debug: Processing var_name: $var_name"

  # Ensure the variable name is not empty
  if [ -z "$var_name" ]; then
    log_message "Error: Failed to extract var_name from line: $line"
    continue
  fi

  # Set the NVRAM variable to 0
  if nvram set "$var_name=0"; then
    log_message "Debug: Successfully set $var_name to 0"
  else
    log_message "Error: Failed to set $var_name to 0"
    continue
  fi
done
unset IFS

# Find all NVRAM variables matching the pattern wlc*_ssid that contain "dwb"
wlc_ssid_values=$(nvram show | grep -E '^wlc[0-9]*_ssid=.*dwb')
log_message "Debug: Found wlc_ssid_values: $wlc_ssid_values"

# Initialize wl_ssid_value
wl_ssid_value=""

# Process each wlc*_ssid variable
set -f  # Disable filename expansion (globbing)
IFS="
"
for line in $wlc_ssid_values; do
  # Check if line is not empty
  if [ -z "$line" ]; then
    log_message "Warning: Empty line encountered in wlc_ssid_values"
    continue
  fi

  # Extract the variable name
  var_name=$(echo "$line" | cut -d'=' -f1)
  log_message "Debug: Processing var_name: $var_name"

  # Ensure the variable name is not empty
  if [ -z "$var_name" ]; then
    log_message "Error: Failed to extract var_name from line: $line"
    continue
  fi

  # Extract the current value
  current_value=$(echo "$line" | cut -d'=' -f2-)
  log_message "Debug: Current value of $var_name: $current_value"

  # Remove '_dwb' from the value
  new_value=$(echo "$current_value" | sed 's/_dwb//g')
  log_message "Debug: Value after removing '_dwb': $new_value"

  # Replace "2.4GHz" or "5GHz" with "6GHz", case-insensitive
  new_value=$(echo "$new_value" | sed -E 's/(2\.4|5)GHz/6GHz/I')
  log_message "Debug: Value after replacing with 6GHz: $new_value"

  # Append the new value to the wl_ssid_value variable
  wl_ssid_value="${wl_ssid_value}${new_value}"
  log_message "Debug: wl_ssid_value updated to: $wl_ssid_value"
done
unset IFS

# Set final NVRAM variables
if nvram set wl2.1_closed=0; then
  log_message "Debug: Set wl2.1_closed to 0"
else
  log_message "Error: Failed to set wl2.1_closed to 0"
fi

if nvram set wl2.1_ssid="$wl_ssid_value"; then
  log_message "Debug: Set wl2.1_ssid to $wl_ssid_value"
else
  log_message "Error: Failed to set wl2.1_ssid to $wl_ssid_value"
fi

# Commit changes to NVRAM
sleep 3
if nvram commit; then
  log_message "Debug: NVRAM committed"
else
  log_message "Error: Failed to commit NVRAM"
fi

# Turn on the radio and set up the interface
sleep 3
if wl -i wl2.1 ssid "$wl_ssid_value" >/dev/null 2>&1; then
  log_message "Debug: Wireless interface wl2.1 ssid set to $wl_ssid_value"
else
  log_message "Error: Failed to set wireless interface wl2.1 ssid to $wl_ssid_value"
fi

# Restart wireless service
sleep 10
if service restart_wireless >/dev/null 2>&1; then
  log_message "Debug: Wireless service restarted"
else
  log_message "Error: Failed to restart wireless service"
fi

sleep 10
log_message "6GHz Fix Done"

exit 0

#EOF#
