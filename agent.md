# Agent Coding Standards

This repository is a production-oriented sing-box gateway UI and installer. Treat every change as network-critical: a small mistake can break DNS, routing, proxy startup, or a user's LAN.

## Core Principles

- Prefer stable, tested behavior over clever changes.
- Keep changes scoped to the requested feature or bug.
- Read the existing code path before editing it.
- Do not add hidden side effects. If a script changes host networking, services, DNS, routing, or firewall state, the behavior must be explicit in code and documented in `README.md`.
- Do not silently fall back from invalid user input to an old/default value. Reject invalid input with a clear error.
- Do not make UI controls look saved when the backend rejected or normalized the value.

## Project-Specific Boundaries

- The installer must use the bundled repository-tested sing-box binary only.
- Do not add `latest`, `custom`, or upstream sing-box auto-download behavior unless the config compatibility strategy is redesigned first.
- The installer must not point host DNS to sing-box.
- The installer must not write public DNS servers to `/etc/resolv.conf`.
- The installer must not rewrite `/etc/resolv.conf` contents or symlink targets.
- If `systemd-resolved` occupies port 53, the installer may only set `DNSStubListener=no`, restart `systemd-resolved`, and wait for port 53 to be released.
- Do not enable `radvd` or advertise this host as an IPv6 gateway by default.
- `radvd` behavior must remain opt-in through an explicit environment variable.
- TProxy should capture FakeIP ranges and avoid proxying node server IPs back through itself.
- IPv4 and IPv6 FakeIP ranges must stay synchronized across DNS fakeip server settings, route rules, and TProxy rules.

## UI Rules

- All editable controls must update in-memory state consistently.
- For text inputs that affect saved config, listen to both `input` and `change` unless there is a specific reason not to.
- Before saving, collect current form values into state again. Do not rely only on prior event handlers.
- Disable save only when there are truly no unsaved changes or an operation is busy.
- After a successful save, reload/render from the backend response so the UI reflects actual persisted state.
- If validation fails, show the backend error and keep the user's current edit visible when possible.
- Avoid one-off dirty-state handling. Use shared helpers such as `markChanged()` or a clearly named equivalent.

## Backend Validation

- Validate all user-controlled config before writing files.
- CIDR values must be real network addresses when used as ranges. For example, accept `29.0.0.0/8`; reject `29.1.2.3/8`.
- Ports must be integers from 1 to 65535.
- Speeds, intervals, and numeric limits must reject invalid, negative, or nonsensical values.
- Node tags must remain unique and must not collide with reserved outbounds such as `Proxy`, `Auto`, `direct`, or `block`.
- Keep staged `sing-box check` before applying saved config.
- On restart failure, roll back to the previous working config.

## Installer Rules

- Keep installer output calm and meaningful.
- Intermediate mirror failures should not look like fatal errors if the installer can safely continue.
- Only print warnings when user action may be needed.
- Always print final access information after successful install:
  - Rule UI URL
  - Rule UI token
  - Clash UI URL
  - Clash API URL
  - Clash secret
- Do not expose internal implementation details such as template node bypass IPs in normal install output.

## Documentation

- Update `README.md` when behavior changes in any of these areas:
  - DNS
  - port 53 handling
  - TProxy
  - FakeIP
  - IPv6 routing
  - installer prompts
  - backup/import/export
  - bundled sing-box version
- Documentation must tell users what the installer does and what it deliberately does not do.
- For small users, be explicit about file paths and when manual router/client DNS configuration is required.

## Required Checks

Run the relevant checks before committing:

```bash
bash -n scripts/install.sh scripts/update-sing-box-rules-jsdelivr
python3 -m py_compile singbox-rule-ui/app.py scripts/bootstrap_config.py scripts/sync_tproxy_setup.py scripts/refresh_runtime_config.py
node --check singbox-rule-ui/static/app.js
```

When touching UI save behavior, also test:

- Editing Auto settings marks the page dirty and persists.
- Editing FakeIP settings marks the page dirty and persists.
- Invalid CIDR shows an error and does not fake a successful save.
- Adding/updating/deleting/enabling/disabling nodes persists correctly.
- Backup export/import still works.

When touching installer behavior, test or reason through:

- Fresh install with `systemd-resolved` occupying port 53.
- Fresh install without `systemd-resolved`.
- Fresh install where zashboard mirror probing fails but fallback succeeds.
- Reinstall on a host that already has sing-box installed.

## Git Hygiene

- Keep commits focused and named after the behavior changed.
- Do not commit unrelated generated files or local test artifacts.
- Do not revert user changes unless explicitly requested.
- Check `git status --short` before and after edits.

