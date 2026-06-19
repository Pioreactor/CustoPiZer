# Repository Guidelines

This project is used to generate our custom Raspberry Pi images for the Pioreactor hardware. We take the published "Lite" images from the Raspberry Pi Foundation, and make customization to them. The current source images are Debian Trixie (13), with python 3.13 installed.

## Project Structure & Module Organization
- `src/`: CustoPiZer core scripts and config used inside the Docker build (e.g., `common.sh`, `customize`, `start_chroot_script`).
- `workspace/`: Build workspace mounted into the container.
  - `workspace/scripts/`: Ordered customization steps (`00-...sh` → `99-...sh`).
  - `workspace/scripts/files/`: Assets copied into the image (e.g., `bash/`, `sql/`).
- Top-level helpers: `make_leader_image.sh`, `make_worker_image.sh`, `make_leader_worker_image.sh`, `make_zero_w_worker_image.sh`, `enter_image.sh`.
- CI: `.github/workflows/custopize.yaml` triggers containerized builds and publishes release assets.

## Verification loop

- use shellcheck for changed shell scripts
- do not assume Docker is installed locally
- for image changes, identify the affected script and explain which build target would exercise it

## Other relevant files and information

 - See `metadata/RPi-filesystem-locations.md` for a list of important Raspberry Pi Locations for Pioreactor Images
 - See `metadata/2025-12-04-raspios-trixie-arm64-lite-sizes.tsv` for a list of preinstalled software on the Lite images.
 - Some files under workspace/scripts/files/ may be generated or synced from the Pioreactor repo. Before editing assets there, check whether a sync script or source asset owns the file.
