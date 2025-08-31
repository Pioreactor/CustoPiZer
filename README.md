# CustoPiZer for Pioreactor

This repo contains the scripts to serially modify an original RPi image (say, from the RPi Foundation), to add Pioreactor software and files.

### How does it work?

When a new release is made in [pioreactor/pioreactor](https://github.com/Pioreactor/pioreactor), a dispatch is sent to this repo using Github Actions, including the version of Pioreactor software to use. A new workflow is kicked off that builds the images, creates a new release, and attaches the images to the release.

The following url will point to a specific asset in the latest release:
```
https://github.com/pioreactor/custopizer/releases/latest/download/<asset_name>
```

### Nightlies

Available at [nightly.pioreactor.com/](https://nightly.pioreactor.com/)

### Local build

With Docker running:

```
bash make_leader_image.sh <version> ./config.local
```

**Systemd Targets**
- Common: `pioreactor.target` — pulls up shared services (`pioreactor-web.target`, `avahi_aliases`, `everyboot`, `firstboot`, `wifi_powersave`, `write_ip`, `local_access_point`, `pioreactor_startup_run@monitor`, `network-info.timer`).
- Leader: `pioreactor-leader.target` — adds `mosquitto`, `pioreactor_startup_run@mqtt_to_db_streaming`, `backup-database.timer`, `ui-exports-cleanup.timer`.
- Worker: `pioreactor-worker.target` — adds `load_rp2040`.
- Web: `pioreactor-web.target` — groups `lighttpd.service` and `huey.service` for joint start/stop/restart.

Enable only the appropriate targets during image build; individual units are not enabled directly in scripts anymore.

**Timers (replaces cron)**
- `network-info.timer`: updates `/boot/firmware/network_info.txt` every 5 minutes.
- `backup-database.timer`: weekly database backup via `pio run backup_database`.
- `ui-exports-cleanup.timer`: monthly cleanup of exported files in `/run/pioreactor/exports`.

Check with `systemctl list-dependencies pioreactor*.target` and `systemctl list-timers` on a device.

**Web Stack Ops**
- Restart both web services: `sudo systemctl restart pioreactor-web.target`
- Start/stop both: `sudo systemctl start|stop pioreactor-web.target`

**Environment File**
- Shared env for units at `/etc/pioreactor.env`:
  - `DOT_PIOREACTOR=/home/pioreactor/.pioreactor` (used to locate configs and data)
  - `RUN_PIOREACTOR=/run/pioreactor` (tmpfs for ephemeral runtime files)
  - `LG_WD=/run/pioreactor` and `TMPDIR=/tmp/` for temp paths
- Units reference it via `EnvironmentFile=/etc/pioreactor.env`.

**Image Flavors → Targets**
- Leader: enable `pioreactor.target` + `pioreactor-leader.target`.
- Worker: enable `pioreactor.target` + `pioreactor-worker.target`.
- Leader+Worker: enable all three targets.

These are applied by the top-level `make_*_image.sh` scripts and in CI.

**Exports Location**
- `/exports/` is served from `/run/pioreactor/exports` (tmpfs, cleared on reboot). No exports are stored under `~/.pioreactor`.

**FastCGI Socket**
- lighttpd connects to the Flask backend via Unix socket `RUN_PIOREACTOR/pioreactor_web.sock`.

**Cache**
- Transient UI/Huey/cache files live under `/run/pioreactor/cache` (created on boot via tmpfiles), replacing the previous `/tmp/pioreactor_cache`.
