param(
    [Parameter(Mandatory = $true)][string]$BundlePath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$namespace = 'http://wixtoolset.org/schemas/v4/wxs'
$bundle = (Resolve-Path -LiteralPath $BundlePath).Path.TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $bundle 'SubnetDesk.exe') -PathType Leaf) -and -not (Test-Path -LiteralPath (Join-Path $bundle 'SubnetDeskDeploy.exe') -PathType Leaf)) {
    throw "Deploy bundle does not contain SubnetDesk.exe: $bundle"
}
if (Get-ChildItem -LiteralPath $bundle -File -Recurse -Filter 'unattended-password.txt') {
    throw 'Refusing to package a bundle containing unattended-password.txt.'
}


function New-StableId([string]$prefix, [string]$value) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($value)))
        $hex = [BitConverter]::ToString([Convert]::FromBase64String($digest)).Replace('-', '').ToLowerInvariant()
        return $prefix + $hex.Substring(0, 16)
    } finally {
        $sha.Dispose()
    }
}

$items = [Collections.Generic.List[object]]::new()
Get-ChildItem -LiteralPath $bundle -File -Recurse |
    Where-Object { $_.Extension -ne '.pdb' } |
    ForEach-Object {
    $relative = $_.FullName.Substring($bundle.Length + 1).Replace('\', '/')
    $items.Add([pscustomobject]@{ Source = $_.FullName; Relative = $relative })
}


$doc = [Xml.XmlDocument]::new()
$doc.AppendChild($doc.CreateXmlDeclaration('1.0', 'utf-8', $null)) | Out-Null
$wix = $doc.CreateElement('Wix', $namespace)
$doc.AppendChild($wix) | Out-Null
$fragment = $doc.CreateElement('Fragment', $namespace)
$wix.AppendChild($fragment) | Out-Null
$dirRef = $doc.CreateElement('DirectoryRef', $namespace)
$dirRef.SetAttribute('Id', 'DEPLOYFOLDER')
$fragment.AppendChild($dirRef) | Out-Null
$dirs = @{ '__ROOT__' = $dirRef }
$components = [Collections.Generic.List[object]]::new()

foreach ($item in ($items | Sort-Object { $_.Relative.ToLowerInvariant() })) {
    $parts = $item.Relative -split '/'
    $parent = '__ROOT__'
    if ($parts.Length -gt 1) {
        foreach ($part in $parts[0..($parts.Length - 2)]) {
            $key = if ($parent -eq '__ROOT__') { $part } else { "$parent/$part" }
            if (-not $dirs.ContainsKey($key)) {
                $directory = $doc.CreateElement('Directory', $namespace)
                $directory.SetAttribute('Id', (New-StableId 'dir' $key))
                $directory.SetAttribute('Name', $part)
                $dirs[$parent].AppendChild($directory) | Out-Null
                $dirs[$key] = $directory
            }
            $parent = $key
        }
    }
    $directoryId = 'DEPLOYFOLDER'
    if ($parent -ne '__ROOT__') { $directoryId = New-StableId 'dir' $parent }
    $componentId = New-StableId 'cmp' $item.Relative
    $fileId = New-StableId 'fil' $item.Relative
    $components.Add([pscustomobject]@{
        Id = $componentId
        FileId = $fileId
        DirectoryId = $directoryId
        Source = $item.Source
    })
}

$group = $doc.CreateElement('ComponentGroup', $namespace)
$group.SetAttribute('Id', 'DeployPayload')
$fragment.AppendChild($group) | Out-Null
foreach ($item in $components) {
    $component = $doc.CreateElement('Component', $namespace)
    $component.SetAttribute('Id', $item.Id)
    $component.SetAttribute('Directory', $item.DirectoryId)
    $component.SetAttribute('Guid', '*')
    $file = $doc.CreateElement('File', $namespace)
    $file.SetAttribute('Id', $item.FileId)
    $file.SetAttribute('Source', $item.Source)
    $file.SetAttribute('KeyPath', 'yes')
    if ([IO.Path]::GetFileName($item.Source) -eq 'SubnetDeskManagement.exe') {
        $service = $doc.CreateElement('ServiceInstall', $namespace)
        $service.SetAttribute('Id', 'InstallManagementService')
        $service.SetAttribute('Name', 'SubnetDeskManagement')
        $service.SetAttribute('DisplayName', 'SubnetDesk Deployment Management')
        $service.SetAttribute('Description', 'Coordinates authenticated outbound Agent deployment over HTTPS.')
        $service.SetAttribute('Type', 'ownProcess')
        $service.SetAttribute('Start', 'auto')
        $service.SetAttribute('ErrorControl', 'normal')
        $service.SetAttribute('Account', 'LocalSystem')
        $component.AppendChild($service) | Out-Null
        $control = $doc.CreateElement('ServiceControl', $namespace)
        $control.SetAttribute('Id', 'ControlManagementService')
        $control.SetAttribute('Name', 'SubnetDeskManagement')
        $control.SetAttribute('Start', 'install')
        $control.SetAttribute('Stop', 'both')
        $control.SetAttribute('Remove', 'uninstall')
        $control.SetAttribute('Wait', 'yes')
        $component.AppendChild($control) | Out-Null
    }
    if ([IO.Path]::GetFileName($item.Source) -in @('SubnetDesk.exe','SubnetDeskDeploy.exe')) {
        $shortcut = $doc.CreateElement('Shortcut', $namespace)
        $shortcut.SetAttribute('Id', 'DeployStartMenuShortcutFile')
        $shortcut.SetAttribute('Name', 'SubnetDesk Deploy')
        $shortcut.SetAttribute('Directory', 'DeployStartMenuDir')
        $shortcut.SetAttribute('Advertise', 'yes')
        $shortcut.SetAttribute('Icon', 'DeployAppIcon.exe')
        $shortcut.SetAttribute('IconIndex', '0')
        $shortcut.SetAttribute('Arguments', '--deploy-helper')
        $shortcut.SetAttribute('WorkingDirectory', 'DEPLOYFOLDER')
        $file.AppendChild($shortcut) | Out-Null
        $remove = $doc.CreateElement('RemoveFolder', $namespace)
        $remove.SetAttribute('Id', 'RemoveDeployStartMenu')
        $remove.SetAttribute('Directory', 'DeployStartMenuDir')
        $remove.SetAttribute('On', 'uninstall')
        $component.AppendChild($remove) | Out-Null
    }
    $component.AppendChild($file) | Out-Null
    $group.AppendChild($component) | Out-Null
}

$fullOutput = [IO.Path]::GetFullPath($OutputPath)
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($fullOutput)) | Out-Null
$settings = [Xml.XmlWriterSettings]::new()
$settings.Encoding = [Text.UTF8Encoding]::new($false)
$settings.Indent = $true
$writer = [Xml.XmlWriter]::Create($fullOutput, $settings)
try { $doc.Save($writer) } finally { $writer.Dispose() }
