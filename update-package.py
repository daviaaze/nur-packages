#!/usr/bin/env python3
"""
Update a package in this flake to its latest upstream release.

Usage: scripts/update-package.py <attr> [--build]

Reads update.json to learn how the attribute's version/hash is sourced, then
rewrites the target package.nix. Uses `nix store prefetch-file` for real SRI hashes.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CONF = ROOT / "update.json"


def sri_of(url: str) -> str:
    out = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", url],
        capture_output=True, text=True, check=True,
    ).stdout
    return json.loads(out)["hash"]


def latest_tag(repo: str) -> str:
    out = subprocess.run(
        ["gh", "api", f"repos/{repo}/releases/latest", "--jq", ".tag_name"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    return out


def release_asset(repo: str, tag: str, matcher: str) -> str:
    out = subprocess.run(
        ["gh", "api", f"repos/{repo}/releases/tags/{tag}",
         "--jq", ".assets[] | {name, browser_download_url, url}"],
        capture_output=True, text=True, check=True,
    ).stdout
    for line in out.splitlines():
        a = json.loads(line)
        if re.search(matcher, a["name"]):
            return a["browser_download_url"]
    raise SystemExit(f"no asset matching {matcher!r} in {repo}@{tag}")


def strip_prefix(s: str, prefix: str) -> str:
    return re.sub(rf"^{re.escape(prefix)}", "", s)


def set_field(nix: str, field: str, value: str) -> str:
    """Replace `field = "..."` or `field ? "..."` (default-arg) value."""
    n, count = None, 0
    for sep in ("\\s*=\\s*", "\\s*\\?\\s*"):
        pat = re.compile(
            rf"({re.escape(field)}{sep}\")[^\"]*(\")",
        )
        n, count = pat.subn(lambda m: m.group(1) + value + m.group(2), nix)
        if count:
            break
    if count == 0:
        raise SystemExit(f"field {field!r} not found")
    return n


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("attr")
    ap.add_argument("--build", action="store_true")
    args = ap.parse_args()

    with CONF.open() as fh:
        data = json.load(fh)
    entry = next(
        (p for p in data["packages"] if p["attr"] == args.attr), None
    )
    if entry is None:
        raise SystemExit(f"no update.json entry for attr {args.attr!r}")

    file = ROOT / entry["file"]
    nix = file.read_text()

    strategy = entry["strategy"]
    repo = entry.get("repo", "")
    tag_prefix = entry.get("tagPrefix", "v")

    subs = {}  # field -> new value

    if strategy in ("github-release", "appimage"):
        tag = latest_tag(repo)
        subs["version"] = strip_prefix(tag, tag_prefix)
        url = release_asset(repo, tag, entry["assetMatch"])
        subs[entry.get("hashField", "hash")] = sri_of(url)
    elif strategy == "github-rev":
        rev = entry["rev"]
        url = f"https://github.com/{repo}/archive/{rev}.tar.gz"
        subs[entry.get("revField", "rev")] = rev
        subs[entry.get("hashField", "hash")] = sri_of(url)
        if entry.get("versionField"):
            subs[entry["versionField"]] = entry.get("version", rev)
    else:
        raise SystemExit(f"unknown strategy {strategy!r}")

    for field, value in subs.items():
        nix = set_field(nix, field, value)

    file.write_text(nix)

    if args.build:
        subprocess.run(["nix", "build", f".#{args.attr}", "--no-link"], check=True)


if __name__ == "__main__":
    main()