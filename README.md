# CustoPiZer for Pioreactor

This repo contains the scripts to serially modify an original RPi image (say, from the RPi Foundation), to add Pioreactor software and files. Builds currently target Raspberry Pi OS based on Debian Trixie (ships with Python 3.13).

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

Other local image helpers are `make_leader_worker_image.sh`, `make_worker_image.sh`, and `make_zero_w_worker_image.sh`.

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
  - `PIO_EXPORTS_DIR=/run/pioreactor/exports` (override to redirect `/exports/` storage)
  - `LG_WD=/run/pioreactor` and `TMPDIR=/tmp/` for temp paths
- Units reference it via `EnvironmentFile=/etc/pioreactor.env`.
- `/usr/local/bin/pio` and `/usr/local/bin/pios` source `/etc/pioreactor.env` before delegating into `/opt/pioreactor/venv/bin`, so non-interactive SSH commands and `nohup` inherit the same Pioreactor environment.

**Image Flavors → Targets**
- Leader: enable `pioreactor.target` + `pioreactor-leader.target`.
- Worker: enable `pioreactor.target` + `pioreactor-worker.target`.
- Leader+Worker: enable all three targets.

These are applied by the top-level `make_*_image.sh` scripts and in CI.

**Exports Location**
- `/exports/` is served from `/run/pioreactor/exports` (tmpfs, cleared on reboot). No exports are stored under `~/.pioreactor` unless you set `PIO_EXPORTS_DIR` to a persistent path, which will be symlinked into `/run/pioreactor/exports` on boot.

**FastCGI Socket**
- lighttpd connects to the Flask backend via Unix socket `RUN_PIOREACTOR/pioreactor_web.sock`.

**Cache**
- Transient UI/Huey/cache files live under `/run/pioreactor/cache` (created on boot via tmpfiles), replacing the previous `/tmp/pioreactor_cache`.

## Repository Purpose and Usage
- Builds Pioreactor-ready Raspberry Pi OS images from the official “lite” base by applying ordered customizations in `workspace/scripts/`.
- Produces four headless image flavors: leader, worker, leader+worker, and Zero W worker. The first three differ by enabled systemd targets; the Zero W worker is a worker-only profile built with `PIOREACTOR_IMAGE_PROFILE=zero_w_worker`, which is written to `/etc/pioreactor.env`, used for lower-pressure Huey startup, removes the periodic network-info timer, disables local access point support, and writes Zero W unit defaults into `unit_config.ini`. Build locally with Docker via `make_leader_image.sh`, `make_worker_image.sh`, `make_leader_worker_image.sh`, or `make_zero_w_worker_image.sh` (`bash <script> <pio_version> ./config.local`), which output zipped `.img` files in `workspace/`.
- GitHub Actions receives dispatches from upstream `pioreactor` releases, runs the same containerized build (see `action.yml`), and attaches the images to the latest release; nightly images are hosted at `https://nightly.pioreactor.com/`.
- Artifacts: `workspace/scripts/files/` (systemd units/targets/timers, bash helpers, lighttpd configs, tmpfiles rules, firstboot/everyboot scripts, NetworkManager profiles) and `src/` (CustoPiZer driver files used in the container build).
- End users download the desired image (leader/worker/leader_worker/zero_w_worker) from GitHub releases or nightlies, flash to an SD card, and boot; services come pre-enabled via targets (`pioreactor.target`, `pioreactor-leader.target`, `pioreactor-worker.target`, `pioreactor-web.target`) so Pioreactor CLI/UI work immediately.

## Shared Pioreactor assets
- The Pioreactor application repo owns shared provisioning assets under `packaging/shared-assets`, including SQL schema files, default config, exportable datasets, and UI descriptor YAML.
- Before building images, run `scripts/sync_pioreactor_assets.sh ../pioreactor`.
- The local `make_*_image.sh` scripts run this automatically using `PIOREACTOR_REPO` or `../pioreactor`.
- The GitHub workflow checks out the matching Pioreactor ref and syncs those assets before each image build.
- The synced destinations under `workspace/scripts/files/sql/`, `workspace/scripts/files/pioreactor/config.example.ini`, `workspace/scripts/files/pioreactor/exportable_datasets/`, `workspace/scripts/files/pioreactor/ui/`, and the shared leader service/config files are generated build inputs and intentionally ignored by Git here.
- CustoPiZer still owns image-only boot and hardware services such as firstboot, worker targets, local access point setup, and RP2040 loading.
