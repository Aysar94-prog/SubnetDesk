# SubnetDesk Management Console

Deploy 1.10.1 Build125 opens a unified management dashboard with Overview, Devices,
Tasks & history, Helper packages, Server & enrollment, Agent requests and Agent updates. Agent and Domain/WinRM
records share one persistent inventory, with search, transport/status/group
filters, pagination, CSV export, device details and bulk lifecycle actions.
The Devices table offers 21 selectable data columns. Every data header sorts the
full filtered inventory before pagination, with natural name/numeric version/IP
comparison and chronological timestamps. Columns and sort preferences persist
per Windows user under AppData/SubnetDesk Deploy/device-table.json. CSV export
uses the visible columns and current sort order. Action/selection controls are
not data columns.
See [the current setup guide](QUICKSTART-1.6.md) for the complete workflow.

Agent deployment includes credential profile editing and confirmed deletion,
case-insensitive unique profile names, and a visibility toggle for entered
passwords. Stored passwords stay on the server; leaving the password blank on
edit preserves it only when the account is unchanged. Profiles used by queued
or running jobs cannot be changed or deleted, and scheduled profiles cannot be
deleted. Discovery jobs retain grouped failure counts, example targets, and
Windows error codes. Rerun discovery to collect these details for an older job.
Deploy has a gold deployment badge on its application and installer icon.

## Silent Agent setup (Agent 1.7.0+)

Run from an elevated administrator/SYSTEM process on the target PC:

```text
SubnetDeskAgent.exe --install --silent --server PC-Aysar --certificate-sha256 <64-hex-management-certificate-fingerprint>
SubnetDeskAgent.exe --install --silent --server 192.168.50.189 --certificate-sha256 <64-hex-management-certificate-fingerprint>
```

`--server` identifies the management server, not the target PC. A full HTTPS
`/subnetdesk/` URL and custom port are also accepted. A server-configured setup
exported from Deploy 1.9.3+ already includes the public certificate fingerprint;
when its server matches, only `--install --silent --server PC-Aysar` is needed.
The certificate must include the selected hostname/IP in its names.

Setup installs/starts the service and requests administrator approval in Deploy.
Exit 0 means installation/service startup succeeded, not that approval completed.
Exit 2 indicates invalid setup parameters; exit 1 indicates installation failure.
Details go to `%ProgramData%\SubnetDesk Deployment\AgentSetup.log`.
Windows elevation must already be supplied by the push/GPO/admin process to avoid
a UAC prompt. Same-server reinstalls preserve identity. Intended migrations need
`--replace-registration`, the new server fingerprint and fresh server approval;
revoke the previous registration separately. Active Helper/Agent update work
blocks installation. This adds silent local setup, not an initial remote push UI.

## Helper package removal

In Helper packages, use the trash button beside a server library entry and confirm.
Deletion removes its MSI and metadata from the library. Queued/running jobs block
deletion. Installed Helpers and historical job records are unaffected.

## Unattended passwords (Agent 1.5.0+)

Install/update offers an optional unattended password, passed through MSI's
SET_UNATTENDED_PASSWORD / UNATTENDED_PASSWORD_B64 properties. MSI custom-action
support is checked before queuing. Reusing an already-installed MSI version
still applies requested credentials. Initial WinRM deployment uses its existing
password-transfer support. Post-install **Helper security settings → Change unattended access password** currently
requires Agent 1.5.0+, Helper installed and service running. It uses Helper's
password stdin command, then restarts Helper service to reload cached credentials;
active Helper sessions may disconnect. Agent identity and service are independent.

Sensitive job settings are Windows DPAPI-protected at rest with a 24-hour expiry.
They are redacted from inventory/history and decrypted only for the assigned
Agent's authenticated poll over pinned HTTPS. Results/cancellation/revocation/
expiry remove the protected payload. Passwords are not put into process arguments
by Agent; the native MSI API receives the hidden Base64 property, which is encoding
rather than encryption. Interrupted secret-bearing operations are reported as
unknown instead of assuming version/service checks prove password application.

Device-wide Receiver-only controls require Helper 1.4.5+ and Agent 1.6.0+. Tests cover UI validation, MSI property construction,
DPAPI/redaction, compatibility gates and HTTP job lifecycle; actual credential
application, service restart and login on a production target remain untested.

Agent 1.3.1 reads the installed Windows product caption from
[Win32_OperatingSystem](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-operatingsystem),
with the display release and build revision from the 64-bit registry. OS lookup
is cached for five minutes, with an explicit registry fallback if WMI fails.
Authenticated polls/heartbeats refresh the actual source address and machine name;
custom administrator display names are preserved. Device identity and queued work
are independent of hostname and IP. The isolated HTTP integration test switches
between real IPv4/IPv6 connections and reported machine names; it does not rename
a production computer or exercise an actual DHCP renewal.

## Agent updates (Agent 1.4.0+)

Install Agent 1.4.0 once on existing 1.3.x targets with Save & reconnect to retain
identity. In **Agent updates**, upload a newer Agent setup EXE, select it, select
devices, then queue **Update Agent**. Helper packages and actions remain separate.
The authenticated assigned device alone can download its update. SHA256 and
package identity/version are checked before a separate protected worker stops the
service and atomically swaps the runtime with a backup. The new service confirms
its version, hash and unchanged device ID before reporting success. A startup
failure restores the previous runtime; registration and Helper are preserved.
Same/older versions, busy/revoked devices and Agents lacking the update protocol
are skipped. Offline devices retain queued jobs. No arbitrary command endpoint
was added. Files currently carry no enforced Authenticode publisher signature;
package hash validation is not publisher authentication.

Validated: HTTP upload/queue/authorization/download/progress/result contracts,
hash rejection, version gates, atomic file swap/restore and dashboard workflow.
An actual SCM service update/rollback on a target, power-loss recovery and
running Settings-window file-lock scenarios remain to be exercised. An external
worker termination while the service is stopped can require manual recovery.

Two transport paths are available in Deploy:

* **Direct WinRM HTTPS** for domain-managed targets. Domain membership alone does
  not enable remoting: configure WinRM, HTTPS certificates, firewall and admin
  rights through domain policy. Use the target DNS name and a domain account.
* **Agent** for workgroup/local-account targets, or managed devices where inbound
  remoting is undesirable. The Agent polls the management service on the Deploy
  computer using outbound HTTPS 443. No target WinRM setup is required.

The Helper and Deploy MSIs have separate upgrade codes and versions. Agent 1.2
is a standalone EXE with a settings UI and service setup. The
Agent does not include Helper. Deploy uploads exactly the Helper MSI selected by
the administrator. Helper installation keeps its receiver-only/password-unlock
behavior. Agent deployment currently uses the Helper's defaults; it does not
collect or change its unattended-access password.

## Set up the Deploy computer

1. Install the new Deploy MSI. It installs `SubnetDeskManagement`, initially idle
   until explicitly configured. No network settings are changed by MSI install.
2. Open Deploy (it requests administrator access), open **Server & enrollment**,
   choose **Configure / repair server**, enter a stable
   DNS name or IPv4 address assigned to the Deploy computer, then initialize the
   management server.
3. Select the LAN interface/address used by target devices. Setup creates a
   self-signed certificate and HTTP.sys IPv4/IPv6 bindings on port 443. Unrelated
   bindings are never overwritten. A firewall rule on the selected interface
   permits local subnets including Public profiles. Routed subnets require an
   administrator to explicitly extend that firewall rule's remote address scope.
4. Keep the Deploy computer on, with the same address/name. The Windows service
   continues running after closing the Deploy UI.

## Enroll targets

1. Use **Add devices → Install Agent on devices** to export one reusable Agent
   setup for every target. It contains the server address and public certificate
   fingerprint, without enrollment secrets or a 24-hour expiry.
2. Distribute the same setup to all targets. Each creates its own device credential.
3. Open the EXE on the target, accept elevation, then **Install & connect**.
4. The installer creates its Windows service, Apps & Features entry and Start
   menu settings shortcut. No JSON or PowerShell is required. Advanced settings
   still allow importing a registration code or changing the server.

5. In Deploy, open **Agent requests**, verify computer names/source addresses and
   approve or reject selected requests. Pending requests have no job/package access
   and expire after seven days. Diagnostics shows a verification fingerprint that
   can be compared with the request. No code entry is required.
6. A revoked identity remains revoked. Use **Request server approval** on the
   target for a fresh request that requires explicit administrator approval.
   No Windows administrator password is sent to or stored by the Agent.
   A bare installer discovers the server certificate and requires explicit trust
   confirmation; a configured installer already pins that certificate.

Agent registration is an initial provisioning step. It cannot install itself on
an unmanaged machine without an existing authorized installation mechanism.

## Deploy Helper

Browse the Helper MSI, select enrolled devices (or select all), then install/
upgrade. Repair, uninstall and service start/stop/restart need no MSI selection.
Stop/uninstall require confirmation. Cancel only affects queued tasks; assigned
MSI actions are not forcibly interrupted. Task history shows the latest 200
completed/cancelled jobs; stored history remains on the server.
Offline devices stay queued and install when they reconnect. The UI refreshes
every 15 seconds; an Agent is online when seen within the last 90 seconds.
An independent heartbeat continues during installation. The service authenticates each device using its own random credential and checks
that package requests belong to its assigned job. The Agent validates package
SHA256, MSI ProductName, ProductCode and version before invoking Windows Installer,
then verifies the installed version and `SubnetDesk` service. Only the fixed
Helper lifecycle actions are supported; there is no remote shell/command endpoint.

TLS uses an explicitly provisioned SHA256 pin of the management certificate,
including validity checks; the Agent also checks the endpoint hostname. No
Trust-All TLS or TrustedHosts wildcard is installed. Changing or expiring the
certificate requires deliberate target reconfiguration; automatic renewal/pin
rotation is not implemented. Windows Installer packages may execute privileged
custom actions, so only select trusted Helper packages. MSI signature enforcement
is not enabled because existing project releases are unsigned.

## Repair, upgrade and removal

Deploy repair/upgrade preserves protected identities and queue state in
`C:\ProgramData\SubnetDesk Deployment`. Open a newer Agent EXE and choose
**Save & connect** with a blank token to preserve its registration. Legacy Agent
MSI registration is removed during migration to the standalone service under
`C:\Program Files\SubnetDesk Agent Runtime`. **Remove Agent service** preserves
configuration; the EXE can be deleted after closing it. Use **Revoke Agent
access** in Deploy before retiring a device. Revoking blocks future polling and
downloads; it cannot stop an MSI already running. Deploy uninstall removes the
management service but preserves its data, certificate and binding, allowing a
reinstall without silently changing enrolled device trust. Retiring a management
server requires explicit cleanup of those resources by the administrator.

Logs are bounded to approximately 1 MB and contain categories/status rather than
tokens, passwords or request bodies. MSI execution is not forcibly terminated
when the Agent stops. Interrupted installation is reconciled with installed MSI
state; an uncertain failure requires an explicit new deployment job.

## Build with the bundled toolchain

`deployment/build-agent.ps1` uses the specified Visual Studio Build Tools Roslyn
compiler, built-in .NET Framework libraries (no NuGet dependencies), and bundled
WiX. It produces the Agent EXE and management executable. Stage
`SubnetDeskManagement.exe` plus `Initialize-Management.ps1` under `deployment/`
inside the Deploy Flutter bundle before running `res/msi/build-deploy-msi.ps1`.
The payload generator includes the management Windows service automatically.
`deployment/build-release.ps1` builds and packages the complete release with the
separately named `SubnetDeskDeploy.exe`. Legacy Agent MSI output is optional.

## Initial release limits

This release supports Helper lifecycle/version verification and persistent jobs,
enrollment, revocation, online status and bulk selection. It does not yet include
Scheduled Agent rollout policies, fleet-wide concurrency limits, automatic certificate rotation,
cross-subnet discovery, or a remote administration UI on another computer. Bulk
jobs are polled independently by devices with randomized 10–20 second intervals.

## Device-wide receiver policy

From Helper 1.4.5 Build121, every MSI install, reinstall, repair and upgrade
re-applies Receiver-only, including an unlocked managed device policy and older
unlocked account profiles. Stored unlock verifiers, unattended credentials and
device identity are preserved. Unlocking is allowed after installation and
persists across ordinary restarts, until the next installer operation.

Helper 1.4.5 reads HKLM 64-bit `SOFTWARE\SubnetDesk\DevicePolicy\ReceiverPolicy` on
receiver queries, ahead of account-local options. It is one atomic JSON registry
value with schema, locked mode, password verifier and revision. Ordinary Windows
users have read-only access; SYSTEM/Administrators can update it. Portable copies
outside the registered Helper installation retain their own settings. This is
application policy for installed Helper, not OS-wide application execution control.

Deploy exposes device lock, password-verified unlock, and password rotation which
preserves current mode. First adoption via Lock explicitly chooses a new global
lock credential; initial Unlock/Rotate validates the existing background Helper
lock credential. Subsequent locked policy passwords cannot be replaced by Lock.
Unattended credentials are independent. Managed local Settings are read-only and
show device scope; existing outgoing sessions are not forcibly terminated.

The policy intentionally survives Helper/Agent removal and reinstall/upgrade.
Unmanaged clean installs retain the usual receiver-only default. To return a
retired machine to per-account settings, a local administrator can remove only
`ReceiverPolicy` from the above key after reviewing its impact; this does not
promise to unlock any legacy account-local lock. Reinstalling Agent restores
normal dashboard management. Helper upgrade preserves the existing profile;
uninstall/reinstall gets a fresh profile without erasing an explicit device policy.

Rust unit tests cover policy priority and invalid-policy fail-closed behavior.
C# tests cover independent account state, verifier checks, rotation, persistence,
ACL construction and protected task delivery. Real two-account installed Windows
integration and reboot/service verification are still required on a target.
