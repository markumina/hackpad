#!/bin/bash
#set -x 

# Path to the touchpad input device
TOUCHPAD_DEVICE="/sys/devices/pci0000:00/0000:00:15.2/i2c_designware.1/i2c-2/i2c-VEN_0488:00/0018:0488:1072.0002/input/input17/inhibited"

# Temporary file to store the state of touched_while_in_delay
TOUCHED_FILE="/tmp/touched_while_in_delay.txt"

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

# Disable touchpad on script start
enable_touchpad

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
        # If touchpad is disabled, wait 1.1 seconds, then check the state
        if [ -f "$TOUCHPAD_DEVICE" ] && [ "$(cat "$TOUCHPAD_DEVICE")" -eq 1 ]; then
            sleep 0.5

            touched_while_in_delay=$(cat "$TOUCHED_FILE")  # Read the state from the file
            #echo "inactivity: $touched_while_in_delay"
            if [ "$touched_while_in_delay" -eq 0 ]; then
                enable_touchpad
            else
                echo 0 > "$TOUCHED_FILE"  # Reset touched_while_in_delay to 0
                #echo "t"  # Output 't' for touched
            fi
        fi

        sleep 0.1
    done
}

# Start both threads
monitor_keys &
key_monitor_pid=$!  # Capture the PID of the key monitoring thread

check_inactivity &
inactivity_check_pid=$!  # Capture the PID of the inactivity checking thread

# Wait for both background processes
wait
