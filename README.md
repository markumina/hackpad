# hackpad (a small passion project)
## (XPS13, 2024, but adjust for your own Linux machine)

I recently bought a Dell XPS13, and the touchpad has been giving me nightmares by clicking on random parts of my screen, or random places in an editor while I type.

Tech support was surpringly helpful with the webcam, but not the touchpad, nor the display periodic freezing:

Tangent: To fix the display periodic freezing, update file '/etc/default/grub' to contain:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.enable_psr=0"
```
This shuts off Panel Self Refresh, which will increase power consumption a bit, but prevents screen glitching and periodic freezing.

I dug through all the settings that I could find in Wayland. Enabling the following did help, but it only disables `mouse` movement while typing, it does not disable `click`. You can still accidentally click by having your palm tap the touchpad. It's annoying. Anyway this is the setting that helps a bit, but it doesn't disable the trackpad long enough after a keypress. Leave this on (the script auto-sets it at startup) because it can prevent an issue where sometimes a finger needs to be lifted and placed again before the trackpad responds:
```
gsettings set org.gnome.desktop.peripherals.touchpad disable-while-typing true
```

After that, I tweaked every setting, switched from Wayland to X11 and tweaked all those settings - no great results.

So I stuck together a little script that has helped a lot, for me. The debug-events based monitoring is what I settled on. There were other ways to disable the touchpad, namely:

```gsettings get org.gnome.desktop.peripherals.touchpad send-events 'enabled'```

.. but it left the touchpad in an odd state where you had to lift your finger and put it back down again for it to start accepting motion - something seems broken. The debug-events monitor does not have that issue.

The script consumes very little CPU, and works fine for me. If you want to use it, you'll have to find your path to enabling/disabling your touchpad.

To do so:

1. Search the device list for Touch or Touchpad or 'ouch':
```
cat /proc/bus/input/devices | grep -A10 -B1 ouch
```

Example output:

```
markumina@markxps:~/Documents/hackpad$ cat /proc/bus/input/devices | grep -A10 -B1 ouch
I: Bus=0018 Vendor=0488 Product=1072 Version=0100
N: Name="VEN_0488:00 0488:1072 Touchpad"
P: Phys=i2c-VEN_0488:00
S: Sysfs=/devices/pci0000:00/0000:00:15.2/i2c_designware.1/i2c-2/i2c-VEN_0488:00/0018:0488:1072.0002/input/input17
U: Uniq=
H: Handlers=mouse2 event7 
B: PROP=5
B: EV=1b
B: KEY=e520 10000 0 0 0 0
B: ABS=2e0800000000003
B: MSC=20
```
So my path is:
```
/devices/pci0000:00/0000:00:15.2/i2c_designware.1/i2c-2/i2c-VEN_0488:00/0018:0488:1072.0002/input/input17
```

3. Take path above and:
   a. Add prefix /sys/
   b. Remove the input17 (or inputxx - whatever number it may be, it's dynamic so the script ignores it)
   c. Place this path in hackpad.sh `TOUCHPAD_DEVICE`, making sure to keep: "/${TOUCHPAD_DEVICE}/inhibited" at the end

For me that results in:

```
TOUCHPAD_DEVICE="/sys/devices/pci0000:00/0000:00:15.2/i2c_designware.1/i2c-2/i2c-VEN_0488:00/0018:0488:1072.0002/input/${TOUCHPAD_DEVICE}/inhibited"
```

4. sudo vi /etc/systemd/system/hackpad.service

5. Paste contents below:
```
[Unit]
Description=Hackpad Touchpad Management Script

[Service]
ExecStart=/opt/hackpad/hackpad.sh
Restart=always
RestartSec=5  # Optional: time to wait before restarting (in seconds)

[Install]
WantedBy=multi-user.target
```

6. Place your hackpad.sh file in /opt/hackpad.sh

7. Enable the service and reload:

```
sudo systemctl daemon-reload
sudo systemctl enable hackpad.service
sudo systemctl start hackpad.service
systemctl status hackpad.service
```

Also check that it restarted automatically on reboot.

Hit me up: mark.umina at gmail dot com.

