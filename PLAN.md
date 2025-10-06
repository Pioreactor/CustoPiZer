Pioreactor Image Modernization Plan

- Repos: CustoPiZer (this repo), upstream core at https://github.com/pioreactor/pioreactor
- Context: Read alongside ISSUES.md for rationale, mappings, and constraints.
- Strategy: Land small, testable changes in phases; minimize user friction; consolidate behavior around `pio` and systemd targets.

 Progress Log (current)
- Removed cache-prep oneshot: deleted `create_diskcache.service` and script.
- tmpfiles provisions `/run/pioreactor/{exports,cache}` and pre-creates `local_intermittent_pioreactor_metadata.sqlite` and `huey.db` with `0660`, owner `pioreactor:www-data`.
- Group-writability hardened: added `UMask=0007` to `huey.service` and `lighttpd.service` and default ACLs applied to `/run/pioreactor/cache` in `everyboot.sh`.
- Deterministic ordering: `huey.service` now starts After `everyboot.service`.
- Added `pioreactor-web.target` to group `lighttpd` and `huey`; both declare `PartOf=pioreactor-web.target` for joint restarts.
- Build ensures `setfacl` present: `acl` package installed explicitly.
- Leader+worker boots; API endpoints respond; UI accessible.
- Backend API installs via pip; FastCGI points to packaged entrypoint.
- Jobs run; plugins work; `.pioreactor` layout confirmed.
- `/etc/pioreactor.env` templatized via `18-create-pioreactor-env.sh`; install also drops a profile.d snippet so interactive shells inherit Pioreactor vars and PATH.
- `14-install-crontabs.sh` now intentionally no-ops so the new systemd timers own all scheduling.
- Phase 4 deliverables merged: UI is packaged, services point to module entrypoints, and legacy tarball tooling is removed.

Secondary Goals Addressed (performance and portability)
- Decrease boot time and perceived readiness.
- Decrease `pio <cmd>` startup latency.
- Reduce tight coupling to Raspberry Pi OS specifics.

**Phases Summary**
- Phase 1: Targets, EnvironmentFile, and Timers (start here)
  - Add `pioreactor-web.target` for web stack management (restart lighttpd + huey together).
- Phase 3: Replace `pio workers add` shell-out with native Python
- Phase 4: Package UI via pip; update services to module entrypoints (complete)
- Phase 5: Unified software; produce leader/worker/leader_worker images
- Phase 6: Decommission legacy bash; dedupe services
- Phase 7: Documentation and release

**Starting Issue: Phase 1 — Targets, EnvironmentFile, Timers**
- Why first: Unblocks later work, low risk, no upstream dependency, clarifies service topology, and improves observability by replacing cron.

- Objectives
  - Establish `pioreactor.target` (common), `pioreactor-leader.target`, `pioreactor-worker.target` and map existing services as per ISSUES.md.
  - Introduce `/etc/pioreactor.env` used by all relevant units; include `DOT_PIOREACTOR=/home/pioreactor/.pioreactor`, `RUN_PIOREACTOR=/run/pioreactor`, and set `LG_WD=/run/pioreactor`.
  - Replace cron with systemd timers (network-info, backup-database, ui-exports-cleanup).

- Changes in CustoPiZer
  - Add target unit files under `workspace/scripts/files/system/systemd/`:
    - `pioreactor.target`: [Install] WantedBy=multi-user.target
    - `pioreactor-leader.target`: [Install] WantedBy=multi-user.target
    - `pioreactor-worker.target`: [Install] WantedBy=multi-user.target
  - Wire services via target Wants (targets declare `Wants=...`), and stop enabling services directly in scripts:
    - Common (`pioreactor.target` Wants): `pioreactor-web.target`, `avahi_aliases.service`, `everyboot.service`, `firstboot.service`, `wifi_powersave.service`, `write_ip.service`, `local_access_point.service`, `pioreactor_startup_run@monitor.service`.
    - Web (`pioreactor-web.target` Wants): `lighttpd.service`, `huey.service`.
    - Leader (`pioreactor-leader.target` Wants): `mosquitto.service`, `pioreactor_startup_run@mqtt_to_db_streaming.service`.
    - Worker (`pioreactor-worker.target` Wants): `load_rp2040.service`.
  - Add timers/services:
    - `network-info.service` + `network-info.timer` (common): runs write_ip helper; `OnCalendar=*:0/5`.
    - `backup-database.service` + timer (leader): replaces `pio run backup_database`; `OnCalendar=Sun *-*-* 00:00` (weekly) or keep prior cadence.
    - `ui-exports-cleanup.service` + timer (leader): cleans export dir; `OnCalendar=monthly`.
  - Introduce `/etc/pioreactor.env` creation in the image build (new step writes `DOT_PIOREACTOR=/home/pioreactor/.pioreactor`), and update units to reference `EnvironmentFile=/etc/pioreactor.env` (replace `/etc/environment`).
    - Status: done via `18-create-pioreactor-env.sh`, which installs the template and profile.d loader for interactive shells.
  - Add tmpfiles rules to provision `/run/pioreactor/{exports,cache}` on boot and move ephemeral data there.
    - Status: done; includes pre-creating cache DB files with correct perms.
  - Stop enabling units directly in `workspace/scripts/04-install-services.sh`, `11-add-firstboot.sh`, and `13-add-everyboot.sh`. Instead, only enable the appropriate target(s).
    - Status: partial; cache-prep unit removed and dependencies cleaned from targets and startup units.
  - Keep cron jobs for one release behind a build flag, then remove `14-install-crontabs.sh` when timers are verified.
    - Status: done; script now logs a skip message and relies entirely on timers.
  - No role files required; role is determined by image flavor (leader.img, worker.img, leader_worker.img).

- Upstream (pioreactor) dependencies
  - None required for Phase 1; timers can call existing helpers (`pio run backup_database` remains the executable invoked by the leader timer).

- Testing
  - Build image; confirm `systemctl is-enabled` on targets; verify constituent units appear in `systemctl list-dependencies pioreactor*.target`.
  - Verify timers via `systemd-analyze calendar` and observe `journalctl -u *.timer -u *.service` after trigger.
  - Confirm `DOT_PIOREACTOR`, `RUN_PIOREACTOR`, and `LG_WD` are present in service env (`systemctl show -p Environment ...`).
  - Confirm `/run/pioreactor` subdirs exist at boot (tmpfiles) and lighttpd uses `/run/pioreactor/pioreactor_web.sock`.
  - Lab test: Boot a device, verify monitor is running (`systemctl status pioreactor_startup_run@monitor`), timers fire, and `write_ip` updates `/boot/firmware/network_info.txt`.

- Acceptance Criteria
  - Targets installed and enabled; boot brings up the same services as before by role.
  - Timers replace cron jobs; no regression in backup/cleanup/network info behaviors.
  - Units reference `/etc/pioreactor.env`; services continue to locate `config.ini` via `DOT_PIOREACTOR`.
  - Performance: `systemd-analyze blame` shows no new long-running dependencies; timer services complete quickly (<1s typical).

Phase 1 — Next PR Outline (CustoPiZer)
- Add targets: create `workspace/scripts/files/system/systemd/pioreactor.target`, `pioreactor-leader.target`, `pioreactor-worker.target` with `Wants=` lists per mapping above and `[Install] WantedBy=multi-user.target`.
- Add timers: add `workspace/scripts/files/system/systemd/network-info.service` + `.timer`; leader-only `backup-database.*` and `ui-exports-cleanup.*` (point ExecStart to existing helpers).
- Add env: new script step `workspace/scripts/xx-create-pioreactor-env.sh` that writes `/etc/pioreactor.env` with `DOT_PIOREACTOR=/home/pioreactor/.pioreactor`.
- Switch enablement: edit `workspace/scripts/04-install-services.sh`, `11-add-firstboot.sh`, `13-add-everyboot.sh` to stop enabling individual units; instead, enable only the target(s).
- Deduplicate: remove the duplicate copy of `pioreactor_startup_run@.service` in `04-install-services.sh` while touching the file.
- Image flavors: adjust `make_leader_image.sh`, `make_worker_image.sh`, `make_leader_worker_image.sh` to `systemctl enable` the correct target(s) during build.

**Phase 2: Harden First-Boot and Every-Boot (bash)**
- Objectives
  - Keep `firstboot_*.sh` and `everyboot.sh` as bash for speed and early-boot simplicity.
  - Apply hardening: `set -euo pipefail`; explicit timeouts/retries for external calls; idempotent guards with simple file/flag checks; ensure they are fast oneshots and avoid blocking `network-online.target`; read env via `/etc/pioreactor.env`; rely on tmpfiles for directories.

- Changes in CustoPiZer
  - Review and update `workspace/scripts/files/bash/firstboot_*.sh` and `everyboot.sh` per the above.
  - Ensure `firstboot.service` and `everyboot.service` reference `/etc/pioreactor.env` and remain minimal oneshots.
  - Keep service dependencies (After/Before) identical.
  - Document expectations in this repo’s README/ISSUES.

- Testing & Acceptance
  - Boot both leader and worker images; verify idempotent runs, presence of keys/config/db seeds, and logs.
  - Confirm that re-running services does not alter state unexpectedly.
  - Lab test: Place a sample `/boot/firmware/config.ini`, reboot, verify merge occurred and file removed; check Wi‑Fi forced on.
  - Performance: First-boot oneshot completes quickly after network-online (<5s typical) and does not block unrelated services.

**Phase 3: Native `pio workers add` (no shell-out)**
- Objectives
  - Replace shell script invocation with a robust Python implementation.

- Upstream tasks (pioreactor)
  - Implement `pio workers add <hostname> [--password <pw>] [--address <addr>]` using `sshpass`, `ssh-copy-id`, `ssh`, and `scp` with timeouts and clear errors.
  - Steps: connectivity checks; config updates on leader (`cluster.addresses`), copy shared/unit configs to worker, chrony hints, reboot worker, bounded retries.
  - Tests: unit tests for argument handling and command building; dry-run mode; doc examples.

- Changes in CustoPiZer
  - Remove installation of `add_new_pioreactor_worker_from_leader.sh` and references.

- Testing & Acceptance
  - Lab test: join a fresh worker to a leader using the new CLI; confirm presence on UI and config sync.
  - Performance: End-to-end adoption time dominated by network/ssh; CLI cold start <200ms on target hardware where feasible.

**Phase 4: Package UI via pip; update services (complete)**
- Objectives
  - Move the web API (UI) to a proper Python package in upstream; keep lighttpd; point services at module entrypoints.
  - Both leader and worker images install and run the web API. Workers enable lighttpd's `api-only` config (no static), leaders serve static assets.

- Upstream tasks (pioreactor)
  - Package UI inside `pioreactor`: include Flask app, FastCGI/WSGI entrypoint, huey tasks (`pioreactor.web.tasks.huey`).
  - Remove reliance on `.env`; load env from process (i.e., `DOT_PIOREACTOR`) or config.
  - Declare dependencies; ensure static assets are included in the wheel.

- Changes in CustoPiZer
  - Lighttpd integration updated (done):
    - Use lighttpd-managed FastCGI: `bin-path=/usr/bin/pioreactor-fcgi`, socket `/run/pioreactor/pioreactor_web.sock`.
    - Rewrite `/api`, `/unit_api`, `/mcp` → `/api.fcgi$1`.
    - Leaders serve static via alias `/static/` → `/usr/share/pioreactorui/static` with SPA fallback to `/static/index.html`.
    - Leaders expose `/exports/` → `/run/pioreactor/exports` (ephemeral).
    - Workers enable `api-only` filter to expose ONLY `/unit_api`.
  - Services and scripts (done):
    - `huey.service` updated to `pioreactor.web.tasks.huey`.
    - `08-install-pioreactorui.sh` no longer fetches tarballs or `.env`; installs lighttpd + config.
    - `06-install-pioreactor.sh` manages `/usr/share/pioreactorui/static` symlink to packaged assets; no exports under `${DOT_PIOREACTOR}`.
    - Cleanup timer points to `/run/pioreactor/exports`.
    - Legacy `update_ui.sh` no longer installed.

- Testing & Acceptance
  - Verify UI responds via lighttpd; huey consumes tasks; upgrades via pip do not disturb user data.
  - Lab test: Upgrade the UI wheel on a leader, confirm no loss of user exports (now under `DOT_PIOREACTOR`) and huey restarts cleanly.
  - Performance: Ensure lighttpd startup is not gated by long oneshots; huey starts independently; UI import path is lean.

Phase 4 — Status in this repo (complete)
- Packaging landed upstream. Downstream now:
  - Serves static from packaged assets via symlink; no files under `/var/www/pioreactorui`.
  - Restricts worker HTTP surface to `/unit_api` only; leaders expose `/api`, `/unit_api`, `/mcp`.
  - Exports live under `/run/pioreactor/exports` (tmpfs, cleared on reboot) and are cleaned by timer.
  - Caching tuned for SPA shell vs hashed assets.

**Phase 5: Unified software; produce leader/worker/leader_worker images**
- Objectives
  - Ship the same software on all images; produce three image flavors differing only by enabled targets.

- Changes in CustoPiZer
  - Remove scattered `LEADER`/`WORKER` branches in install scripts; install all requisite packages on all images.
  - At image build, enable targets according to flavor:
    - leader.img → enable `pioreactor.target` + `pioreactor-leader.target`
    - worker.img → enable `pioreactor.target` + `pioreactor-worker.target`
    - leader_worker.img → enable all three targets

- Upstream tasks (pioreactor)
  - `pio role set leader|worker|leader_worker` remains optional (useful for advanced users switching roles), but not required for headless provisioning.

- Testing & Acceptance
  - Validate each image flavor boots with the correct services; ensure sets match the mapping in ISSUES.md.
  - Lab test: Boot leader.img (mosquitto + mqtt_to_db_streaming present), worker.img (rp2040 loader present), leader_worker.img (union); monitor present on all.
  - Performance: Compare `systemd-analyze critical-chain` across flavors; target improvements in boot path.

**Phase 6: Decommission Legacy Bash; dedupe services**
- Objectives
  - Remove/update legacy scripts and duplicated unit copies.

- Changes in CustoPiZer
  - Stop copying bash scripts that have Python replacements (update `12-add-pioreactor-bash-scripts.sh`).
  - Remove duplicated `pioreactor_startup_run@.service` copy in `04-install-services.sh`.
  - Remove cron install step when timers are proven.

- Testing & Acceptance
  - CI/build sanity; boot tests confirm no missing functionality.
  - Performance: Removing shell glue reduces process spawn overhead for recurring tasks.

**Phase 7: Documentation and Release**
- Objectives
  - Document new service topology, role switching, and upgrade paths; cut a release.

- Deliverables
  - Docs: user-facing guide for adding workers (`pio workers add`), role selection, and UI upgrades via pip.
  - Release notes: deprecations (bash removal, tarball UI), new timers, unified image.
  - Performance notes: measured boot and CLI startup improvements; any knobs exposed to users.

Performance and Portability Work (Cross-Cutting)
- Boot-time reduction (CustoPiZer)
  - Audit unit dependencies: keep `After=network-online.target` only where strictly required; avoid chaining units unnecessarily (e.g., huey shouldn’t block lighttpd unless needed).
  - Prefer `Type=oneshot` for setup tasks and remove `RemainAfterExit` unless necessary.
  - Avoid unnecessary oneshots; rely on tmpfiles for ephemeral dirs.
  - Remove redundant service copies and duplicate enablement to reduce unit churn at boot.
  - Measure with `systemd-analyze blame` and `systemd-analyze critical-chain`; set a target delta improvement (e.g., -20%).

- `pio` CLI cold-start reduction (Upstream: pioreactor)
  - Profile imports: `python -X importtime -m pio --help` and record hotspots.
  - Defer heavy imports to command execution scope (lazy import within subcommands).
  - Avoid importing Flask/UI/huey paths in the CLI root; import only when those commands are invoked.
  - Replace `pkg_resources` usage with `importlib.metadata` where possible.
  - Precompile bytecode at install (`python -m compileall -q <package>`) in the image build to reduce on-device compilation.
  - Keep console_scripts minimal; avoid global side effects at import time.

- Reduce Raspberry Pi OS coupling (Both repos)
  - Centralize SoC-specific tweaks (overlays, `/boot/config.txt` edits) in a single script; gate on hardware detection.
  - Minimize reliance on `/boot/firmware` paths by funneling through a `BOOT_MOUNT` variable (default to RPi path), so alternate distros can override.
  - Prefer NetworkManager-native configs (already used) and generic Debian packages.
  - Avoid raspi-specific services (already masking many) and use standards (systemd timers, targets) for portability.

**Cross-Repo Work Items (Checklist)**
- CustoPiZer
  - [x] Add targets and wire services to them
  - [x] Add `/etc/pioreactor.env` and switch units to `EnvironmentFile`
  - [x] Add timers and disable cron
  - [ ] Harden `firstboot`/`everyboot` bash scripts (set -euo, idempotent, timeouts/retries, avoid blocking network-online, read env via `/etc/pioreactor.env`, use tmpfiles)
  - [x] Switch UI install to pip and adjust services
  - [ ] Remove legacy bash installs and duplicate service wiring
  - [ ] Remove role conditionals

- Upstream (pioreactor)
  - [ ] Implement native `pio workers add`
  - [ ] Implement `pio role set`
  - [x] Package UI within `pioreactor` (FastCGI + huey entrypoints)
  - [ ] Update `pio plugins` parity logic (optional follow-up)
  - [ ] Tests and docs for new CLIs and paths

**Risks and Mitigations**
- Users on older images won’t auto-migrate: mitigated by clear re-image guidance and simplified add-worker flow.
- Service order regressions: mitigated by keeping the same After/Wants relationships and validating with `systemd-analyze`.
- UI deployment differences: mitigated by packaging and stable entrypoints; keep lighttpd to avoid proxy churn.
