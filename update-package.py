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
        ["gh", "release", "latest", "--repo", repo, "--json", "tagName"],
        capture_output=True, text=True, check=True,
    ).stdout
    return json.loads(out)["tagName"]


def release_asset(repo: str, tag: str, matcher: str) -> str:
    out = subprocess.run(
        ["gh", "release", "view", "--repo", repo, "--tag", tag, "--json", "assets"],
        capture_output=True, text=True, check=True,
    ).stdout
    for a in json.loads(out)["assets"]:
        if re.search(matcher, a["name"]):
            return a["url"]
    raise SystemExit(f"no asset matching {matcher!r} in {repo}@{tag}")


def strip_prefix(s: str, prefix: str) -> str:
    return re.sub(rf"^{re.escape(prefix)}", "", s)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("attr")
    ap.add_argument("--build", action="store_true")
    args = ap.parse_args()

    with CONF.open() as fh:
        data = json.load(fh)
    entry = next(p for p in data["packages"] if p["attr"] == args.attr)

    file = ROOT / entry["file"]
    nix = file.read_text()

    strategy = entry["strategy"]
    repo = entry.get("repo", "")
    tag_prefix = entry.get("tagPrefix", "v")

    subs = {}  # field -> new value

    if strategy == "github-release":
        tag = latest_tag(repo)
        subs["version"] = strip_prefix(tag, tag_prefix)
        asset = entry["assetMatch"]
        url = release_asset(repo, tag, asset)
        subs[entry.get("hashField", "hash")] = sri_of(url)
    elif strategy == "github-rev":
        rev = entry["rev"]
        url = f"https://github.com/{repo}/archive/{rev}.tar.gz"
        subs["rev"] = rev
        subs[entry.get("hashField", "hash")] = sri_of(url)
    elif strategy in ("appimage", "platform-release"):
        tag = latest_tag(repo)
        new_version = strip_prefix(tag, tag_prefix)
        asset = entry["assetMatch"]
        url = release_asset(repo, tag, asset)
        subs["version"] = new_version
        subs[entry.get("hashField", "hash")] = sri_of(url)
        if strategy == "platform-release":
            # hash is a per-platform map
            pass
    else:
        raise SystemExit(f"unknown strategy {strategy!r}")

    # Apply simple field substitutions first
    for field, value in subs.items():
        n, count = re.subn(
            rf'({re.escape(field)}\s*=\s*")[^"]*(")',
            lambda m: m.group(1) + value + m.group(2),
            nix,
        )
        if count == 0:
            raise SystemExit(f"field {field!r} not found (single-line)")

    # Platform hash maps: rewrite inside the {} of a given field.
    if strategy == "platform-release":
        plat_subs = entry.get("hashByPlatform", {})
        n = re.sub(
            rf'({re.escape(entry["hashField"])}\s*=\s*\{{)([^}}]*)(\}})',
            lambda m: m.group(1) + _rewrite_platforms(m.group(2), plat_subs) + m.group(3),
            nix,
        )

    file.write_text(nix)

    if args.build:
        subprocess.run(["nix", "build", f".#{args.attr}", "--no-link"], check=True)


if __name__ == "__main__":
    main()