## What RPi Imager actually writes to the image

For the current Pioreactor images served from `https://pioreactor.com/imager/os-list.json`, the OS entries use `init_format: "systemd"`. That means Raspberry Pi Imager customizes the SD card by writing a one-time boot script named `firstrun.sh` onto the FAT boot partition, and appending kernel arguments to `cmdline.txt` so the script runs on first boot.

### Settings we ask users to change in Imager

In our setup instructions, we ask users to set:

- `Content Repository = https://pioreactor.com/imager/os-list.json`
- `hostname = <user-chosen unique name>`
- localization settings
- `username = pioreactor`
- `password = raspberry`
- Wi-Fi SSID and password, if using Wi-Fi
- `Enable SSH = on`
- `Use password authentication = on`

Two of those do **not** modify the Raspberry Pi image itself:

- `Content Repository`
- `Disable telemetry`

Those are only local Raspberry Pi Imager application settings on the user’s computer.

---

## Files added or changed on the SD card

### 1. `firstrun.sh` is added to the boot partition

Imager writes a script called:

```text
/boot/firstrun.sh
```

This script runs once on first boot, applies the requested settings, then deletes itself.

### 2. `cmdline.txt` is modified

Imager appends this to `cmdline.txt`:

```text
systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target
```

If a Wi-Fi country is set, it also appends:

```text
cfg80211.ieee80211_regdom=<COUNTRY>
```

At the end of first boot, `firstrun.sh` removes itself and strips the `systemd.run=...` arguments back out of `cmdline.txt`.

---

## What `firstrun.sh` does

Below is the practical behavior, with placeholders.

### 1. Set the hostname

If the user enters a hostname like `leader`, `worker01`, or `pioreactor01`, the script applies it by either:

- calling Raspberry Pi’s helper:
  ```sh
  /usr/lib/raspberrypi-sys-mods/imager_custom set_hostname <HOSTNAME>
  ```

- or falling back to:
  ```sh
  echo <HOSTNAME> >/etc/hostname
  sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t<HOSTNAME>/g" /etc/hosts
  ```

### 2. Enable SSH

Because we tell users to enable SSH and choose password authentication, the script enables the SSH service:

```sh
/usr/lib/raspberrypi-sys-mods/imager_custom enable_ssh
```

or fallback:

```sh
systemctl enable ssh
```

### 3. Set the username and password

We ask users to set:

```text
username: pioreactor
password: raspberry
```

Imager does **not** write the plaintext password into the first-boot script. It hashes the password first, then the script applies the hashed password.

The script uses either:

```sh
/usr/lib/userconf-pi/userconf 'pioreactor' '<HASHED_PASSWORD>'
```

or fallback logic like:

```sh
echo "$FIRSTUSER:<HASHED_PASSWORD>" | chpasswd -e
usermod -l "pioreactor" "$FIRSTUSER"
usermod -m -d "/home/pioreactor" "pioreactor"
groupmod -n "pioreactor" "$FIRSTUSER"
```

So the net effect is:

- rename the default first user to `pioreactor`
- set its password to the hash of `raspberry`
- update the user’s home directory
- rename the primary group to `pioreactor`

### 4. Configure Wi-Fi, if provided

If the user enters Wi-Fi credentials, the script configures wireless networking.

Preferred path:

```sh
/usr/lib/raspberrypi-sys-mods/imager_custom set_wlan '<SSID>' '<WIFI_PSK_HASH>' '<COUNTRY>'
```

Fallback path writes `/etc/wpa_supplicant/wpa_supplicant.conf` like this:

```conf
country=<COUNTRY>
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
ap_scan=1

update_config=1
network={
    ssid="<SSID>"
    key_mgmt=WPA-PSK SAE
    psk=<WIFI_PSK_HASH>
    ieee80211w=1
}
```

Then it unblocks Wi-Fi:

```sh
chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
rfkill unblock wifi
for filename in /var/lib/systemd/rfkill/*:wlan ; do
    echo 0 > $filename
done
```

If the network is hidden, it also adds:

```conf
scan_ssid=1
```

### 5. Set localization options

If the user changes keyboard layout or timezone, the script applies them.

Preferred path:

```sh
/usr/lib/raspberrypi-sys-mods/imager_custom set_keymap '<KEYBOARD_LAYOUT>'
/usr/lib/raspberrypi-sys-mods/imager_custom set_timezone '<TIMEZONE>'
```

Fallback path:

```sh
rm -f /etc/localtime
echo "<TIMEZONE>" >/etc/timezone
dpkg-reconfigure -f noninteractive tzdata
```

and for keyboard:

```conf
XKBMODEL="pc105"
XKBLAYOUT="<KEYBOARD_LAYOUT>"
XKBVARIANT=""
XKBOPTIONS=""
```

written to:

```text
/etc/default/keyboard
```

followed by:

```sh
dpkg-reconfigure -f noninteractive keyboard-configuration
```

### 6. Clean itself up

At the end of first boot, the script removes itself:

```sh
rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0
```

---

## Copy/paste example for other projects

If you want to reproduce the same pattern in another Raspberry Pi project, this is the main shape of it:

```sh
#!/bin/sh

set +e

CURRENT_HOSTNAME=$(cat /etc/hostname | tr -d " \t\n\r")
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
   /usr/lib/raspberrypi-sys-mods/imager_custom set_hostname <HOSTNAME>
else
   echo <HOSTNAME> >/etc/hostname
   sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t<HOSTNAME>/g" /etc/hosts
fi

FIRSTUSER=$(getent passwd 1000 | cut -d: -f1)
FIRSTUSERHOME=$(getent passwd 1000 | cut -d: -f6)

if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
   /usr/lib/raspberrypi-sys-mods/imager_custom enable_ssh
else
   systemctl enable ssh
fi

if [ -f /usr/lib/userconf-pi/userconf ]; then
   /usr/lib/userconf-pi/userconf '<USERNAME>' '<HASHED_PASSWORD>'
else
   echo "$FIRSTUSER:<HASHED_PASSWORD>" | chpasswd -e
   if [ "$FIRSTUSER" != "<USERNAME>" ]; then
      usermod -l "<USERNAME>" "$FIRSTUSER"
      usermod -m -d "/home/<USERNAME>" "<USERNAME>"
      groupmod -n "<USERNAME>" "$FIRSTUSER"
   fi
fi

if [ -n "<SSID>" ]; then
   if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
      /usr/lib/raspberrypi-sys-mods/imager_custom set_wlan '<SSID>' '<WIFI_PSK_HASH>' '<COUNTRY>'
   else
      cat >/etc/wpa_supplicant/wpa_supplicant.conf <<'WPAEOF'
country=<COUNTRY>
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
ap_scan=1

update_config=1
network={
    ssid="<SSID>"
    key_mgmt=WPA-PSK SAE
    psk=<WIFI_PSK_HASH>
    ieee80211w=1
}
WPAEOF
      chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
      rfkill unblock wifi
   fi
fi

rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0
```

And `cmdline.txt` must contain:

```text
systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target
```

---

## Pioreactor-specific values

For Pioreactor, the placeholders are typically:

```text
<USERNAME> = pioreactor
<PASSWORD> = raspberry
<HASHED_PASSWORD> = hash of "raspberry" generated by Imager
<HOSTNAME> = leader, worker01, pioreactor01, etc.
<SSID> = user’s network SSID
<WIFI_PSK_HASH> = hashed/derived Wi-Fi PSK
<COUNTRY> = user’s Wi-Fi regulatory country
```

If you want, I can turn this into:
1. a tighter docs-ready MDX section, or
2. a table with columns `Imager setting` / `Image mutation` / `File changed` / `Example output`.