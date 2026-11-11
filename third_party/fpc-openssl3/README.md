# FPC OpenSSL 3 load fix (Linux)

Free Pascal 3.2.x `openssl.pas` tries `libssl.so`, `libssl.so.1.1`, and older sonames, but not `libssl.so.3`. Debian / Raspberry Pi OS bookworm+ ship OpenSSL 3 as `libssl.so.3` only (no `libssl.so` without `libssl-dev`).

This directory contains **vendor copies** of FPC’s OpenSSL package sources. Only `openssl.pas` is modified (`'.3'` added to `DLLVersions` so `LoadLibHack` loads `libssl.so.3` / `libcrypto.so.3`). `opensslsockets.pp` and `fpopenssl.pp` are unmodified companions so Lazarus can rebuild against the patched `openssl` unit.

- **Source:** FPC 3.2.2 `packages/openssl/src/` (LGPL, see FPC `COPYING.FPC`).
- **Project wiring:** `lazycodingagent.lpi` adds `third_party/fpc-openssl3/src` to **Other unit files** so it overrides the system unit for this program only.
- **Maintenance:** When upgrading FPC/Lazarus, diff this file against the new upstream `openssl.pas` and re-apply the `'.3'` entry (or drop this override if upstream includes it).
