# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.24] - 2026-06-22
## [0.1.23] - 2026-06-19
### Added
- `Get-CloudPCServicePlan` lists available Windows 365 Cloud PC service plans
  from Microsoft Graph beta, including vCPU, RAM, storage, user profile size,
  plan type, and raw Graph data.
- `Get-CloudPCOrganizationSetting` reads tenant-wide Windows 365 organization
  defaults such as OS version, user account type, MEM auto-enrollment, single
  sign-on, Windows language, and raw Graph data.
- `Invoke-CloudPCEndGracePeriod` ends the grace period for Cloud PCs through
  Microsoft Graph beta. `-All` targets Cloud PCs returned by
  `Get-CloudPC -ProvisioningStatus inGracePeriod`.
- `Rename-CloudPC` renames Cloud PC display names through Microsoft Graph v1.0
  and supports `-WhatIf`, `-Force`, `-PassThru`, object pipeline input, exact
  names, and IDs.
- `Rename-CloudPC -ManagedDeviceName` optionally renames the linked Intune
  managed device through the beta `managedDevices/{id}/setDeviceName` action
  and requests `DeviceManagementManagedDevices.PrivilegedOperations.All` only
  when that path is used.
- `Restore-CloudPC` restores a Cloud PC from a restore point snapshot through
  Microsoft Graph v1.0. It accepts Cloud PC targets with `-SnapshotId` or
  `WindowsCloudPC.Snapshot` pipeline input from `Get-CloudPCSnapshot`.

### Changed
- `Get-CloudPC` now supports direct lookup with `-Id` / `-CloudPcId` and name
  filtering with `-Name` / `-DisplayName` / `-ManagedDeviceName`, including
  wildcard searches.
- `Get-CloudPC` now supports one or more `-ProvisioningStatus` values,
  including `inGracePeriod` and `deprovisioning`, to find Cloud PCs by Graph
  status.
- `Get-CloudPC` now sets `Name` from the Cloud PC `displayName`, the value
  changed by `Rename-CloudPC`, and exposes the Intune device name separately as
  `ManagedDeviceName`.
- Docusaurus command reference generation now classifies `Rename-*` and
  `Restore-*` commands as actions.

## [0.1.22] - 2026-06-19
## [0.1.21] - 2026-06-19
### Added
- `Get-CloudPCReport -ReportName realTimeRemoteConnectionStatus` now calls the
  Graph beta `getRealTimeRemoteConnectionStatus` report function for one Cloud
  PC by ID, or for all Cloud PCs when `-CloudPcId` is omitted.
- `Get-CloudPCReport` now retries Graph 429, 503, and 504 responses, honors
  `Retry-After` when provided, and supports `-RequestDelayMilliseconds` to pace
  tenant-wide real-time status queries.
### Changed
- `Get-CloudPCUsage` now uses `getRealTimeRemoteConnectionStatus` as the
  current sign-in source of truth for dedicated Cloud PCs before falling back to
  connectivity history.
- `Get-CloudPCUsage -CloudPC` now accepts Cloud PC objects, exact Cloud PC IDs,
  or exact Cloud PC names.

## [0.1.20] - 2026-06-19
### Added
- `Get-CloudPCReport` retrieves Windows 365 Cloud PC report stream files from
  Microsoft Graph beta, maps `cloudPcReportName` members to the correct report
  action, parses the returned `Schema` and `Values` payload, and emits typed
  `WindowsCloudPC.ReportRow` objects.
- `Get-CloudPCReport -ReportName` now exposes only reports validated to return
  streams in live testing. Deprecated names, Graph 400 aliases, and enum values
  without callable actions are excluded from parameter binding.

## [0.1.19] - 2026-06-18
## [0.1.18] - 2026-06-18
### Added
- `Get-CloudPCConnectivityHistory` is now a public cmdlet for reading Graph beta
  `cloudPCs/{id}/getCloudPcConnectivityHistory` events by Cloud PC ID or from
  `Get-CloudPC` pipeline input. It emits
  `WindowsCloudPC.CloudPCConnectivityEvent` objects with Cloud PC context,
  activity id, event timestamp, event type, event name, result, message, and raw
  Graph payload.

## [0.1.17] - 2026-06-17
## [0.1.16] - 2026-06-17
### Changed
- `Get-CloudPCUsage` now uses Graph beta
  `cloudPCs/{id}/getCloudPcConnectivityHistory` for dedicated Cloud PC usage
  state, while shared Cloud PCs always use the near-instant
  `cloudPC.connectivityResult.status` endpoint value because connectivity
  history can lag for shared devices. Shared Cloud PCs still use connectivity
  history to populate last sign-in timestamps, and `available` now maps to
  `SignInStatus = NotSignedIn`.
- `Get-CloudPC` now sends `Prefer: include-unknown-enum-members` when selecting
  `connectivityResult` so Graph returns evolvable enum values such as `inUse`
  and `underServiceMaintenance`.

## [0.1.15] - 2026-06-16
## [0.1.14] - 2026-06-16
## [0.1.13] - 2026-06-16
## [0.1.12] - 2026-06-16
## [0.1.11] - 2026-06-16
### Added
- `Get-CloudPCLicensingAllotment` - lists Microsoft Graph cloud licensing
  allotments from Graph beta (`GET /admin/cloudLicensing/allotments`) and gets a
  single allotment by ID. Output includes SKU, allotted units, consumed units,
  available units, assignability, services, subscriptions, waiting members, and
  raw Graph data. Supports `-Select`, `-Expand`, `-Filter`, `-Top`, and `-Apply`
  for testing the beta endpoint.

## [0.1.10] - 2026-06-16
## [0.1.9] - 2026-06-16
### Added
- `Get-CloudPCUserSetting` - lists Windows 365 Cloud PC user settings from
  Graph beta (`GET /deviceManagement/virtualEndpoint/userSettings`), including
  reset, restore point, local admin, cross-region disaster recovery, notification,
  assignment, timestamp, and raw nested setting details.
- `Get-CloudPCSettingProfile` - lists Windows 365 setting profiles from Graph
  beta (`GET /deviceManagement/virtualEndpoint/settingProfiles`). Supports
  single-profile lookup and `-IncludeDetails` to expand assignments and settings,
  including object and list setting children.
- `Get-CloudPCSnapshot` - lists Cloud PC restore point snapshots from Graph beta
  (`GET /deviceManagement/virtualEndpoint/cloudPCs/{id}/retrieveSnapshots`).
  Supports `-Id`, `-CloudPC` object or friendly name, `-User`, and `-All`.
  Snapshot output includes friendly Cloud PC names, timestamps, status, type,
  health check status, and raw Graph data. `-Verbose` reports Cloud PC
  enumeration and per-PC snapshot counts.
- `New-CloudPCSnapshot` - creates Cloud PC restore point snapshots from Graph beta
  (`POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/createSnapshot`).
  Supports one Cloud PC by ID, object, or friendly name, plus `-All`, `-User`,
  and `-ProvisioningPolicyId` batch modes. Optional `-StorageAccountId`,
  `-AccessTier`, `-ExcludeCloudPC`, `-Force`, and `-WhatIf` parameters support
  scoped, auditable snapshot runs.

## [0.1.8] - 2026-06-16
## [0.1.7] - 2026-06-16
### Added
- `Get-CloudPCSupportedRegion` - lists Windows 365 supported Cloud PC regions
  from Graph beta (`GET /deviceManagement/virtualEndpoint/supportedRegions`),
  including `RegionStatus`, `SupportedSolution`, `RegionGroup`, and
  `GeographicLocationType`. Supports client-side filters for status, solution,
  region group, and geographic location type.
- `Get-CloudPCLaunchDetail` - gets Graph launch details for Cloud PCs
  (`GET /me/cloudPCs/{id}/retrieveCloudPcLaunchDetail` or
  `GET /users/{userId}/cloudPCs/{id}/retrieveCloudPcLaunchDetail`), emits
  `CloudPcLaunchUrl`, Windows 365 Switch compatibility fields, and a computed
  `WindowsAppLaunchUri` using the `ms-cloudpc:connect` protocol when a username
  is available. Provisioning PCs that return Graph `NotFound` now emit
  `LaunchDetailStatus = 'Unavailable'` instead of a non-terminating error.

## [0.1.6] - 2026-06-16
## [0.1.5] - 2026-06-16
### Added
- `Restart-CloudPC` — reboot one or more Cloud PCs via Graph
  (`POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/reboot`). Pipeline-
  friendly from `Get-CloudPC`, `SupportsShouldProcess` with
  `ConfirmImpact='High'` (use `-Force` or `-Confirm:$false` to bypass),
  `-PassThru` emits a `WindowsCloudPC.RestartResult`. Auto-adds the
  `CloudPC.ReadWrite.All` scope.
- `Get-CloudPCRemoteActionResult` — recent remote-action history
  (`GET /deviceManagement/virtualEndpoint/cloudPCs/{id}/retrieveCloudPCRemoteActionResults`)
  with `ActionName`, `ActionState`, timestamps, `ManagedDeviceId`, status
  detail, and `HasDownTime`. Sorted most-recent-first. Use immediately after
  `Restart-CloudPC` to confirm the action landed and watch state transition
  from `pending` to `done`.
- `Invoke-CloudPCReprovision` — reprovision one or more Cloud PCs via Graph
  (`POST /deviceManagement/virtualEndpoint/cloudPCs/{id}/reprovision`).
  Pipeline-friendly from `Get-CloudPC`, `SupportsShouldProcess` with
  `ConfirmImpact='High'`, optional `-OsVersion` / `-UserAccountType`, `-Force`,
  and `-PassThru`. Auto-adds the `CloudPC.ReadWrite.All` scope.
- `Invoke-CloudPCPolicyReprovision` — resolves all Cloud PCs assigned to a
  provisioning policy, supports exclusions by name, ID, managed device ID, Azure
  AD device ID, or assigned user UPN, invokes reprovision for included PCs, and
  emits a result row for every included/excluded target.

## [0.1.4] - 2026-06-15
### Changed
- Style-only refactor across every public and private function: each function now
  uses explicit `begin` / `process` / `end` blocks, and `return $var` has been
  replaced with idiomatic bare emission (early exits use bare `return`). No
  behavior change.

## [0.1.3] - 2026-06-15
### Added
- `Get-CloudPCByProvisioningPolicy` — returns one row per provisioning policy
  with a `CloudPCCount` and a nested `CloudPCs` array (real, fetched per-policy
  via `Get-CloudPC`). Empty policies are included with `CloudPCCount = 0` so
  you can spot drift.

### Changed
- **Breaking**: `Get-CloudPC` no longer emits `ConnectivityStatus` or
  `SessionStartDateTime` as top-level properties. The data is unchanged and
  still available under `.Raw.connectivityResult.status` /
  `.Raw.sharedDeviceDetail.sessionStartDateTime`. `Get-CloudPCUsage`
  consumes these from `.Raw` internally and is unaffected.
- **Breaking**: `Get-CloudPCProvisioningPolicy` no longer accepts
  `-IncludeCloudPCCount` / `-IncludeCloudPCs`, and no longer emits the
  always-null `CloudPCCount` and `CloudPCs` properties. Use the new
  `Get-CloudPCByProvisioningPolicy` for those scenarios.

## [0.1.2] - 2026-06-15
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
