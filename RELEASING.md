# Release process

1. Set `version` to `20261004-vN` and increment `versionCode` in both variants' `module.prop`. The current code is `2026100422`.
2. Rebuild the modern ZIP in `dist/`, including the current `module.prop` and `README.txt`.
3. Update `version`, `versionCode`, and `zipUrl` in `update.json`. Point `zipUrl` to the new release asset. Add the release to `CHANGELOG.md` and `README.md`. Put only the current release in `update-changelog.md` for the manager update dialog.
4. Commit and push `main`.
5. Create release tag `vN` with `QSC-StopCharging_A5-17_vN_20261004.zip` and `QSC-StopCharging_Legacy-Root_vN.zip`.
6. Verify that `update.json` is accessible and valid JSON, the ZIP downloads, and the manager detects the new `versionCode`.

Versions 1 and 2 require a manual update to v3 before in-manager updates become available.
