Pioreactor Image Issues and Modernization Plan

- Owner: CustoPiZer image build (workspace/scripts)
- Scope: Leader/worker images, UI deployment, systemd topology, bash tooling
- Goal: Shift to package-managed Python, unify images, reduce bash, clarify services
- Secondary goals:
  - decrease start up time.
  - decrease `pio X` start up time.
  - reduce being tied to Raspberry Pi OS.

Decisions Confirmed
- UI packaging via pip is desired; lighttpd remains.
- Keep environment variables (e.g., `DOT_PIOREACTOR` to locate `config.ini`).
- CLI namespace is `pio` (e.g., `pio run ...`, `pio plugins install ...`).
- Single image should support roles leader, worker, and leader+worker.
- `avahi_aliases` may run on both leader and worker.
- Replace cron with systemd timers.
- Keep `sshpass` for now unless a clearly easier user flow is demonstrated.
 - Ephemeral runtime lives under `/run/pioreactor` exposed via `RUN_PIOREACTOR`; `LG_WD` points to `/run/pioreactor`.
 - UI exports are served from `/run/pioreactor/exports` (cleared on reboot). Nothing under `~/.pioreactor/web/exports`.
- lighttpd FastCGI socket is `/run/pioreactor/pioreactor_web.sock`.

Progress Update (current)
- Removed `create_diskcache.service` and its script; rely on tmpfiles for `/run/pioreactor/{exports,cache}`.
- tmpfiles now also pre-creates cache DBs with correct perms: `local_intermittent_pioreactor_metadata.sqlite` and `huey.db` (0660, `pioreactor:www-data`).
- Added `UMask=0007` to `huey.service` and `lighttpd.service` for group-writable artifacts.
- `everyboot.sh` applies default ACLs to `/run/pioreactor/cache` so new files (WAL/SHM) are always group `rw` regardless of umask.
- `huey.service` now `After=everyboot.service` to ensure ACLs are in place before it starts.
- Explicitly install `acl` package during image build to provide `setfacl`.

Repository Ground Truth (CustoPiZer)
- Units and targets under `workspace/scripts/files/system/systemd/` include services, timers, and targets:
  - Services: `avahi_aliases.service`, `everyboot.service`, `firstboot.service`, `huey.service`, `lighttpd.service`, `load_rp2040.service`, `local_access_point.service`, `log-failure@.service`, `pioreactor_startup_run@.service`, `wifi_powersave.service`, `write_ip.service`.
  - Timers: `network-info.timer`, `backup-database.timer`, `ui-exports-cleanup.timer` with matching `.service` units.
  - Targets: `pioreactor.target`, `pioreactor-leader.target`, `pioreactor-worker.target` wire services via Wants.
- Enablement is target-based:
  - `workspace/scripts/04-install-services.sh` installs targets and tmpfiles, and enables `pioreactor.target` plus role-specific targets based on `LEADER`/`WORKER`.
  - `workspace/scripts/11-add-firstboot.sh`/`13-add-everyboot.sh` install their units but do not directly enable them.
  - `workspace/scripts/14-install-crontabs.sh` intentionally skips crontab installation (timers replace cron).
- Worker-only avahi service file exists at `workspace/scripts/files/system/avahi/pioreactor_worker.service`.
- tmpfiles.d: `workspace/scripts/files/system/tmpfiles.d/pioreactor.conf` provisions `/run/pioreactor/{exports,cache}` at boot.

1) Bash Reliance and Brittleness
- Problem: Fixed bash scripts ship in the image and don’t update with core software. Hard to test/change; logic scattered across many files.
- Evidence: `workspace/scripts/files/bash/*.sh` (e.g., `add_new_pioreactor_worker_from_leader.sh`, `update_ui.sh`, `firstboot_*.sh`, `everyboot.sh`, `local_access_point.sh`). Copied into `/usr/local/bin` by `12-add-pioreactor-bash-scripts.sh` and others.
- Impact: Bug fixes require re-imaging; limited testability; role logic duplicated; fragile error handling and env assumptions.
- Direction:
  - Move logic into Python CLIs under the existing `pio` namespace (shipped in `pioreactor` and, later, UI package).
  - Keep minimal systemd oneshots that invoke Python entrypoints (not shell), using `EnvironmentFile` to expose `DOT_PIOREACTOR` and other env.
  - No backward-compat shims required: we will replace shipping bash scripts and require users to re-image.
  - Replace cron tasks with systemd timers for better observability and dependency control.
- First candidates to port:
  - Cluster join: there is already a `pio workers add` that currently shells out to `add_new_pioreactor_worker_from_leader.sh`. Re-implement that command natively in Python (SSH, config sync, chrony, reboot). Keep `sshpass` initially.
  - First boot / every boot: `pio system first-boot` and `pio system every-boot` oneshots (idempotent, read `DOT_PIOREACTOR`).
  - Avahi aliasing helper: expose a more general networking CLI (e.g., `pio net advertise` or `pio mdns advertise`) that supervises `avahi-publish` with retries.
  - UI update flow: superseded by pip-installed UI (see 2).

2) UI Deployment Outside Python Packaging
- Problem: UI currently lives in `/var/www/pioreactorui` and updates via tarball swap (`08-install-pioreactorui.sh`, `files/bash/update_ui.sh`). Huey/lighttpd services point into that folder.
- Impact: Updates bypass pip versioning, risk drift and permissions churn; `.env` juggling; harder rollbacks.
- Direction:
  - Package the UI as a Python distribution (name TBD; may fold into one wheel with core later). Include Flask app, tasks, static assets, and CLIs.
  - Keep lighttpd. Treat it as reverse proxy/FastCGI frontend to the packaged app entrypoint (no more mutable app code in `/var/www`).
  - Use a systemd `EnvironmentFile` to surface `DOT_PIOREACTOR` and other env, not `.env` files inside app dirs.
  - Store user-persistent artifacts under `~/.pioreactor` (anchored by `DOT_PIOREACTOR`); ephemeral HTTP exports live under `/run/pioreactor/exports`.
 - Point huey and WSGI/FastCGI units at module paths (e.g., `ExecStart=... -m pioreactorui.tasks`) instead of hardcoded folders.

3) Systemd Service Sprawl and Role Entanglement
- Problem: Many units with mixed concerns and role-specific enabling during image build (`LEADER`/`WORKER` conditionals); some duplication and ad‑hoc dep chains.
- Evidence: `files/system/systemd/*.service` (huey, lighttpd, avahi_aliases, firstboot, everyboot, load_rp2040, local_access_point, wifi_powersave, write_ip). Role-specific enabling is scattered (e.g., `04-install-services.sh`).
- Impact: Harder to reason about boot order and failure handling; inconsistencies across devices.
- Direction:
  - Introduce targets: `pioreactor.target` (common), `pioreactor-leader.target`, `pioreactor-worker.target`, and support combined activation for leader+worker.
  - Prefer wiring via target Wants (targets declare `Wants=serviceA serviceB ...`), and enable only the appropriate target(s) per image flavor at build time. Avoid direct service enablement in scripts.
  - Convert cron to timers; define correct `After/Wants` (DB/cache readiness, network-online) to reflect real dependencies. (Implemented.)
  - Centralize environment via a single `EnvironmentFile` (exposing `DOT_PIOREACTOR`, etc.) referenced by all units that need it.
  - Replace bash ExecStart lines with Python module entrypoints where logic is non-trivial.

4) Unified Software, Multiple Image Flavors
- Problem: Current leader/worker conditionals are scattered across scripts. We want the same software everywhere, but ship three headless images for simplicity: leader.img, worker.img, leader_worker.img.
- Evidence: `if [ "$LEADER" == "1" ]` / `if [ "$WORKER" == "1" ]` across install scripts; firstboot variants; selective service enabling.
- Impact: Disorganization makes maintenance harder; but having distinct images is desirable for user UX.
- Direction:
  - Build all three images from the same code and packages; differences are only which systemd targets are enabled.
  - For leader.img: enable `pioreactor.target` + `pioreactor-leader.target`.
  - For worker.img: enable `pioreactor.target` + `pioreactor-worker.target`.
  - For leader_worker.img: enable all three targets.
  - Replace the add-worker bash with a native `pio workers add` implementation, retaining `sshpass` initially to minimize user friction. Revisit key/token bootstrap later.

Additional Observations
- Workers currently enable lighttpd with `api-only` module; with the unified image, govern this via role targets rather than build-time conditionals.
- `04-install-services.sh` copies `pioreactor_startup_run@.service` twice; should be deduped in the migration.
- `14-install-crontabs.sh` is now disabled; timers cover DB backup, export cleanup, and network info refresh.
- Firstboot scripts handle SSH keys, DB seeds, and config; implement as idempotent Python oneshots in `pio system ...`.

Proposed Next Steps
- Define the three targets (`pioreactor`, `pioreactor-leader`, `pioreactor-worker`) and map existing units to them (including leader+worker combined activation). Update image build scripts to enable the correct targets per flavor.
- Draft `pio` subcommands and module entrypoints for: `system first-boot`, `system every-boot`, `workers add` (native), and a generalized `net advertise`.
- Specify a shared `EnvironmentFile` with `DOT_PIOREACTOR` and other needed env; reference from units.
- Design the UI packaging layout to work with lighttpd + FastCGI and move persistent UI artifacts under `DOT_PIOREACTOR`.
- Replace cron with systemd timers; document new timer names and retention policies. (Implemented.)

Open Decisions (to resolve before Phase 1 PR)
- Targets wiring pattern: keep service unit `[Install]` blocks unchanged and declare `Wants=` on targets (recommended), or switch services to `WantedBy=pioreactor*.target`. Chosen approach here: targets declare `Wants=...`; scripts enable only targets.
- Environment file path: default `/etc/pioreactor.env` with `DOT_PIOREACTOR=/home/pioreactor/.pioreactor` and `RUN_PIOREACTOR=/run/pioreactor`; `LG_WD=/run/pioreactor`.
- Firstboot linking: replace manual symlink in `11-add-firstboot.sh` with target-based enablement.
- Where to select image flavor: top-level `make_*_image.sh` enables the corresponding target(s) (preferred) rather than conditionals inside install scripts.

Current State Snapshot (for future you)
- Images build from `workspace/scripts/` with role conditionals (`LEADER`, `WORKER`), copying assets from `workspace/scripts/files/` into the image.
- Core Python app installed via pip in `06-install-pioreactor.sh` with extras per role; UI unpacked via tarball in `08-install-pioreactorui.sh` into `/var/www/pioreactorui`.
- CLI `pio workers add` exists and shells out to `/usr/local/bin/add_new_pioreactor_worker_from_leader.sh`.
- Bash scripts installed by `12-add-pioreactor-bash-scripts.sh` (update UI, plugin install/uninstall, worker add) and by service setup scripts.
- First boot and every boot are handled by `firstboot.service` and `everyboot.service` executing bash (`firstboot_*.sh`, `everyboot.sh`).
- Systemd units under `files/system/systemd/`: huey, lighttpd, avahi_aliases, load_rp2040, local_access_point, wifi_powersave, write_ip, pioreactor_startup_run@, firstboot, everyboot.
- Networking: NetworkManager profiles copied in `16-modify-network-details.sh`; avahi config tweaked; `write_ip.service` writes interface info to `/boot/firmware/network_info.txt`.
- Time sync: chrony installed (`17-install-chrony.sh`); leader config allows local stratum.
- Databases: SQLite DBs under `~/.pioreactor/storage`; UI/huey/cache under `/run/pioreactor/cache` (WAL enabled via tmpfiles + service ExecStartPre).
- Cron: `14-install-crontabs.sh` is a no-op; DB backup, export cleanup, and network-info are handled by systemd timers.
- Env: pip configured to use piwheels; `DOT_PIOREACTOR` is used by the app to locate `config.ini` and should be exposed to services via EnvironmentFile.

What “messy updates” mean today
- Bash scripts can be updated post-image but require ad-hoc distribution (manual copy, or shipping via Python packages writing to `/usr/local/bin`, or asking users to re-image). This is fragile and inconsistent across devices.
- UI updates are done by swapping the entire `/var/www/pioreactorui` folder via `update_ui.sh`, which risks permissions drift and loses package-level tracking/rollbacks.

Naming and CLI surface
- Prefer general-purpose names. Instead of `pio net publish-alias`, use `pio net advertise` or `pio mdns advertise` and group related network helpers under `pio net`.
- Keep `pio workers add` as the user-facing join command; implement natively in Python (no shell callout). Retain `sshpass` flow for now.

Persistence and storage notes
- Ephemeral items should live under `/run/pioreactor` (tmpfs). Anything required for durability across reboots should live under `DOT_PIOREACTOR`.
- Plan to relocate any persistent UI artifacts out of `/var/www/...` and into `~/.pioreactor/...` paths, with lighttpd serving from there when needed.

Quick Wins (low-risk groundwork)
- Define the shared systemd `EnvironmentFile` and list required variables (`DOT_PIOREACTOR`, others) without changing services yet.
- Inventory and map each existing unit to leader/worker/common ahead of target introduction.
- Draft the `pio system first-boot` logic based on `firstboot_*.sh` with idempotent checks (SSH keys, DB seeds, config writes).

Gotchas to remember
- `/tmp` is tmpfs (good for churn, not durable); journal size is capped (20M) and IPv6 is disabled by default — verify impacts on discovery/perf when altering network services.
- Workers currently enable lighttpd’s `api-only` module; ensure role targets carry that behavior.
- `pioreactor_startup_run@.service` is copied twice in `04-install-services.sh` — remove duplication in migration.

Systemd Target Mapping Draft
- Common (`pioreactor.target`):
  - lighttpd.service: Web server (workers use api-only module via config). After network-online.target.
  - huey.service: UI task consumer; requires `DOT_PIOREACTOR` in EnvironmentFile; After network, Before lighttpd.
  
  - avahi_aliases.service: mDNS alias publication; allowed on leader and worker; After network-online.target.
  - everyboot.service: Runs per-boot idempotent tasks.
  - firstboot.service: Runs once on first boot then disables itself.
  - wifi_powersave.service: Disables WiFi power save.
  - write_ip.service: Writes network info to `/boot/firmware/network_info.txt`.
  - local_access_point.service: Conditional oneshot (requires `/boot/firmware/local_access_point`).
  - log-failure@.service: Generic failure logger (OnFailure target for other units where useful).
  - pioreactor_startup_run@.service (template): Common template used by instances.
  - pioreactor_startup_run@monitor.service: Required on both leader and worker.
  - chrony.service: Time sync client; installed on all nodes.

- Leader (`pioreactor-leader.target`):
  - mosquitto.service: MQTT broker enabled only on leader.
  - pioreactor_startup_run@mqtt_to_db_streaming.service: Leader-only long-running job.

- Worker (`pioreactor-worker.target`):
  - load_rp2040.service: Flash/initialize microcontroller on workers.

- Combined (leader+worker):
  - Activates both `pioreactor-leader.target` and `pioreactor-worker.target` Wants; resolves to union of services.

Timers to Replace Cron (planned)
- Common timers:
  - `network-info.timer`: periodic refresh of network details (replaces root crontab line); runs `write_ip` helper.
- Leader timers:
  - `backup-database.timer`: replaces `pio run backup_database` cron (leader owns central DB).
  - `ui-exports-cleanup.timer`: periodically cleans `/run/pioreactor/exports`.

EnvironmentFile Plan
- Define a shared environment file (e.g., `/etc/pioreactor.env`) with at minimum `DOT_PIOREACTOR=/home/pioreactor/.pioreactor` and any other required env.
- Update units that currently reference `/etc/environment` to reference `/etc/pioreactor.env` (huey, load_rp2040, avahi_aliases, pioreactor_startup_run@, etc.).
- Ensure Python entrypoints read `DOT_PIOREACTOR` for config discovery.

Migration Checklist (Ordered)
- Define environment contract
  - Create `/etc/pioreactor.env` with `DOT_PIOREACTOR=/home/pioreactor/.pioreactor` and other required vars.
  - Adjust all services to use `EnvironmentFile=/etc/pioreactor.env` (replace references to `/etc/environment`).

- Introduce systemd targets
  - Add `pioreactor.target` (common), `pioreactor-leader.target`, and `pioreactor-worker.target` unit files.
  - Move enablement from build-time conditionals to Wants= of these targets per the mapping above.
  - Provide `pio role set leader|worker|leader_worker` to `systemctl enable --now` the correct targets and persist choice.

- Convert cron to timers
  - Create `network-info.service` + `network-info.timer` to replace root crontab `*/5 * * * *` (use `OnCalendar=*:0/5`).
  - Create `backup-database.service` + timer (leader-only). Mirror previous schedule or standardize to weekly (`OnCalendar=Sun *-*-* 00:00`).
  - Create `ui-exports-cleanup.service` + timer. Mirror `0 0 */29 * *` or standardize to monthly (`OnCalendar=monthly`).
  - Remove crontab installation from image build after timers are in place.

- Port bash flows to Python (`pio`)
  - `pio system first-boot`: generate SSH keys, config seeds, DB seeds; idempotent; logs to `pio`.
  - `pio system every-boot`: merge `/boot/firmware/config.ini`, force Wi-Fi on, any recurring tasks; idempotent.
  - `pio workers add`: replace shell-out; implement SSH auth (keep `sshpass`), config sync, chrony hints, reboot.
  - `pio net advertise` (or `pio mdns advertise`): manage alias publication via avahi; retry logic; respect `DOT_PIOREACTOR`.

- UI packaging and services
  - Package UI as a Python distribution (can merge with core later). Include WSGI/FCGI entrypoint and huey tasks.
  - Update `lighttpd` config to point to packaged app entrypoint (no mutable code in `/var/www`).
  - Update `huey.service` ExecStart to module invocation (e.g., `-m pioreactorui.tasks`).
  - Relocate persistent exports/uploads under `DOT_PIOREACTOR`; keep ephemeral items acceptable under `/tmp`.

- Service cleanup and deduplication
  - Remove duplicate copy of `pioreactor_startup_run@.service` in `04-install-services.sh`.
  - Stop copying bash scripts into `/usr/local/bin` once `pio` commands exist.
  - Keep `load_rp2040.service` and other minimal shell-only when truly trivial; otherwise replace with Python.

- Image build updates
  - Replace tarball-based UI install with pip install of packaged UI.
  - Remove role conditionals; enable targets instead. Keep necessary packages on all images.
  - Keep `sshpass` dependency for `pio workers add` initially.

- Test and rollout
  - Validate timers fire as expected (`systemd-analyze calendar ...`).
  - Boot-test leader, worker, and leader+worker modes; verify role switching via `pio role set`.
- Verify `DOT_PIOREACTOR` respected by services; check file ownership/permissions on `~/.pioreactor` and `/run/pioreactor/cache`.
  - Document migration notes and updated service topology.

- Decommission legacy
  - Remove `update_ui.sh`, `firstboot_*.sh`, `everyboot.sh`, and `add_new_pioreactor_worker_from_leader.sh` from the image once replaced.
  - Replace plugin install/uninstall bash with `pio plugins` subcommands (optional follow-up).

Upstream Changes Required (pioreactor/pioreactor)
- Repository: https://github.com/pioreactor/pioreactor (contains core `pio` CLI and `pioreactorui` Flask code)

- CLI: new and updated `pio` subcommands
  - `pio system first-boot`: Idempotent initializer. Implements logic from current `firstboot_*.sh`:
    - Generate SSH keys for user, seed authorized_keys and known_hosts with self hostname.local.
    - Set leader hostname/address and MQTT broker in config when appropriate.
    - Seed SQLite DB with demo experiment and optional initial worker assignment (when leader+worker).
    - Create `config_<hostname>.ini` and copy to `unit_config.ini` (leader path), using `DOT_PIOREACTOR`.
  - `pio system every-boot`: Idempotent recurring tasks:
    - Merge `/boot/firmware/config.ini` into `config.ini` and chown; remove source file.
    - Force Wi‑Fi on via `nmcli radio wifi on` (best-effort, ignore errors).
  - `pio workers add <hostname> [--password <pw>] [--address <addr>]`:
    - Native Python implementation replacing shell-out.
    - Use `sshpass` (present on image) to probe connectivity and copy SSH keys.
    - Create/overwrite unit-specific config file on leader; update `cluster.addresses` mapping.
    - Copy shared and unit configs to the worker; sanity-check presence; set chrony peer to leader; reboot worker.
    - Clear, actionable error messages; bounded retries (match current N=120 behavior but be faster where possible).
  - `pio role set leader|worker|leader_worker`:
    - Write role configuration under `DOT_PIOREACTOR`.
    - Optionally call `systemctl` to enable/disable `pioreactor-*.target` (guard with root-permission check).
  - `pio net advertise [--alias <name>]` (or `pio mdns advertise`):
    - Publish mDNS alias using `avahi-publish -a -R` for all current IPs; simple retry/sleep loop until IPs exist.
    - Default alias sourced from config (`ui.domain_alias`) and/or argument.

- Packaging: `pioreactorui` as a Python distribution
  - Move UI code (currently placed in `/var/www/pioreactorui` by tarball) into a proper package inside this repo.
  - Provide WSGI/FCGI entrypoint (console_script) for lighttpd to launch, plus a huey tasks module path.
  - Ensure dependencies are declared; avoid runtime `pip install -r`.
  - Replace reliance on `.env` file with reading env via `os.environ` (e.g., `DOT_PIOREACTOR`) and/or `config.ini`.

- Storage and paths
  - Centralize path resolution around `DOT_PIOREACTOR` (default `/home/pioreactor/.pioreactor`).
  - Move persistent uploads/exports to `DOT_PIOREACTOR` (e.g., `.../ui_static/exports`); allow ephemeral items in `/tmp`.
  - Provide helpers to get persistent vs ephemeral paths; avoid writing into package install directories.

- Systemd integration entrypoints
  - Ensure huey consumer path remains `pioreactorui.tasks.huey` (as used by unit).
  - Provide console_scripts for `pio` subcommands above and any service entrypoints (e.g., FCGI/WSGI runner).

- Plugins handling parity (optional, but recommended)
  - Align `pio plugins install/uninstall` to perform what current bash does:
    - Detect `LEADER_ONLY` file inside wheels and gate installation accordingly.
    - Merge `additional_config.ini` into shared config on leader.
    - Apply `additional_sql.sql` to leader DB and restart `mqtt_to_db_streaming` if needed.
    - Sync UI contrib YAMLs and datasets into `~/.pioreactor/plugins/...` locations.

- Testing and docs
  - Add CLI tests (unit/integration where feasible) for `pio workers add`, `system first-boot`, and `system every-boot`.
  - Document `DOT_PIOREACTOR` and new storage locations for UI exports/uploads.
  - Provide upgrade notes: UI now packaged via pip; tarball-based `update_ui.sh` is removed.

Implementation Hints
- Reuse existing config/CRUD helpers in core where possible; avoid re-implementing CRUDINI behavior if library functions exist.
- For SSH flows, wrap shell calls (`ssh`, `sshpass`, `ssh-copy-id`, `scp`) with robust subprocess handling and timeouts; surface concise errors.
- Keep all new CLIs idempotent and safe to re-run; write minimal state to `DOT_PIOREACTOR`.

Headless Role Selection (Three Images)
- Users download `leader.img`, `worker.img`, or `leader_worker.img`.
- Each image enables the appropriate targets at build time; no interactive role selection is needed.


Organize .pioreactor folder
 - currently have /ui/contrib and /plugins/ui/contrib, but this doesn't extend to export