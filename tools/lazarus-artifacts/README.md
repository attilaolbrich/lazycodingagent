# Local Lazarus CI artifacts (optional)

GitHub Actions and the `ci-install-lazarus-*` scripts can download pinned Lazarus 4.8 / FPC blobs from SourceForge. To avoid slow or flaky downloads (for example on self-hosted runners or [act](https://github.com/nektos/act)), place the files below in this folder.

Filenames and URLs are defined in [`scripts/lazarus-ci-artifacts.json`](../../scripts/lazarus-ci-artifacts.json). Resolver order: this folder (or `LAZARUS_ARTIFACTS_DIR`) → CI workdir cache → SourceForge (or `LAZARUS_SF_MIRROR` as the base URL override).

## Files by CI target

| Target | Files |
|--------|--------|
| `windows-win64` | `lazarus-4.8-fpc-3.2.2-win64.exe` |
| `macos-aarch64` | `fpc-3.2.4rc1a.intelarm64-macosx.dmg`, `lazarus-darwin-aarch64-4.8.zip` |
| `macos-x86_64` | `fpc-3.2.4rc1a.intelarm64-macosx.dmg`, `lazarus-darwin-x86_64-4.8.zip` |

## Populate

```bash
# all targets
./scripts/prefetch-lazarus-ci-artifacts.sh

# one target
./scripts/prefetch-lazarus-ci-artifacts.sh windows-win64
```

On Windows:

```powershell
./scripts/prefetch-lazarus-ci-artifacts.ps1
./scripts/prefetch-lazarus-ci-artifacts.ps1 -TargetId macos-aarch64
```

Large binaries are gitignored; only this README is tracked.
