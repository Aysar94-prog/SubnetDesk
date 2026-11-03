# Managed Helper lifecycle

The design uses the same broad administration patterns documented by
[Kaspersky Security Center](https://support.kaspersky.com/KSC/14/en-US/202480.htm)
and [Microsoft Intune](https://learn.microsoft.com/en-us/intune/device-management/tools/management-extension-windows):
device enrollment, per-device application inventory, explicit lifecycle tasks,
asynchronous execution, and observable per-device results. No proprietary code,
branding, or interface assets are copied.

## Implemented

* Independent Windows process/window identity for Deploy and Helper.
* Standalone Agent EXE with administrator settings UI, connection testing,
  server migration using fresh enrollment, and local service setup.
* Registration code copy/paste and optional bulk enrollment file export.
* Direct domain WinRM HTTPS and outbound Agent transports.
* Fixed Helper install/upgrade, repair, uninstall, start, stop, restart actions.
* MSI Helper-family UpgradeCode validation in the Agent path; no arbitrary shell.
* Persisted per-device queues, offline delivery, durable result outbox,
  interrupted-install reconciliation, and independent heartbeat during execution.
* Helper version/service inventory, Agent version, completed/cancelled task
  history, queued cancellation, and Agent revocation.
* New actions require Agent 1.1; existing 1.0 Agents can still install Helper.
* Installer package hashes plus pinned TLS, and administrator-only local config.
* Selected LAN firewall interface, local-subnet source scope, IPv4/IPv6 bindings.

## Operational boundaries

The administration UI currently runs on the management computer as a local
administrator. Multi-operator RBAC/MFA, internet tenant isolation, signed package
policy, certificate rotation, maintenance windows, scheduled Agent rollouts,
and server-wide concurrency limits are future work, not delivered features.
This is a bounded Helper-management implementation, not feature parity with an
enterprise endpoint-management suite. Production readiness requires actual
device deployment and fault/recovery tests beyond build/unit validation.

Cancellation only stops queued work. Once assigned, an MSI operation is not
forcibly terminated. Uninstall/stop require confirmation in the UI. Agent
uninstall and Helper uninstall are separate operations. There is no remote
arbitrary process or PowerShell execution endpoint in the Agent protocol.
