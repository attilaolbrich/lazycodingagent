# Security policy

## Supported versions

LazyCodingAgent is pre-1.0. We provide security fixes for:

| Version | Supported |
| ------- | --------- |
| Latest [GitHub Release](https://github.com/olbrichattila/lazycodingagent/releases) | Yes |
| `main` branch (current development) | Yes |
| Older releases | Best effort |

Installers and packages from the release page are the recommended way to run
the app. Building from `main` is supported for contributors who need the
latest fixes.

## Reporting a vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Report them through GitHub **private vulnerability reporting**:

<https://github.com/olbrichattila/lazycodingagent/security/advisories/new>

Maintainers will respond on the private advisory thread.

### What to include

- Affected version (release tag, installer name, or commit on `main`)
- Platform (Windows, Linux, macOS) and architecture if relevant
- Impact (what an attacker could do, and whether user interaction is required)
- Steps to reproduce at a high level (avoid posting exploit code in public
  channels before coordination)

We appreciate responsible disclosure and will work with you on timing for a fix
and public disclosure when appropriate.

## Scope notes

This policy covers the LazyCodingAgent application and its first-party source
in this repository. Third-party vendored code under `third_party/` may have its
own maintainers; we still welcome reports if the issue affects LazyCodingAgent
users.

General hardening ideas and non-security bugs belong in the normal issue
tracker, not private advisories.
