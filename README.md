# ButtHole — MiSTer Extras Database

A friends-group MiSTer Downloader database for files that are not already supplied by the public MiSTer distribution databases.

The repository follows the MiSTer custom database format used by [DB-Template_MiSTer](https://github.com/theypsilon/DB-Template_MiSTer).

After the GitHub Action builds the database, friends can add:

```ini
[modology/ButtHole]
db_url = https://raw.githubusercontent.com/modology/ButtHole/db/db.json.zip
```

to `/media/fat/downloader.ini`, or use the generated drop-in `.ini` file.

## MiSTer Script Menu

The two main scripts are designed to be launched directly from the MiSTer **Scripts** menu. No command-line options are required for normal use.

### Upload scanner

Launch:

```text
mister_extras_scan.sh
```

The scanner will automatically:

1. Scan the **entire `/media/fat` SD card recursively**.
2. Compare files against the configured public MiSTer databases.
3. Stage detected extras in `/media/fat/MiSTer_Extras/`.
4. Show the scan/staging results.
5. Ask whether you want to commit the staged files to GitHub.
6. If you answer **Yes**, clone/pull `modology/ButtHole`, copy the staged files, create a Git commit, and push to `main`.
7. If you answer **No**, nothing is uploaded and the staged files remain on the SD card.

There is deliberately no automatic GitHub push without asking first.

### First-time setup: GitHub token

Before using the scanner's GitHub upload option, copy the supplied file:

```text
.github_token
```

to **exactly**:

```text
/media/fat/Scripts/.github_token
```

The file must contain the GitHub fine-grained Personal Access Token on a single line. If necessary:

```bash
chmod 600 /media/fat/Scripts/.github_token
```

**This token gives the scanner permission to commit and push your detected extra files to the `modology/ButtHole` GitHub repository on behalf of the repository owner.** The token should have `Contents: Read and write` permission for `modology/ButtHole` only.

Treat the token as a secret. Anyone who obtains it may be able to modify the repository with the permissions granted to that token. Never put the token into the repository, a screenshot, a report, or a forum post.

The scanner temporarily moves the token out of `/media/fat` while scanning so it cannot accidentally be classified as an extra. The local Git checkout is also temporarily moved out of the scan area. The token is never copied into the repository, report, commit, or staged extras.

### Pull latest files

To download the latest files from the ButtHole repository directly from the MiSTer Scripts menu, launch:

```text
mister_extras_pull.sh
```

The pull script uses the same `.github_token`, downloads the latest `main` branch, and copies the repository files onto `/media/fat`. Git metadata, `.github_token`, the scanner report, and the local checksum file are not copied to the SD card.

This makes it easy for you and your friends to pull the latest files from the shared repository without using a computer or typing Git commands.

## Scanner details

The scanner's Python backend can still be called manually for advanced/debugging use, but this is not required for normal MiSTer menu operation.

The scanner writes its report to:

```text
/media/fat/mister_extras_report.json
```

Files at or above 95 MiB are reported but not staged by default. GitHub's normal Git file limit is 100 MiB, so these files need a different distribution method.

## Scan scope

**Everything is scanned by default.** The scanner no longer limits discovery to `_Arcade`, `_Console`, `_Computer`, `cores`, `Scripts`, or other MiSTer distribution-like directories. Personal ROM collections and other files anywhere under `/media/fat` are included in the scan.

The old restricted behaviour is still available to advanced users with:

```bash
python3 /media/fat/Scripts/mister_extras_scan.py --distribution-only
```

## Public baseline

The default comparison sources are:

- Official MiSTer Distribution
- Jotego JT cores, with beta/premium/patreon-tagged entries excluded
- Coin-Op Collection MiSTer distribution

Additional **public** databases can be supplied to the Python backend for advanced use.

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
