# hackpad
## A small nerdy project
### (XPS13, 2024, but adjust for your own Linux machine)

I recently bought a Dell XPS13, and the touchpad has been giving me nightmares by clicking on random parts of my screen, or random places in an editor while I type.

Tech support was surpringly helpful with the webcam, but not the touchpad, nor the display periodic freezing:

Tangent: To fix the display periodic freezing, update file `/etc/default/grub` to contain:
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

The script consumes very little CPU, and works fine for me. It discovers the touchpad from `/proc/bus/input/devices`, then inhibits it through `/sys/class/input/inputN/inhibited`, so there is no Dell-specific sysfs path to paste into the script.

## Build a deb

```
./build-deb.sh
```

That creates:

```
dist/hackpad_0.1.0_all.deb
```

Install it with:

```
sudo apt install ./dist/hackpad_0.1.0_all.deb
```

The package installs:

```
/opt/hackpad/hackpad.sh
/etc/systemd/system/hackpad.service
```

The package post-install step reloads systemd, enables `hackpad.service`, and restarts it.

Check status with:

```
systemctl status hackpad.service
```
Check that it restarted automatically on reboot by typing while attempting to use the trackpad.


`OPTIONAL ADJUSTMENTS`

8. I've noticed that my cursor is choppy, which I've found can happen because of Intel's dynamic refresh rate. Make it constant (this will burn more juice!). 

   Force constant refresh by disabling saving features:

   A. `vi /etc/default/grub`

   B. Find the line starting with GRUB_CMDLINE_LINUX_DEFAULT and add the following: `i915.enable_psr=0`, for me:

        `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.enable_psr=0"`

   D. Save and run: `sudo update-grub`

   E. Run `sudo reboot now`

Hit me up: mark.umina at gmail dot com.

