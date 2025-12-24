# Important Raspberry Pi Locations for Pioreactor Images

Reference list of on-device paths that matter once a custom Pioreactor Raspberry Pi OS image is flashed and running. Use it as a checklist when debugging installs, copying data, or documenting support steps.

| Path | What lives here | Notes |
| --- | --- | --- |
| `/etc/pioreactor.env` | Shared environment file exported to services | Provides canonical `DOT_PIOREACTOR`, `RUN_PIOREACTOR`, `LG_WD`, and virtualenv paths so systemd units pick up the same locations. |
| `/home/pioreactor/.pioreactor/` | Pioreactor home (`$DOT_PIOREACTOR`) | Contains configs, plugins, storage, hardware definitions, logs, and other per-device state. Ensure ownership stays `pioreactor:pioreactor`. |
| `/home/pioreactor/.pioreactor/config.ini` | Cluster-wide configuration | Holds network, MQTT, UI, logging, and automation settings replicated to workers. |
| `/home/pioreactor/.pioreactor/unit_config.ini` | Unit overrides | Optional per-device overrides synced from the leader when a worker is added. |
| `/home/pioreactor/.pioreactor/plugins/` | Plugin root | Mirrors the `.pioreactor` layout for plugin-provided files; typically subdivided into `python/`, `ui/`, `exportable_datasets/`, etc. |
| `/home/pioreactor/.pioreactor/plugins/ui/` | UI plugin assets | Static contrib YAML, templates, and other UI resources merged into the Pioreactor UI. |
| `/home/pioreactor/.pioreactor/plugins/exportable_datasets/` | Exportable dataset plugins | Each plugin ships SQL queries or serializers that surface new datasets to the UI. |
| `/home/pioreactor/.pioreactor/storage/` | Persistent databases | Holds SQLite data such as `pioreactor.sqlite` (experiments) and `local_persistent_pioreactor_metadata.sqlite`. |
| `/home/pioreactor/.pioreactor/storage/pioreactor.sqlite` | Primary experiment database | Used by the leader, replicated to workers for durability. Back up before major upgrades. |
| `/home/pioreactor/.pioreactor/storage/local_persistent_pioreactor_metadata.sqlite` | Persistent cache | Stores long-lived metadata that survives reboots. |
| `/home/pioreactor/.pioreactor/hardware/` | Hardware definition packs | YAML that describes hats, models, sensors, and calibration values consumed by the Pioreactor hardware subsystem. |
| `/home/pioreactor/.pioreactor/experiment_profiles/` | User experiment profiles | Drop `.py` / `.json` profile definitions here so they show up in the UI for scheduling. |
| `/home/pioreactor/.ssh/` | Device SSH keys | Created during image build so leaders can add workers securely. |
| `/run/pioreactor/` | Runtime scratch space (`$RUN_PIOREACTOR`) | tmpfs directory for caches, sockets, Huey queues, and general runtime coordination. Cleared on reboot. |
| `/run/pioreactor/cache/` | Volatile caches | Includes `local_intermittent_pioreactor_metadata.sqlite` and UI/Huey cache files that can be safely discarded. |
| `/run/pioreactor/exports/` | Web export staging | Lighttpd serves `/exports/` from here so downloads never touch persistent storage. |
| `/var/log/pioreactor.log` | System log for Pioreactor services | Configured via `config.ini` and read by both CLI and UI. Rotate with journald/logrotate as needed. |
| `/opt/pioreactor/venv/` | System Python virtual environment | Hosts the Pioreactor Python installation (`pio`, `pios`, services). Activate manually for debugging. |
| `/tmp/` | Temporary workspace | Referenced by `TMPDIR` in `pioreactor.env` for short-lived files. |

These paths assume the default `pioreactor` user and the standard environment variables distributed in `pioreactor.env`. Override them only when you fully control downstream references.
