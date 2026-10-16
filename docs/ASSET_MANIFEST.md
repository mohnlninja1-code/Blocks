# Supplied asset manifest summary

The user's original `minecraft-assets-1.18.2.zip` was audited locally and remains unchanged outside the project bundle. The complete file-by-file CSV is included in the downloadable project ZIP. In this repository it is stored compactly as `docs/ASSET_MANIFEST.csv.gz.b64`; decode using `base64 -d docs/ASSET_MANIFEST.csv.gz.b64 | gzip -d > docs/ASSET_MANIFEST.csv`.

- Non-directory source archive entries: **14,459**.
- Uncompressed source asset bytes: **532,470,059**.
- Selected assets with explicit live consumers: **75**.
- Remaining entries are recorded as `NOT_INTEGRATED_FEATURE_PENDING`, `NOT_CONSUMED_BY_RUNTIME`, or `NOT_INTEGRATED`. The presence of a resource-pack file is not counted as runtime integration.

| Audit status | Entries |
|---|---:|
| `INTEGRATED_REFERENCED` | 75 |
| `NOT_CONSUMED_BY_RUNTIME` | 5,995 |
| `NOT_INTEGRATED_FEATURE_PENDING` | 4,976 |
| `NOT_INTEGRATED` | 3,413 |

`docs/ASSET_USAGE.csv` provides the path, intended in-game role, consumer and current runtime-validation limitations for every one of the 75 integrated files. Source path references are traceable to the uploaded archive prefix. Audio playback and renderer output remain runtime-unverified until Godot and Android checks are complete.
