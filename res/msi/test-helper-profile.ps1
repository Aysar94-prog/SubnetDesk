param([Parameter(Mandatory = $true)][string]$MsiPath)
$ErrorActionPreference='Stop'
$profileActionDll = Join-Path $PSScriptRoot 'CustomActions\x64\Release\CustomActions.dll'
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class MsiProfileTest {
 [DllImport(@"$profileActionDll", CallingConvention=CallingConvention.StdCall)] public static extern uint GenerateHelperProfileId(uint handle);
 [DllImport("msi.dll",CharSet=CharSet.Unicode)] public static extern uint MsiOpenPackageEx(string path,uint flags,out uint handle);
 [DllImport("msi.dll",CharSet=CharSet.Unicode)] public static extern uint MsiDoAction(uint handle,string action);
 [DllImport("msi.dll",CharSet=CharSet.Unicode)] public static extern uint MsiGetProperty(uint handle,string name,StringBuilder value,ref uint length);
 [DllImport("msi.dll")] public static extern uint MsiCloseHandle(uint handle);
 [DllImport("msi.dll")] public static extern uint MsiSetInternalUI(uint level,IntPtr window);
}
"@
$handle=[uint32]0
$oldUi=[MsiProfileTest]::MsiSetInternalUI(2,[IntPtr]::Zero)
try {
 $code=[MsiProfileTest]::MsiOpenPackageEx((Resolve-Path -LiteralPath $MsiPath).Path,1,[ref]$handle)
 if($code -ne 0){throw "OpenPackage failed: $code"}
 $ids=@()
 for($i=0;$i -lt 2;$i++) {
  $code=[MsiProfileTest]::GenerateHelperProfileId($handle)
  if($code -ne 0){throw "Profile action failed: $code"}
  $text=[Text.StringBuilder]::new(128); $length=[uint32]128
  $code=[MsiProfileTest]::MsiGetProperty($handle,'HELPER_PROFILE_ID',$text,[ref]$length)
  if($code -ne 0){throw "Profile property failed: $code"}
  $ids += [guid]::Parse($text.ToString()).ToString()
 }
 if($ids[0] -eq $ids[1]){throw 'Fresh install did not generate a new profile'}
 'PASS: MSI custom action generates a new valid installation profile ID on each invocation; no installation performed.'
} finally {
 if($handle){[MsiProfileTest]::MsiCloseHandle($handle) | Out-Null}
 [MsiProfileTest]::MsiSetInternalUI($oldUi,[IntPtr]::Zero) | Out-Null
}
