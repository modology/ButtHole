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

The scanner is intended to run directly from the MiSTer Scripts menu:

```bash
bash ./mister_extras_scan.sh
```

No command-line options are required for normal use. The scanner automatically scans **the entire `/media/fat` SD card recursively**, compares files against the configured public databases, stages detected extras, and then asks whether the user wants to commit and push the staged changes to GitHub.

A report is written to:

```text
/media/fat/mister_extras_report.json
```

The default staging directory is:

```text
/media/fat/MiSTer_Extras/
```

If the user answers **No** at the GitHub upload prompt, the staged files remain local and nothing is pushed.

## Automatic GitHub upload

If you are a friend contributing files to this database, copy the provided `.github_token` file to **exactly**:

```text
/media/fat/Scripts/.github_token
```

The file must contain the GitHub fine-grained Personal Access Token on a single line. If necessary:

```bash
chmod 600 /media/fat/Scripts/.github_token
```

**This token gives the scanner permission to commit and push detected extra files to the `modology/ButtHole` GitHub repository on behalf of the repository owner.** It should have `Contents: Read and write` permission for `modology/ButtHole`.

Treat the token as a secret. Anyone who obtains a copy may be able to modify the repository with the permissions granted to that token. Never upload the token to GitHub or include it in a report, screenshot, forum post, or commit.

When the scanner finishes staging, it asks whether to upload the changes. Answering **Yes** automatically clones the repository on the first upload, copies the staged files, creates a Git commit, and pushes it to `main`. Later uploads reuse/update the local checkout before pushing.

The scanner keeps `.github_token`, its report, and local checksum files out of the upload.

## Pulling new files from ButtHole

The repository includes `mister_extras_pull.sh`, which can also be run directly from the MiSTer Scripts menu.

```bash
bash ./mister_extras_pull.sh
```

The pull script performs an **incremental update** rather than blindly copying the whole repository every time.

It:

1. Downloads the latest `main` repository snapshot.
2. Checks every repository file against the corresponding file on `/media/fat`.
3. **Skips files that are already identical.**
4. Downloads/copies only **new or changed files**.
5. Shows counts for new, changed, and unchanged files and the amount of data copied.
6. **Never deletes local files that are not present in ButtHole.**

For example, if a MiSTer already has 40 GB of ButtHole content and a friend adds 500 MB of new files, the next pull will skip the existing identical files and only copy the new/changed 500 MB.

The pull script also excludes `.github_token`, the scanner report, checksum files, and Git metadata from being copied to the SD card.

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

Additional **public** databases can be supplied by modifying the scanner configuration.

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
