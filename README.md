# ButtHole — MiSTer Extras Database

A friends-group MiSTer Downloader database for files that are not already supplied by the public MiSTer distribution databases.

The repository follows the MiSTer custom database format used by [DB-Template_MiSTer](https://github.com/theypsilon/DB-Template_MiSTer).

After the GitHub Action builds the database, friends can add:

```ini
[modology/ButtHole]
db_url = https://raw.githubusercontent.com/modology/ButtHole/db/db.json.zip
```

to `/media/fat/downloader.ini`, or use the generated drop-in `.ini` file.

## Scanner

The scanner is intended to run directly on a MiSTer:

```bash
cd /media/fat/Scripts
bash ./mister_extras_scan.sh
```

The first run is a **dry run**. It downloads the public database manifests and, by default, scans **the entire `/media/fat` SD card recursively**. It writes:

```text
/media/fat/mister_extras_report.json
```

Review that report. To stage the detected extras:

```bash
bash ./mister_extras_scan.sh --stage
```

By default, staging goes to:

```text
/media/fat/MiSTer_Extras/
```

The scanner does not upload anything unless `--upload` is explicitly supplied.

## Automatic GitHub upload

To stage the detected extras and automatically commit and push them to this repository:

```bash
bash ./mister_extras_scan.sh --stage --upload
```

The first upload automatically clones `modology/ButtHole` into a local working directory on the MiSTer. Later uploads reuse that checkout and pull the latest `main` before pushing.

The scanner uses a GitHub fine-grained Personal Access Token stored locally on the MiSTer. **Never commit the token to this repository.** Create:

```text
/media/fat/Scripts/.github_token
```

and put the token on a single line in that file. The script restricts the token file to mode `600` where the filesystem permits it and keeps the token out of Git URLs, reports, commit messages, and uploaded files.

For this repository, the token only needs `Contents: Read and write` access to `modology/ButtHole`.

During upload the script displays progress for cloning/pulling, copying, staging, committing, and pushing. If there are no changes, it reports that there is nothing new to commit.

The generated local token file, scanner report, and checksum file are explicitly excluded from the GitHub upload.

## Scan scope

**Everything is scanned by default.** The scanner no longer limits discovery to `_Arcade`, `_Console`, `_Computer`, `cores`, `Scripts`, or other MiSTer distribution-like directories. Personal ROM collections and other files anywhere under `/media/fat` are included in the scan.

The old full-scan option remains accepted as a compatibility alias:

```bash
bash ./mister_extras_scan.sh --all-files
```

If you specifically want the old restricted behaviour, use:

```bash
bash ./mister_extras_scan.sh --distribution-only
```

The scanner still avoids copying the generated report and the `MiSTer_Extras` staging directory into themselves. Files at or above 95 MiB are reported but not staged by default. GitHub's normal Git file limit is 100 MiB, so these files need a different distribution method.

## Public baseline

The default comparison sources are:

- Official MiSTer Distribution
- Jotego JT cores, with beta/premium/patreon-tagged entries excluded
- Coin-Op Collection MiSTer distribution

Additional **public** databases can be supplied:

```bash
bash ./mister_extras_scan.sh \
  --public-db "example=https://example.com/db.json.zip"
```

The scanner intentionally does **not** blindly trust the MiSTer's `downloader.ini`, because a user's `downloader.ini` can contain premium/beta databases.

## Workflow

Every push to `main` runs the MiSTer DB generator. The resulting database is published on the `db` branch as:

```text
https://raw.githubusercontent.com/modology/ButtHole/db/db.json.zip
```

and the generated drop-in Downloader configuration is also published there.

## Authorization

The repository is intended only for files whose redistribution is authorized by their copyright/licence holders. Do not add files merely because they happen to be present on somebody's SD card.

## Credits

- MiSTer Downloader / DB Template by theypsilon and contributors.
- MiSTer distribution and core authors retain their respective copyrights and licences.
