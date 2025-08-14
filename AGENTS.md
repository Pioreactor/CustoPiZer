# Repository Guidelines

## Project Structure & Module Organization
- `src/`: CustoPiZer core scripts and config used inside the Docker build (e.g., `common.sh`, `customize`, `start_chroot_script`).
- `workspace/`: Build workspace mounted into the container.
  - `workspace/scripts/`: Ordered customization steps (`00-...sh` → `99-...sh`).
  - `workspace/scripts/files/`: Assets copied into the image (e.g., `bash/`, `sql/`).
- Top-level helpers: `make_leader_image.sh`, `make_worker_image.sh`, `make_leader_worker_image.sh`, `enter_image.sh`.
- CI: `.github/workflows/custopize.yaml` triggers containerized builds and publishes release assets.


See ISSUES.md and PLAN.md for issue tracking and project planning.
