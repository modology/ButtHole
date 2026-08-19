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

The first run is a **dry run**. It downloads the public database manifests, scans distribution-like directories, and writes:

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

The scanner does not upload anything to GitHub.

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

## Important: personal ROMs and large files

The default scan is restricted to MiSTer distribution-like directories such as `_Arcade`, `_Console`, `_Computer`, `cores`, and `Scripts`. It does not automatically stage arbitrary personal ROM collections.

To scan everything:

```bash
bash ./mister_extras_scan.sh --all-files
```

Files at or above 95 MiB are reported but not staged by default. GitHub's normal Git file limit is 100 MiB, so these files need a different distribution method.

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
