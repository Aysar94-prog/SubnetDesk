# Windows accessibility stability mode — Helper 1.5.0 Build137

Live outgoing connections crashed inside Flutter 3.44.1's accessibility tree.
The first repair covered ChildAtIndex. Build135 then failed at GetParent and
AXNodeData::IsIgnored; a later debugger capture showed RAX=UINTPTR_MAX and an
invalid read at 0x47. Build136 rejected that value but failed elsewhere, in
AXNode::ComputeFirstUnignoredChildRecursive at RVA 0x8e3d49. These failures
show that isolated pointer guards do not repair the underlying tree lifetime.
The failed guard experiments and local diagnostics remain under tools/; they
are not the production repair or a deliverable release.

Build137 uses the unmodified pinned SDK engine. The production runner routes
MSAA OBJID_CLIENT and UIA root WM_GETOBJECT requests to DefWindowProc on both
the host and Flutter view HWNDs, including desktop_multi_window views, before
Flutter's provider activates semantics. Other messages retain their original
handler. The subclass removes itself at WM_NCDESTROY. This uses Windows' generic
accessibility proxy rather than the unstable Flutter widget tree.

This is an explicit application-level stability fallback. It limits widget-level
screen-reader/UIA automation inside SubnetDesk; normal window proxies remain.
The user confirmed they do not use a screen reader and authorized this mode.
No system accessibility or security settings are modified. Rendering, input,
network/authentication policies and stored credentials retain their existing paths.
Use screenshots/coordinates to verify the GUI of this build.

The native regression uses a real message-only HWND and sends 4000 signed and
zero-extended provider requests. None may reach a simulated Flutter handler;
other messages, explicit removal and destruction must work. All four runner
CTest checks pass. Build137 packaging reruns those tests and requires the SDK
engine SHA256 a147927018fcc1a843fb3938ead58838d2e185ce7d840bc4191a7a1b90c21015.
Installed main and remote windows expose the intended generic FLUTTERVIEW pane.
The live picture and mouse checks passed. A 30-minute monitored real connection
completed on 2026-11-06 from 00:11:25 to 00:41:25 local time: 120 checks found
the same process alive and TCP established, with no new SubnetDesk crash reports
in the Windows Application log. Physical keyboard delivery subsequently passed: the user typed A in the remote
test window and its receiver-side X11 log confirmed keycode38/keysym0x41 press
and release. Automated key requests alone had not proved it. Build137 is accepted
for the observed scenario. This does not establish that all future failures are
excluded.

The same investigation repaired confy/TOML local-config persistence: empty
favorite/group arrays are omitted and their existing serde defaults restore
empty values. The production writer's regression covers all four empty/populated
combinations and preserves options and UI settings.

`build-accessibility-helper.ps1` defaults to Helper 1.5.0 Build137 with
UseNativeAccessibilityFallback enabled. The older binary-patch scripts and
source equivalent remain unchanged for historical ChildAtIndex repair builds;
they are not applied to Build137. Do not use them to infer live stability.

Official Windows behavior:
- https://learn.microsoft.com/en-us/windows/win32/winauto/handling-the-wm-getobject-message
- https://learn.microsoft.com/en-us/windows/win32/winauto/iaccessible-proxies
- https://learn.microsoft.com/en-us/windows/win32/controls/subclassing-overview
