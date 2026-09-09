# Security Policy

## Reporting a vulnerability

If you discover a security issue in this repository (the Ada stack backup
scripts, the systemd units, or the tarball pipeline), please report it
privately:

**Email:** security@skillhub.shop

Please do **not** file a public GitHub issue for security problems. We will
acknowledge receipt within 48 hours and aim to triage within 5 business days.

## Scope

- `backup.sh` / `restore.sh` and any container snapshots they produce
- The systemd units that drive the backup pipeline
- The published tarballs under `ada-backup-*.tar.zst`

## Out of scope

- The restored containers themselves — report vulnerabilities in a specific
  service to that service's maintainers.
