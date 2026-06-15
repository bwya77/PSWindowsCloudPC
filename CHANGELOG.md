# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-15

### Changed
- `Get-CloudPCUsage` now uses a hybrid signal for `UsageStatus`:
  - **Shared** PCs read `connectivityResult.status` from the Cloud PC service.
  - **Dedicated** PCs check the matching Intune managedDevice's `usersLoggedOn[]` —
    any entry promotes the PC to `inUse`. This is necessary because the Cloud PC
    service rarely flips dedicated PCs to `inUse` (they usually report `available`
    even with an active session). A connectivity status of `unavailable` or
    `failed` is preserved as-is (an offline PC stays offline).
- Removed the `-ActiveWindowMinutes` parameter from `Get-CloudPCUsage` (the
  previous logon-recency heuristic was unreliable).

### Added
- Initial module scaffold.
- `Connect-CloudPC` — idempotent Microsoft Graph sign-in with required scopes
  (`CloudPC.Read.All`, `DeviceManagementManagedDevices.Read.All`, `User.Read.All`, `Group.Read.All`).
- `Get-CloudPC` — list tenant Cloud PCs with normalized objects; filter by
  `-ProvisioningPolicyId`, `-UserPrincipalName`, or `-Type` (Shared/Dedicated/All).
- `Get-CloudPCUsage` — per-PC usage report. Shared PCs read `connectivityResult`
  for status; dedicated PCs use `managedDevice.usersLoggedOn[]` as the canonical
  in-use signal. Resolves display names from UPNs/object ids.
- `Get-CloudPCProvisioningPolicy` — list provisioning policies with resolved
  assignment group names. `-IncludeCloudPCCount` / `-IncludeCloudPCs` switches.
- Pipeline-by-property-name binding: `Get-CloudPCProvisioningPolicy | Get-CloudPC`
  and `... | Get-CloudPCUsage` "just work".
- CI: GitHub Actions workflow for lint + Pester on PR/push (Windows + Linux).
- Release: tag-triggered (`v*`) workflow that publishes to PSGallery.
- `build.ps1` orchestrator (`Lint` / `Test` / `Build` / `Publish`).
- Pester 5 test suite with `Invoke-MgGraphRequest` mocked (no live tenant needed).
