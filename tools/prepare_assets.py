#!/usr/bin/env python3
"""Extract a verified Minecraft 1.18.2 resource/data ZIP into an ignored working copy.

The source archive is never edited. Existing destination files are not replaced unless
--force is supplied; with --force, differing files are copied to a preservation folder.
"""
from __future__ import annotations
import argparse, csv, hashlib, os, pathlib, shutil, tempfile, zipfile

EXPECTED_SHA256 = "bd6b2db35ab6e92de254a398b30ae56b0884e7f1a9c46490af1378ecc4d18f97"
DEFAULT_ARCHIVE = pathlib.Path("assets/source/minecraft-assets-1.18.2.zip")

def sha256_stream(stream) -> str:
    digest = hashlib.sha256()
    for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
        digest.update(chunk)
    return digest.hexdigest()

def sha256_file(path: pathlib.Path) -> str:
    with path.open("rb") as stream:
        return sha256_stream(stream)

def safe_relative(name: str) -> pathlib.PurePosixPath | None:
    path = pathlib.PurePosixPath(name)
    if path.is_absolute() or not path.parts or any(part in ("", ".", "..") for part in path.parts):
        return None
    if ":" in path.parts[0]:
        return None
    return path

def locate_payload(name: str) -> tuple[str, str] | None:
    """Return (destination area, relative path) for runtime resources/reference data."""
    safe = safe_relative(name)
    if safe is None:
        return None
    parts = safe.parts
    for index in range(len(parts) - 2):
        if parts[index:index + 2] == ("assets", "minecraft") and index + 2 < len(parts):
            return ("resource", "/".join(parts[index + 2:]))
        if parts[index:index + 2] == ("data", "minecraft") and index + 2 < len(parts):
            return ("reference_data", "/".join(parts[index + 2:]))
    # Also support files stored with the domain directory as the archive root.
    return None

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", nargs="?", type=pathlib.Path, default=DEFAULT_ARCHIVE,
                        help=f"source ZIP (default: {DEFAULT_ARCHIVE})")
    parser.add_argument("--asset-destination", type=pathlib.Path, default=pathlib.Path("assets/minecraft"))
    parser.add_argument("--reference-data-destination", type=pathlib.Path, default=pathlib.Path("assets/reference_data/minecraft"))
    parser.add_argument("--force", action="store_true", help="replace differing working-copy files, preserving old bytes")
    parser.add_argument("--allow-hash-mismatch", action="store_true", help="audit/extract a different archive explicitly")
    args = parser.parse_args()
    archive = args.archive.resolve()
    if not archive.is_file():
        print(f"ERROR: source archive not found: {archive}")
        return 2
    digest = sha256_file(archive)
    if digest != EXPECTED_SHA256 and not args.allow_hash_mismatch:
        print(f"ERROR: source SHA-256 mismatch. Expected {EXPECTED_SHA256}, got {digest}")
        return 2

    asset_dest = args.asset_destination.resolve()
    data_dest = args.reference_data_destination.resolve()
    if asset_dest == data_dest or asset_dest in data_dest.parents or data_dest in asset_dest.parents:
        print("ERROR: runtime assets and reference data destinations must not overlap")
        return 2
    asset_dest.parent.mkdir(parents=True, exist_ok=True)
    data_dest.parent.mkdir(parents=True, exist_ok=True)
    report_path = asset_dest.parent / "ASSET_EXTRACTION_MANIFEST.csv"
    staged: list[dict] = []
    names_seen: set[tuple[str, str]] = set()
    with tempfile.TemporaryDirectory(prefix=".asset-extract-stage-", dir=str(asset_dest.parent)) as temporary:
        stage_root = pathlib.Path(temporary)
        try:
            with zipfile.ZipFile(archive) as source:
                bad_member = source.testzip()
                if bad_member is not None:
                    print(f"ERROR: corrupt ZIP member: {bad_member}")
                    return 2
                for info in source.infolist():
                    if info.is_dir():
                        continue
                    located = locate_payload(info.filename)
                    if located is None:
                        continue
                    area, relative = located
                    relative_path = safe_relative(relative)
                    if relative_path is None:
                        print(f"ERROR: unsafe archive member: {info.filename}")
                        return 2
                    identity = (area, relative)
                    if identity in names_seen:
                        print(f"ERROR: two ZIP members target the same output: {identity}")
                        return 2
                    names_seen.add(identity)
                    area_root = asset_dest if area == "resource" else data_dest
                    final_path = area_root.joinpath(*relative_path.parts)
                    # Avoid paths that resolve outside the chosen root.
                    try:
                        final_path.resolve().relative_to(area_root)
                    except ValueError:
                        print(f"ERROR: extraction path escapes destination: {info.filename}")
                        return 2
                    staged_path = stage_root / area / pathlib.Path(*relative_path.parts)
                    staged_path.parent.mkdir(parents=True, exist_ok=True)
                    with source.open(info) as inp, staged_path.open("wb") as out:
                        shutil.copyfileobj(inp, out, length=1024 * 1024)
                    staged_hash = sha256_file(staged_path)
                    if staged_path.stat().st_size != info.file_size:
                        print(f"ERROR: size mismatch after extraction: {info.filename}")
                        return 2
                    staged.append({
                        "archive_path": info.filename, "area": area, "relative_path": relative,
                        "size_bytes": info.file_size, "sha256": staged_hash,
                        "stage_path": staged_path, "final_path": final_path,
                    })
        except (OSError, zipfile.BadZipFile, RuntimeError) as exc:
            print(f"ERROR: extraction staging failed: {exc}")
            return 2

        conflicts: list[dict] = []
        for row in staged:
            final_path: pathlib.Path = row["final_path"]
            if final_path.is_file() and sha256_file(final_path) != row["sha256"]:
                conflicts.append(row)
        if conflicts and not args.force:
            print(f"ERROR: {len(conflicts)} destination file(s) differ; nothing changed. Review and use --force to preserve/replace conflicts.")
            for row in conflicts[:20]:
                print(f"CONFLICT: {row['final_path']}")
            return 3

        for row in staged:
            final_path = row["final_path"]
            final_path.parent.mkdir(parents=True, exist_ok=True)
            if final_path.is_file() and sha256_file(final_path) == row["sha256"]:
                row["status"] = "UNCHANGED_MATCH"
                continue
            if final_path.is_file():
                area_root = asset_dest if row["area"] == "resource" else data_dest
                backup_root = area_root.parent / ".preserved-replacements" / area_root.name
                backup_path = backup_root / row["relative_path"]
                backup_path.parent.mkdir(parents=True, exist_ok=True)
                if backup_path.exists() and sha256_file(backup_path) != sha256_file(final_path):
                    backup_path = backup_path.with_name(backup_path.name + "." + sha256_file(final_path)[:12] + ".bak")
                if not backup_path.exists():
                    shutil.copy2(final_path, backup_path)
            shutil.copy2(row["stage_path"], final_path)
            if sha256_file(final_path) != row["sha256"]:
                print(f"ERROR: final copy hash mismatch: {final_path}")
                return 4
            row["status"] = "EXTRACTED" if not conflicts else "REPLACED_WITH_BACKUP_OR_EXTRACTED"
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with report_path.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=["archive_sha256", "archive_path", "area", "relative_path", "destination_path", "size_bytes", "sha256", "status"])
            writer.writeheader()
            for row in staged:
                writer.writerow({
                    "archive_sha256": digest,
                    "archive_path": row["archive_path"],
                    "area": row["area"],
                    "relative_path": row["relative_path"],
                    "destination_path": str(row["final_path"].relative_to(pathlib.Path.cwd())) if row["final_path"].is_relative_to(pathlib.Path.cwd()) else str(row["final_path"]),
                    "size_bytes": row["size_bytes"],
                    "sha256": row["sha256"],
                    "status": row.get("status", "UNKNOWN"),
                })
    resource_count = sum(1 for row in staged if row["area"] == "resource")
    data_count = sum(1 for row in staged if row["area"] == "reference_data")
    print(f"Source SHA-256: {digest}")
    print(f"ZIP integrity: PASS")
    print(f"Resource files staged: {resource_count}")
    print(f"Reference data files staged: {data_count}")
    print(f"Manifest: {report_path}")
    print("The source archive was not changed. Copied resources are not proof of runtime integration.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
