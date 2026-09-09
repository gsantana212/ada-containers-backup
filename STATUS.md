# Status

## Last successful backup
**2026-07-25** — `ada-backup-20260725-003127.tar.zst` (11.8 MB), verified sha256.

The on-disk tarballs in this repo (also exposed as `ada-backup-latest.tar.zst`) are the
last known-good archive. No backup cron is currently installed on lab0
(`crontab -l` is empty, no systemd unit). Restore capability is intact as long as
this tarball is preserved.

## Verified integrity
`ada-backup-latest.tar.zst` sha256 matches `ada-backup-latest.tar.zst.sha256`.
The CI workflow `.github/workflows/verify-backup.yml` re-checks this on every push to `main`.

## Backup schedule
**Current: MANUAL.** No automation is running. Re-enable by installing a cron on
lab0 that runs the backup script and pushes the resulting `*.tar.zst` + `.sha256`
into this repo.

## Warning
Backups are STALE (last: 2026-07-25, ~7 weeks old). Do not rely on this archive
as a current state-of-record until the cron is restored.
