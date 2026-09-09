# ada-containers-backup

Rolling snapshot of the `ada-stack` Docker containers — images, named volumes,
and host-side configs — packed into a single `tar.zst` blob with a sha256
sidecar.

## What is in here

| File | What it is |
|---|---|
| `ada-backup-latest.tar.zst` | The most recent successful backup (always points at the newest dated tarball). |
| `ada-backup-latest.tar.zst.sha256` | sha256 of `ada-backup-latest.tar.zst`. Verify before restoring. |
| `ada-backup-YYYYMMDD-HHMMSS.tar.zst` | A specific dated snapshot. |
| `ada-backup-YYYYMMDD-HHMMSS.tar.zst.sha256` | sha256 of the dated snapshot. |

## How to restore

Prereqs: a Linux box with `zstd` and `docker` installed. The host that produced
this backup was Fedora 41+, Docker 26+.

```bash
# 1. Verify integrity
sha256sum -c ada-backup-latest.tar.zst.sha256

# 2. Extract
tar --use-compress-program=unzstd -xf ada-backup-latest.tar.zst

# 3. Inspect manifest
cat ada-backup-restore/manifest.json | jq .

# 4. Run the included restore script
bash ada-backup-restore/restore.sh
```

## How backups are produced

A cron job on the source VPS (see `ada-restore/ada-backup.sh` upstream) runs
nightly, calls `docker save` + `docker compose config` + tarballs the named
volumes, then pushes the resulting `.tar.zst` to this repo as a new commit on
`main`.

## License

MIT — see `LICENSE`.