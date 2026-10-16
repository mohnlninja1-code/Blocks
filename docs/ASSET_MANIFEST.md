# Supplied asset archive manifest

The archive `minecraft-assets-1.18.2.zip` was verified on 2026-10-16.

- SHA-256: `bd6b2db35ab6e92de254a398b30ae56b0884e7f1a9c46490af1378ecc4d18f97`
- Non-directory files: 14,459
- Uncompressed bytes: 532,470,059
- ZIP member integrity: PASS
- JSON files parsed: 8,311; invalid JSON files: 0
- Item model JSONs: 1,235
- Block model JSONs: 1,725
- Blockstate JSONs: 900
- Recipe JSONs: 1,058

The ZIP was not modified, and its potentially restricted third-party payload is not committed to this public repository.

## Reproducible audit

Run:

```sh
python3 tools/audit_source_archive.py /path/to/minecraft-assets-1.18.2.zip --out docs/audit-generated
```

The script tests ZIP integrity and emits:
- `ASSET_MANIFEST.csv`: one row per source file, with per-file SHA-256 and initial disposition.
- `ASSET_USAGE.csv`: intended role and current runtime consumer evidence.
- `ITEM_MODELS.csv`: every item model JSON, parent, texture layers, transforms and overrides.
- `BLOCK_MECHANICS.csv`: every blockstate mapping JSON with variant/multipart references and implementation/test status.
- `RECIPE_COVERAGE.csv`: every recipe JSON with its type/output/ingredient source definitions.
- `ARCHIVE_AUDIT_REPORT.json`: machine-readable counts and reconciliation status.

A metadata-only audit bundle with these generated files was produced during the current session. The generated CSV files are not yet committed into this repository; the generator and baseline report are version-controlled. Source-file presence is never sufficient evidence of runtime integration.

## Integration policy

Every source entry starts with an explicit disposition. Rows have an empty consumer unless a real runtime callsite is proven. A model is not integrated until its parent/geometry/texture mapping renders in relevant contexts and its behavior works; a recipe is not integrated until transactions and station rules pass tests. Do not use file counts as feature-completion counts.

The handoff's targets of 332 missing mechanics and 791 missing item models cannot yet be reconciled to named ID lists. The archive contains 1,235 source item model definitions, which is not equivalent to the number of missing runtime models. Do not create fabricated filler rows to force counts.
