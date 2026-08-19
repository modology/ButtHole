#!/usr/bin/env python3
"""MiSTer Extras Scanner.

Scans a MiSTer SD card and compares files against selected public Downloader
DB manifests. By default it scans the entire SD card recursively. It reports
public, modified, and extra files and can stage the extras for review. It
never uploads anything by itself.
"""
import argparse, hashlib, json, os, shutil, subprocess, sys, tempfile, time, urllib.request, zipfile
from pathlib import Path

PUBLIC_DBS = [
    ("distribution", "https://raw.githubusercontent.com/MiSTer-devel/Distribution_MiSTer/main/db.json.zip"),
    ("jtcores", "https://raw.githubusercontent.com/jotego/jtcores_mister/main/jtbindb.json.zip"),
    ("coinop", "https://raw.githubusercontent.com/Coin-OpCollection/Distribution-MiSTerFPGA/db/db.json.zip"),
]
DEFAULT_SD = "/media/fat"
DEFAULT_PREFIXES = ("_Arcade/", "_Console/", "_Computer/", "_Other/", "cores/", "Scripts/", "MiSTer/", "games/")
DEFAULT_MAX_FILE_MB = 95
BETA_WORDS = ("jtbeta", "beta", "patreon", "premium")

def die(msg):
    print(f"ERROR: {msg}", file=sys.stderr); raise SystemExit(1)

def run(cmd):
    try:
        return subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    except FileNotFoundError: die(f"Required command not found: {cmd[0]}")
    except subprocess.CalledProcessError as e:
        print(e.stderr.strip(), file=sys.stderr); die(f"Command failed: {' '.join(cmd)}")

def require_commands():
    for c in ("curl", "unzip"):
        if shutil.which(c) is None: die(f"{c} is required")

def norm(v):
    v = str(v).replace("\\", "/").lstrip("/")
    while v.startswith("./"): v = v[2:]
    return v

def download(url, dest):
    run(["curl", "-L", "--fail", "--silent", "--show-error", "--retry", "3", "--connect-timeout", "20", "-o", str(dest), url])

def load_db(path):
    raw = path.read_bytes()
    if raw[:2] == b"PK":
        with zipfile.ZipFile(path) as z:
            names = sorted([n for n in z.namelist() if n.lower().endswith(".json") and not n.endswith("/")], key=lambda n: (Path(n).name != "db.json", len(n)))
            if not names: die(f"No JSON found in {path}")
            return json.loads(z.read(names[0]).decode("utf-8"))
    return json.loads(raw.decode("utf-8"))

def tag_map(db):
    out = {}; td = db.get("tag_dictionary") if isinstance(db, dict) else None
    if not isinstance(td, dict): return out
    for k, v in td.items():
        if isinstance(v, str): out[str(k)] = v.lower(); out[v.lower()] = v.lower()
        elif isinstance(v, (int, float)): out[str(v)] = str(k).lower()
    return out

def strings(v, tm):
    if isinstance(v, (str, int, float)):
        s = str(v).lower(); return [s] + ([tm[s]] if s in tm else [])
    if isinstance(v, list):
        return sum((strings(x, tm) for x in v), [])
    if isinstance(v, dict):
        return sum((strings(k, tm) + strings(x, tm) for k, x in v.items()), [])
    return []

def beta_entry(meta, tm):
    if not isinstance(meta, dict): return False
    vals = []
    for k in ("tags", "tag", "filter", "category", "categories"):
        if k in meta: vals += strings(meta[k], tm)
    for k in ("metadata", "attributes", "props"):
        if isinstance(meta.get(k), dict):
            for sk in ("tags", "tag", "category", "categories"):
                if sk in meta[k]: vals += strings(meta[k][sk], tm)
    return any(any(w in x for w in BETA_WORDS) for x in vals)

def extract(db, name):
    files = db.get("files") if isinstance(db, dict) else None
    if not isinstance(files, dict):
        for k in ("database", "db", "content"):
            if isinstance(db.get(k), dict) and isinstance(db[k].get("files"), dict): files = db[k]["files"]; break
    if not isinstance(files, dict): die(f"{name}: no recognised files object")
    tm = tag_map(db); out = {}
    for p, meta in files.items():
        p = norm(p)
        if not p or not isinstance(meta, dict): continue
        if name == "jtcores" and beta_entry(meta, tm): continue
        out[p] = {"size": meta.get("size"), "hash": str(meta.get("hash") or meta.get("md5")).lower() if (meta.get("hash") or meta.get("md5")) else None, "source": name}
    return out

def md5(path):
    h = hashlib.md5()
    with path.open("rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""): h.update(b)
    return h.hexdigest()

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""): h.update(b)
    return h.hexdigest()

def should(rel, prefixes):
    rel = norm(rel)
    return not any(rel.startswith(x) for x in ("Scripts/.config/", "Scripts/.cache/", "System Volume Information/", ".Trashes/", ".Spotlight-V100/", "lost+found/")) and any(rel.startswith(x) for x in prefixes)

def files_under(root, prefixes):
    for base, dirs, files in os.walk(root):
        relbase = norm(os.path.relpath(base, root)); relbase = "" if relbase == "." else relbase
        keep = []
        for d in dirs:
            p = norm(os.path.join(relbase, d)) + "/"
            if any(x == "" or x.startswith(p) or p.startswith(x) for x in prefixes): keep.append(d)
        dirs[:] = keep
        for f in files:
            rel = norm(os.path.join(relbase, f))
            if should(rel, prefixes): yield rel, Path(base) / f

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sd", default=DEFAULT_SD)
    ap.add_argument("--stage", action="store_true")
    ap.add_argument("--output")
    ap.add_argument("--report")
    ap.add_argument("--include-prefix", action="append", default=[])
    ap.add_argument("--public-db", action="append", default=[])
    ap.add_argument("--max-file-mb", type=float, default=DEFAULT_MAX_FILE_MB)
    ap.add_argument("--distribution-only", action="store_true", help="Restrict scanning to the traditional MiSTer distribution directories instead of scanning the entire SD card")
    ap.add_argument("--all-files", action="store_true", help="Deprecated compatibility alias; full recursive scanning is now the default")
    ap.add_argument("--no-hash", action="store_true")
    a = ap.parse_args()
    root = Path(a.sd).resolve()
    if not root.is_dir(): die(f"SD path does not exist: {root}")
    require_commands()
    scan_all = not a.distribution_only
    prefixes = ("",) if scan_all else tuple(DEFAULT_PREFIXES) + tuple(norm(x).rstrip("/") + "/" for x in a.include_prefix)
    if scan_all and a.include_prefix:
        print("Note: --include-prefix is ignored when scanning the entire SD card (the default). Use --distribution-only to apply prefix filters.")
    report_path = Path(a.report) if a.report else root / "mister_extras_report.json"
    stage = Path(a.output) if a.output else root / "MiSTer_Extras"
    sources = list(PUBLIC_DBS)
    for item in a.public_db:
        n, u = item.split("=", 1) if "=" in item else ("custom", item); sources.append((n, u))
    work = Path(tempfile.mkdtemp(prefix="mister-extras-")); dbs = []
    try:
        print("MiSTer Extras Scanner\n======================")
        print("Scan scope: ENTIRE SD CARD" if scan_all else "Scan scope: distribution directories only")
        for name, url in sources:
            print(f"[DB] {name}")
            p = work / (name + ".db"); download(url, p)
            dbs.append((name, url, load_db(p)))
        public = {}
        counts = {}
        for n, u, db in dbs:
            e = extract(db, n); counts[n] = len(e)
            for p, m in e.items():
                if p not in public or (public[p].get("hash") is None and m.get("hash")): public[p] = m
        print(f"Public index: {len(public):,} entries")
        extras=[]; modified=[]; public_count=0; scanned=0; large=[]; extra_bytes=0
        report_rel = norm(str(report_path.relative_to(root))) if report_path.is_relative_to(root) else None
        stage_abs = stage.resolve()
        for rel, path in files_under(root, prefixes):
            if report_rel and rel == report_rel: continue
            try:
                if path.resolve().is_relative_to(stage_abs): continue
            except AttributeError:
                if str(path.resolve()).startswith(str(stage_abs) + os.sep): continue
            scanned += 1; size = path.stat().st_size; p = public.get(rel)
            if p is None: cat="extra"
            elif p.get("size") is not None and int(p["size"]) == size and (a.no_hash or not p.get("hash") or md5(path) == p["hash"]): cat="public"
            else: cat="modified"
            if cat == "public": public_count += 1
            elif cat == "modified": modified.append({"path":rel,"size":size,"public_size":p.get("size") if p else None,"public_hash":p.get("hash") if p else None})
            else:
                extra_bytes += size
                item={"path":rel,"size":size}
                (large if size >= a.max_file_mb*1024*1024 else extras).append(item)
        report={"format":1,"generated_at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),"sd_path":str(root),"scan_mode":"all_files" if scan_all else "distribution_only","public_databases":[{"name":n,"url":u,"entries":counts[n]} for n,u,_ in dbs],"scan_prefixes":list(prefixes),"summary":{"scanned":scanned,"public":public_count,"modified":len(modified),"extras":len(extras),"large_extras_not_staged":len(large),"extra_bytes":extra_bytes},"extras":extras,"modified":modified,"large_extras":large}
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True)+"\n", encoding="utf-8")
        print(f"Scanned {scanned:,} | public {public_count:,} | modified {len(modified):,} | extras {len(extras):,} | large {len(large):,}")
        print(f"Extra size: {extra_bytes/1024**3:.2f} GiB")
        print(f"Report: {report_path}")
        if not a.stage: print("Dry run: nothing copied. Re-run with --stage after reviewing the report."); return
        stage.mkdir(parents=True, exist_ok=True); lines=[]
        for item in extras:
            rel=item["path"]; src=root/rel; dst=stage/rel; dst.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(src,dst); lines.append(f"{sha256(src)}  {rel}")
        (stage/"EXTRAS_SHA256SUMS").write_text("\n".join(sorted(lines))+(("\n") if lines else ""), encoding="utf-8")
        print(f"Staged {len(extras):,} files to {stage}")
        if large: print(f"{len(large)} files were not staged because they exceed the configured Git-safe size.")
    finally: shutil.rmtree(work, ignore_errors=True)
if __name__ == "__main__": main()
