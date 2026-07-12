# Screen Time Manager Installer and Service Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Produce a Windows installer and an automatic Windows service that launches and restarts the existing interactive Screen Time Manager application.

**Architecture:** Keep the existing UI behavior as the default process mode and add a `--service` mode to the same executable. The service runs as LocalSystem, launches the UI in the active user session, restarts it after unexpected exits, and is registered and removed by an Inno Setup installer.

**Tech Stack:** Rust 2021, `windows` crate, `windows-service`, Inno Setup 6, PowerShell, GitHub Actions on `windows-latest`.

---

### Task 1: Extract process-mode selection

**Files:**
- Create: `src/run_mode.rs`
- Modify: `src/main.rs`

**Step 1: Write the failing tests**

Add unit tests proving that no flag selects UI mode and the exact `--service` flag selects service mode. Unknown flags must remain UI arguments and must not accidentally start the privileged service path.

**Step 2: Run the tests to verify RED**

Run on Windows CI or a Rust-enabled host:

```powershell
cargo test run_mode
```

Expected: compilation fails because `run_mode` does not exist.

**Step 3: Write the minimum implementation**

Add a small `RunMode` enum and a parser over `std::env::args_os()`. Change `main` to dispatch to the unchanged UI entrypoint or the new service entrypoint placeholder.

**Step 4: Run the tests to verify GREEN**

Run `cargo test run_mode`; expected: all run-mode tests pass.

**Step 5: Commit**

```bash
git add src/run_mode.rs src/main.rs
git commit -m "refactor: separate UI and service run modes"
```

### Task 2: Define restart policy as testable logic

**Files:**
- Create: `src/service/restart_policy.rs`
- Create: `src/service/mod.rs`

**Step 1: Write the failing tests**

Test that a normally running child restarts after a short delay, repeated quick failures increase delay up to a fixed maximum, and an explicit service stop never restarts the child.

**Step 2: Run the tests to verify RED**

Run `cargo test restart_policy`; expected: missing policy types/functions.

**Step 3: Write the minimum implementation**

Implement a small state object using `Duration`, with fixed constants and no configurable policy framework.

**Step 4: Run the tests to verify GREEN**

Run `cargo test restart_policy`; expected: all policy tests pass.

**Step 5: Commit**

```bash
git add src/service
git commit -m "feat: add bounded service restart policy"
```

### Task 3: Implement the Windows service lifecycle

**Files:**
- Modify: `Cargo.toml`
- Modify: `src/service/mod.rs`
- Create: `src/service/windows_service.rs`
- Modify: `src/main.rs`

**Step 1: Write the failing compile-time/service-name test**

Add tests for the stable internal service name and display name. Keep Windows API calls behind the service module boundary.

**Step 2: Run the tests to verify RED**

Run `cargo test service`; expected: missing service constants/entrypoint.

**Step 3: Write the minimum implementation**

Add `windows-service` and the exact `windows` features needed for Terminal Services, environment blocks, security tokens, process creation and event logging. Register a service dispatcher, accept STOP and SHUTDOWN controls, and report StartPending, Running, StopPending and Stopped states.

The service loop must:

- discover the active console session;
- obtain and duplicate its user token;
- create the user environment;
- launch the current executable without `--service` using `CreateProcessAsUserW`;
- wait for either child exit or service stop;
- apply the tested restart policy;
- close every Windows handle on every path.

Do not add process hiding, administrator-tool blocking or kernel components.

**Step 4: Run tests and build on Windows**

```powershell
cargo test
cargo build --release
```

Expected: zero failed tests and `target\release\screen-time-manager.exe` exists.

**Step 5: Commit**

```bash
git add Cargo.toml Cargo.lock src/main.rs src/service
git commit -m "feat: add Windows watchdog service mode"
```

### Task 4: Add service event logging

**Files:**
- Create: `src/service/event_log.rs`
- Modify: `src/service/windows_service.rs`

**Step 1: Write the failing formatter tests**

Test sanitized, concise messages for service start, no active session, child launch failure, child exit and service stop. Verify messages never include application configuration values.

**Step 2: Run the tests to verify RED**

Run `cargo test event_log`; expected: missing formatter functions.

**Step 3: Implement minimal Event Log output**

Use a stable event source name. If Event Log registration or writing fails, continue service operation; logging failure must not create a restart loop.

**Step 4: Run the tests to verify GREEN**

Run `cargo test event_log`; expected: all formatter tests pass.

**Step 5: Commit**

```bash
git add src/service
git commit -m "feat: log watchdog lifecycle events"
```

### Task 5: Create the graphical installer

**Files:**
- Create: `installer/screen-time-manager.iss`
- Create: `scripts/install-service.ps1`
- Create: `scripts/uninstall-service.ps1`
- Create: `tests/installer.Tests.ps1`
- Modify: `install.ps1`
- Modify: `uninstall.ps1`
- Modify: `README.md`

**Step 1: Write failing Pester/static tests**

Tests must prove the installer:

- requires administrative privileges;
- installs under Program Files;
- registers the stable service name with `start= auto` and the quoted `--service` command;
- configures Windows service recovery;
- starts the service after install;
- stops and deletes the service before uninstall removes files;
- removes the legacy scheduled task to prevent double startup.

**Step 2: Run tests to verify RED**

Run:

```powershell
Invoke-Pester tests/installer.Tests.ps1
```

Expected: failures because installer and service scripts do not exist.

**Step 3: Implement the minimum installer**

Add an Inno Setup script producing `ScreenTimeManager-Setup-<version>.exe`. Use PowerShell helper scripts for idempotent service registration/removal and legacy scheduled-task cleanup. Keep application data by default and document manual deletion.

The legacy root install/uninstall scripts should explain the migration path or delegate safely; they must not create a second scheduled task.

**Step 4: Run tests and compile installer**

```powershell
Invoke-Pester tests/installer.Tests.ps1
iscc installer\screen-time-manager.iss
```

Expected: tests pass and one installer executable is produced under `dist\`.

**Step 5: Commit**

```bash
git add installer scripts tests install.ps1 uninstall.ps1 README.md
git commit -m "feat: add Windows setup installer"
```

### Task 6: Add Windows CI verification and artifacts

**Files:**
- Create: `.github/workflows/installer-ci.yml`
- Modify: `.github/workflows/release.yml`

**Step 1: Write the workflow assertions first**

Extend the installer static tests so they fail unless CI runs `cargo test`, release build, Pester, Inno Setup compilation and artifact upload.

**Step 2: Run static tests to verify RED**

Run `Invoke-Pester tests/installer.Tests.ps1`; expected: missing workflow steps.

**Step 3: Implement minimal workflows**

Add pull-request/push CI on `windows-latest`. Update release packaging to attach the generated setup executable while retaining the ZIP temporarily for compatibility.

**Step 4: Run local syntax checks and Windows CI**

Verify YAML parses, push only after explicit user authorization, and then require all Windows jobs to pass. Do not claim installer build success from local Mac checks.

**Step 5: Commit**

```bash
git add .github/workflows tests/installer.Tests.ps1
git commit -m "ci: build and verify Windows installer"
```

### Task 7: Perform Windows integration verification

**Files:**
- Create: `docs/testing/windows-installer-checklist.md`

**Step 1: Install on a disposable Windows 10/11 VM**

Record installer version, Windows version and test time. Do not use a production child computer for the first run.

**Step 2: Verify service startup**

Run `Get-Service ScreenTimeManagerService` and `sc.exe qc ScreenTimeManagerService`. Expected: Running, Automatic, LocalSystem, correctly quoted binary path with `--service`.

**Step 3: Verify interactive launch and recovery**

Confirm tray/timer UI appears after login. End only `screen-time-manager.exe` in the interactive session and verify the service starts a replacement within the bounded delay.

**Step 4: Verify reboot and uninstall**

Reboot, confirm service and UI return, then uninstall. Expected: service and Program Files installation are removed; user data remains unless deliberately deleted.

**Step 5: Record limitations and commit evidence**

Document that an administrator can still stop/delete the service. Never describe this build as administrator-proof.

```bash
git add docs/testing/windows-installer-checklist.md
git commit -m "docs: add Windows installer verification checklist"
```

### Task 8: Archive the conversation in the controlling project

**Files:**
- Create: `/Users/willyoung/Documents/GitHub/20_Skills/docs/chats/2026-07-12-屏幕时间管理器安装与守护改造-conversation.md`

**Step 1: Write the archive**

Record the task, key decisions, errors and corrections, final status, lessons and key paths. Do not record credentials or sensitive values.

**Step 2: Verify the archive**

Run Markdown checks or at minimum `git diff --check` in `20_Skills` and review the file for sensitive content.

**Step 3: Keep repository boundaries explicit**

The archive belongs to `20_Skills`; implementation commits belong to the downloaded project worktree. Do not mix them into one Git status or claim.
