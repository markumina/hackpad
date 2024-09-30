#!/bin/bash
#set -x 

# Path to the touchpad input device
TOUCHPAD_DEVICE="/sys/devices/pci0000:00/0000:00:15.2/i2c_designware.1/i2c-2/i2c-VEN_0488:00/0018:0488:1072.0002/input/input17/inhibited"

# Function to disable the touchpad
disable_touchpad() {
    echo 1 > "$TOUCHPAD_DEVICE"
    #echo "d"  # Output 'd' for disabled
}

# Function to enable the touchpad
enable_touchpad() {
    echo 0 > "$TOUCHPAD_DEVICE"
    #echo "e"  # Output 'e' for enabled
}

# Cleanup function to handle script exit
cleanup() {
    enable_touchpad  # Ensure touchpad is re-enabled on exit
    kill "${key_monitor_pid}" 2>/dev/null  # Kill the key monitoring thread
    kill "${inactivity_check_pid}" 2>/dev/null  # Kill the inactivity checking thread
    exit 0
}

# Trap to catch all exit signals
trap cleanup EXIT

# Disable touchpad on script start
enable_touchpad

# Initialize variables
last_key_press_time=$(date +%s)
touchpad_disabled=1  # 1 if disabled, 0 if enabled
touched_while_in_delay=0  # 1 if touchpad was touched while in delay, 0 otherwise

# Thread for monitoring key presses
monitor_keys() {
    stdbuf -oL libinput debug-events | grep --line-buffered "KEYBOARD_KEY" | while read -r event; do
        #echo "k"  # Output 'k' for key press, prevent flood of errors if this device moves
        if [ -f "$TOUCHPAD_DEVICE" ] && [ "$(cat "$TOUCHPAD_DEVICE")" -eq 0 ]; then
            disable_touchpad
        fi
    done
}

# Thread for checking inactivity
check_inactivity() {
    while true; do
    
    # If touchpad disabled, then wait 0.5 seconds and then turn it on, prevent flood of errors if this device moves
    if [ -f "$TOUCHPAD_DEVICE" ] && [ "$(cat "$TOUCHPAD_DEVICE")" -eq 1 ]; then
        sleep 1.1
        if [ "$touched_while_in_delay" -eq 0 ]; then
            enable_touchpad
        else
            #echo "t"  # Output 't' for touched while in delay
            touched_while_in_delay=0
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
