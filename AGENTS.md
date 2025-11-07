# Repository Guidelines

This project is used to generate our custom Raspberry Pi images for the Pioreactor hardware. We take the published "lite" images from the Raspberry Pi Foundation, and make customization to them.

## Project Structure & Module Organization
- `src/`: CustoPiZer core scripts and config used inside the Docker build (e.g., `common.sh`, `customize`, `start_chroot_script`).
- `workspace/`: Build workspace mounted into the container.
  - `workspace/scripts/`: Ordered customization steps (`00-...sh` → `99-...sh`).
  - `workspace/scripts/files/`: Assets copied into the image (e.g., `bash/`, `sql/`).
- Top-level helpers: `make_leader_image.sh`, `make_worker_image.sh`, `make_leader_worker_image.sh`, `enter_image.sh`.
- CI: `.github/workflows/custopize.yaml` triggers containerized builds and publishes release assets.


## Other relevant files


see RPi-filesystem-locations.md for a list of important Raspberry Pi Locations for Pioreactor Images
