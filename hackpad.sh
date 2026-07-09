#!/bin/bash
#set -x 

# User name
USER_NAME="markumina"

# Extract the input<number> path dynamically from /proc/bus/input/devices
TOUCHPAD_DEVICE=$(awk '
    /^N: Name=/ && tolower($0) ~ /touchpad/ { in_touchpad = 1; next }
    in_touchpad && /^S: Sysfs=/ {
        sub(/^S: Sysfs=.*\/input\//, "")
        print
        exit
    }
    /^$/ { in_touchpad = 0 }
' /proc/bus/input/devices)

# Check if the path was found
if [ -z "$TOUCHPAD_DEVICE" ]; then
    echo "Error: No touchpad device found in /proc/bus/input/devices."
    exit 1
fi

# Define the full path to the "inhibited" file for the touchpad
TOUCHPAD_DEVICE="/sys/class/input/${TOUCHPAD_DEVICE}/inhibited"

if [ ! -f "$TOUCHPAD_DEVICE" ]; then
    echo "Error: Touchpad inhibited path not found: $TOUCHPAD_DEVICE"
    exit 1
fi

# Dump it for debug
echo "TOUCHPAD_DEVICE is set to: $TOUCHPAD_DEVICE"

# Runtime file to store the state of touched_while_in_delay
RUNTIME_DIR="${RUNTIME_DIRECTORY:-/run/hackpad}"
mkdir -p "$RUNTIME_DIR"
TOUCHED_FILE="$RUNTIME_DIR/touched_while_in_delay"

# Function to disable the touchpad
disable_touchpad() {
    echo 1 > "$TOUCHPAD_DEVICE"
}

# Function to enable the touchpad
enable_touchpad() {
    echo 0 > "$TOUCHPAD_DEVICE"
}

# Cleanup function to handle script exit
cleanup() {
    enable_touchpad  # Ensure touchpad is re-enabled on exit
    rm -f "$TOUCHED_FILE"  # Clean up the temporary file
    kill "${key_monitor_pid}" 2>/dev/null  # Kill the key monitoring thread
    kill "${inactivity_check_pid}" 2>/dev/null  # Kill the inactivity checking thread
    exit 0
}

# Trap to catch all exit signals
trap cleanup EXIT

# Enable touchpad on script start
enable_touchpad

# Turn on disable-while-typing
# - It can prevent an issue where the touchpad may freeze until finger is lifted and placed again
su - "$USER_NAME" -c "gsettings set org.gnome.desktop.peripherals.touchpad disable-while-typing true"

# Turn off tap and drag, I've found it to be a pain with a sensitive touchpad
su - "$USER_NAME" -c "gsettings set org.gnome.desktop.peripherals.touchpad tap-and-drag false"

# Initialize the touched_while_in_delay state
echo 0 > "$TOUCHED_FILE"

# Thread for monitoring key presses
monitor_keys() {
    stdbuf -oL libinput debug-events | grep --line-buffered "KEYBOARD_KEY" | while read -r event; do
        #echo "k"  # Output 'k' for key press
        echo 1 > "$TOUCHED_FILE"  # Set touched_while_in_delay to 1
        #echo "mon: $(cat $TOUCHED_FILE)"  # Output the state for debugging
        if [ -f "$TOUCHPAD_DEVICE" ] && [ "$(cat "$TOUCHPAD_DEVICE")" -eq 0 ]; then
            disable_touchpad
        fi
    done
}

# Thread for checking inactivity
check_inactivity() {
    while true; do
        # If touchpad is disabled, wait some time, then check the state
        if [ -f "$TOUCHPAD_DEVICE" ] && [ "$(cat "$TOUCHPAD_DEVICE")" -eq 1 ]; then
            sleep 0.20 # Main delay, post keypress.

            touched_while_in_delay=$(cat "$TOUCHED_FILE")  # Read the state from the file
            #echo "inactivity: $touched_while_in_delay"
            if [ "$touched_while_in_delay" -eq 0 ]; then
                enable_touchpad
            else
                echo 0 > "$TOUCHED_FILE"  # Reset touched_while_in_delay to 0
                #echo "t"  # Output 't' for touched
            fi
        fi

        sleep 0.1 # Reduce CPU cycles, TBD break delays out into vars.
    done
}

# Start both threads
monitor_keys &
key_monitor_pid=$!  # Capture the PID of the key monitoring thread

check_inactivity &
inactivity_check_pid=$!  # Capture the PID of the inactivity checking thread

# Wait for both background processes
wait
