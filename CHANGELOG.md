# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Changed
- **Breaking**: `Get-CloudPCUsage -CloudPC` now strictly accepts only objects with
  PSTypeName `WindowsCloudPC.CloudPC` (the output of `Get-CloudPC`). Passing
  arbitrary strings or hashtables now fails fast at parameter binding instead of
  silently returning blank rows.
- `Get-CloudPCUsage` now uses the beta
  `/reports/getRealTimeRemoteConnectionStatus(cloudPcId='...')` report as its
  primary signal for `UsageStatus`, for **both** shared and dedicated Cloud PCs.
  `SignInStatus` (`SignedIn`/`NotSignedIn`) drives `UsageStatus`
  (`inUse`/`available`). `connectivityResult.status` is now a fallback used only
  if the report endpoint is unreachable. PCs that have never been signed into
  now correctly report `available` / `NotSignedIn` (previously `unknown`).
- `Get-CloudPCUsage` output now includes three new fields between `UsageStatus`
  and `AssignedUserUpn`: `SignInStatus`, `DaysSinceLastSignIn`, `LastActiveTime`.
  Use `DaysSinceLastSignIn` to find idle PCs without parsing dates.

### Removed
- **Breaking**: `Get-CloudPCUsageBeta` has been removed. Its functionality (the
  real-time report signal) is now the default behavior of `Get-CloudPCUsage`.
  Migrate: replace any `Get-CloudPCUsageBeta` calls with `Get-CloudPCUsage`.

### Fixed
- `Get-CloudPCRealTimeStatus` (internal helper) now correctly handles the
  `application/octet-stream` response that the Graph beta report endpoint
  returns. Previously every call failed with "Please specify '-OutputFilePath'
  or '-InferOutputFileName'" and the function silently returned `$null`.

## [0.1.1] - 2026-06-15
### Added
- `Get-CloudPCUsageBeta` (experimental) — uses the beta
  `/reports/getRealTimeRemoteConnectionStatus(cloudPcId='...')` endpoint to
  return a definitive "is anyone connected right now" signal. Maps
  `SignInStatus` (`SignedIn` / `NotSignedIn`) to `UsageStatus` and surfaces
  `DaysSinceLastSignIn` + `LastActiveTime` for finding idle Cloud PCs.
  Marked `Beta` because the endpoint is on Graph beta; once stable this will
  fold into `Get-CloudPCUsage`.

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
