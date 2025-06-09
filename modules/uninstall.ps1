#
# ----------------
# DotMan Uninstall
# Module
# ----------------
#
# A modular, open-source and multiplatform manager for .NET
#
# https://github.com/reallukee/dotman
#
# By Luca Pollicino (https://github.com/reallukee)
#
# uninstall.ps1
#
# Licensed under the MIT license!
#

param (
    [Parameter(Position = 0)]
    [ValidateSet(
        "SDK",
        "Runtime",
        "NetCoreRuntime",
        "DesktopCoreRuntime",
        "AspNetCoreRuntime"
    )]
    [string] $Target,

    [switch] $About,
    [switch] $Version,
    [switch] $Help,

    [ValidateSet(
        "System",
        "Local",
        "Custom"
    )]
    [string] $Path = "System",
    [string] $CustomPath,

    [string] $Channel,
    [string] $Runtime,
    [string] $XVersion,

    [switch] $NoCache
)



#
# Output
#

function Write-Output-Error {
    param (
        [string] $Message
    )

    Write-Host -Message "-------------" -ForegroundColor Red
    Write-Host -Message "YOOOOO! [>:(]" -ForegroundColor Red
    Write-Host -Message "DOTMAN   /|\ " -ForegroundColor Red
    Write-Host -Message "ERROR    / \ " -ForegroundColor Red
    Write-Host -Message "-------------" -ForegroundColor Red

    Write-Host -Message ""

    Write-Host -Message "[ERROR] ${Message}" -ForegroundColor Red
}

function Write-Output-Fail {
    param (
        [string] $Message
    )

    Write-Host -Message "[FAIL] ${Message}" -ForegroundColor Red
}



#
# Requirements
#

if (-not $IsMacOS -and $Path -eq "System") {
    exit 1
}

if ($IsWindows) {
    exit 1
}

$PowerShellVersion = [version]$PSVersionTable.PSVersion

if ($PowerShellVersion -lt [version]"5.1.0.0") {
    Write-Output-Error -Message "PowerShell 5.1+ is required!"

    exit 1
}

if ($PowerShellVersion -lt [version]"7.0.0.0") {
    Write-Warning -Message "PowerShell 7+ is recommended!"
}



#
# General Options
#

$COMMAND_NAME = "uninstall"

$ABOUT_FILE   = "${PSScriptRoot}/../abouts/${COMMAND_NAME}.about"
$VERSION_FILE = "${PSScriptRoot}/../versions/${COMMAND_NAME}.version"
$HELP_FILE    = "${PSScriptRoot}/../helps/${COMMAND_NAME}.help"

function Read-File {
    param (
        [string] $File
    )

    if (-not (Test-Path -Path $File -PathType Leaf)) {
        Write-Output-Error -Message "Can't find `"${File}`"!"

        exit 1
    }

    try {
        $Content = Get-Content -Path $File -Encoding utf8 -Raw

        $Placeholders = @{
            "A.B.C"            = Read-Version -Key "Display_Version"
            "@DISPLAY_VERSION" = Read-Version -Key "Display_Version"
            "@VERSION"         = Read-Version -Key "Version"
            "@MIN_VERSION"     = Read-Version -Key "Min_Version"
        }

        foreach ($Key in $Placeholders.Keys) {
            $Value = $Placeholders[$Key]

            $Content = $Content -replace [regex]::Escape($Key), $Value
        }

        $Content = $Content -split "`r?`n" | Where-Object {
            $PSItem -notmatch "^\s*#"
        }

        $Content
    }
    catch {
        Write-Output-Error -Message "Can't read `"${File}`"!"

        exit 1
    }
}

function Read-Version {
    param (
        [string] $Key
    )

    if (-not (Test-Path -Path $VERSION_FILE -PathType Leaf)) {
        Write-Output-Error -Message "Can't find `"${VERSION_FILE}`"!"

        exit 1
    }

    try {
        $Version = Get-Content -Path $VERSION_FILE -Encoding utf8 | Where-Object {
            $PSItem -match "^${Key}="
        } | Select-Object -First 1

        $Version = ($Version -split "=", 2)[1].Trim()
    }
    catch {
        Write-Output-Error -Message "Can't read `"${VERSION_FILE}`"!"

        exit 1
    }

    return $Version
}

if ($About) {
    Read-File -File $ABOUT_FILE

    exit 0
}

if ($Version) {
    Read-Version -Key "Version"

    exit 0
}

if ($Help -or -not $PSBoundParameters.Count) {
    Read-File -File $HELP_FILE

    exit 0
}



#
# Exclusions
#

if ($Path -eq "System") {
    if ([System.Environment]::UserName -ne "root") {
        Write-Output-Error -Message "root is required!"

        exit 1
    }
}

if (-not $Target) {
    exit 1
}

if (-not $Channel -and $Runtime) {
    exit 1
}

if ($XVersion -and $Channel) {
    exit 1
}

if ($Path -eq "Custom" -and -not $CustomPath) {
    exit 1
}



#
# Database
#

$DATABASE_BASE_URI = "https://builds.dotnet.microsoft.com/dotnet/release-metadata"

function Receive-Database {
    param (
        [string] $Uri,
        [string] $LocalFile
    )

    if (-not $Uri) {
        Write-Output-Error -Message "Can't find `"${LocalFile}`"!"

        exit 1
    }

    try {
        $Response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
        $Content = $Response.Content
        $Data = $Content | ConvertFrom-Json

        if (-not $NoCache) {
            $Content | Set-Content -Path $LocalFile -Encoding utf8
        }
    }
    catch {
        Write-Output-Error -Message "Can't read `"${LocalFile}`"!"

        exit 1
    }

    return $Data
}

function Read-Database {
    param (
        [string] $Uri
    )

    $CacheFolder = "${PSScriptRoot}/../.cache"

    $LocalFile = $Uri -replace [regex]::Escape($DATABASE_BASE_URI), $CacheFolder
    $RemoteFile = Invoke-WebRequest -Uri $Uri -Method Head -UseBasicParsing

    if (-not $NoCache) {
        $CachePath = Split-Path -Path $LocalFile -Parent

        if (-not (Test-Path -Path $CachePath -PathType Container)) {
            New-Item -Path $CachePath -ItemType Directory -Force | Out-Null
        }
    }

    if (Test-Path -Path $LocalFile -PathType Leaf) {
        $LocalDate = (Get-Item $LocalFile).LastWriteTime
        $RemoteDate = [datetime]::Parse($RemoteFile.Headers["Last-Modified"])

        if ($RemoteDate -gt $LocalDate) {
            $Data = Receive-Database -Uri $Uri -LocalFile $LocalFile
        } else {
            try {
                $Content = Get-Content -Path $LocalFile -Encoding utf8 -Raw
                $Data = $Content | ConvertFrom-Json
            }
            catch {
                exit 1
            }
        }
    } else {
        $Data = Receive-Database -Uri $Uri -LocalFile $LocalFile
    }

    return $Data
}



#
# DotNet
#

switch ($Path) {
    "System" {
        if ($IsMacOS) {
            $DOTNET_PATH = "/usr/local/share/dotnet"
        }

        if ($IsLinux) {
            $DOTNET_PATH = "/usr/share/dotnet"
        }

        if ($IsWindows) {
            $DOTNET_PATH = "C:/Program Files/dotnet"
        }
    }

    "Local" {
        $DOTNET_PATH = "${HOME}/.dotnet"
    }

    "Custom" {
        if ($CustomPath) {
            $DOTNET_PATH = $CustomPath
        } else {
            exit 1
        }
    }
}

if (-not $DOTNET_PATH) {
    # Write-Output-Error -Message "Can't determine .NET path!"

    # exit 1
}

if (-not (Test-Path -Path $DOTNET_PATH -PathType Container)) {
    # Write-Output-Error -Message "Can't find .NET path!"

    # exit 1
}

function Get-DotNet-Target-Path {
    $DotNetPaths = @{
        "SDK"                = "${DOTNET_PATH}/sdk"
        "Runtime"            = "${DOTNET_PATH}/shared/Microsoft.NETCore.App"
        "NetCoreRuntime"     = "${DOTNET_PATH}/shared/Microsoft.NETCore.App"
        "DesktopCoreRuntime" = "${DOTNET_PATH}/shared/Microsoft.WindowsDesktop.App"
        "AspNetCoreRuntime"  = "${DOTNET_PATH}/shared/Microsoft.AspNetCore.App"
    }

    $DotNetPath = $DotNetPaths[$Target]

    if (-not $DotNetPath) {
        # Write-Output-Error -Message "Can't determine .NET target path!"

        # exit 1
    }

    if (-not (Test-Path -Path $DotNetPath -PathType Container)) {
        # Write-Output-Error -Message "Can't find .NET target path!"

        # exit 1
    }

    return $DotNetPath
}

function Get-Locals {
    $DotNetTargetPath = Get-DotNet-Target-Path

    $Locals = @()

    if (Test-Path -Path $DotNetTargetPath -PathType Container) {
        try {
            $Locals = Get-ChildItem -Path $DotNetTargetPath -Directory | Select-Object -ExpandProperty "Name"
        }
        catch {
            Write-Output-Error -Message "Can't read `"${DotNetTargetPath}`"!"

            exit 1
        }
    }

    return $Locals
}

function Get-OS {
    if ($IsWindows) {
        return "win"
    }

    if ($IsLinux) {
        return "linux"
    }

    if ($IsMacOS) {
        return "osx"
    }

    return "unknown"
}

function Get-Architecture {
    $Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture

    switch ($Architecture) {
        "X64"   { return "x64" }
        "X86"   { return "x86" }
        "Arm"   { return "arm" }
        "Arm64" { return "arm64" }
        default { return "unknown" }
    }
}

function Get-RID {
    $OS = Get-OS
    $Architecture = Get-Architecture

    if ($OS -eq "unknown" -or $Architecture -eq "unknown") {
        Write-Output-Error -Message "Unsupported platform!"

        exit 1
    }

    $RID = "${OS}-${Architecture}"

    return $RID
}

function Get-Tag {
    param (
        [string] $Version
    )

    if ($Version -match "preview") {
        return "preview"
    }

    if ($Version -match "rc") {
        return "rc"
    }

    return "release"
}



function Get-Output-Object {
    param (
        [object] $ReleaseIndex,
        [object] $Channel,
        [object] $Runtime,
        [object] $Release,
        [bool]   $UseValidTarget
    )

    if ($UseValidTarget) {
        $FixedRelease = $Release."${ValidTarget}"
    } else {
        $FixedRelease = $Release
    }

    $Tag = Get-Tag -Version $FixedRelease."version"

    if ($FixedRelease."runtime-version") {
        $RuntimeVersion = $FixedRelease."runtime-version"
    } else {
        $RuntimeVersion = $FixedRelease."version"
    }

    $Object = [PSCustomObject]@{
        "Type"    = $PrintableTarget

        "Channel" = $ReleaseIndex."channel-version"

        "Version" = $FixedRelease."version"
        "Display" = $FixedRelease."version-display"
        "Runtime" = $RuntimeVersion

        "Tag"     = $Tag

        "Files"   = $FixedRelease."files"
    }

    return $Object
}

function Get-Data {
    param (
        [object] $ReleasesIndexData
    )

    $Output = $ReleasesIndexData."releases-index" | ForEach-Object {
        $ReleasesUri = $PSItem."releases.json"

        $ReleasesData = Read-Database -Uri $ReleasesUri

        $ReleaseIndexData = $PSItem
        $ChannelData = $ReleasesData

        $MultipleReleases = $Target -eq "sdk"

        $ChannelData."releases" | ForEach-Object {
            $RuntimeData = $PSItem
            $ReleaseData = $PSItem

            if ($MultipleReleases) {
                $RuntimeData."${ValidTarget}s" | ForEach-Object {
                    $ReleaseData = $PSItem

                    Get-Output-Object `
                        -ReleaseIndex $ReleaseIndexData `
                        -Channel $ChannelData `
                        -Runtime $RuntimeData `
                        -Release $ReleaseData `
                        -UseValidTarget $false
                }
            } else {
                Get-Output-Object `
                    -ReleaseIndex $ReleaseIndexData `
                    -Channel $ChannelData `
                    -Runtime $RuntimeData `
                    -Release $ReleaseData `
                    -UseValidTarget $false
            }
        }
    }

    return $Output
}



function Uninstall {
    param (
        [object] $Output
    )

    $Version = $Output."version"
    $TargetPath = Get-DotNet-Target-Path
    $TargetPathVersion = "${TargetPath}/${Version}"

    if (Test-Path -Path $TargetPathVersion -PathType Container) {
        try {
            Remove-Item -Path $TargetPathVersion -Recurse -Force | Out-Null
        }
        catch {
            exit 1
        }
    }
}

function Uninstall-Channel {
    param (
        [object] $ReleasesIndexData
    )

    $Locals = Get-Locals

    $Output = Get-Data -ReleasesIndexData $ReleasesIndexData

    $Output = $Output | Where-Object {
        $PSItem."Channel" -eq $Channel
    } | Select-Object -First 1

    if (-not ($Locals -contains $Output."version")) {
        exit 0
    }

    Uninstall -Output $Output
}

function Uninstall-Runtime {
    param (
        [object] $ReleasesIndexData
    )

    $Locals = Get-Locals

    $Output = Get-Data -ReleasesIndexData $ReleasesIndexData

    $Output = $Output | Where-Object {
        $PSItem."Runtime" -eq $Runtime
    } | Select-Object -First 1

    if (-not ($Locals -contains $Output."version")) {
        exit 1
    }

    Uninstall -Output $Output
}

function Uninstall-XVersion {
    param (
        [object] $ReleasesIndexData
    )

    $Locals = Get-Locals

    $Output = Get-Data -ReleasesIndexData $ReleasesIndexData

    $Output = $Output | Where-Object {
        $PSItem."Version" -eq $XVersion
    } | Select-Object -First 1

    if ($Locals -contains $Output."version") {
        exit 1
    }

    if ($Locals -contains $Output."version") {
        exit 1
    }

    Uninstall -Output $Output
}



$ValidTargets = @{
    "SDK"                = "sdk"
    "Runtime"            = "runtime"
    "NetCoreRuntime"     = "runtime"
    "DesktopCoreRuntime" = "windowsdesktop"
    "AspNetCoreRuntime"  = "aspnetcore-runtime"
}

$ValidTarget = $ValidTargets[$Target]

$PrintableTargets = @{
    "SDK"                = "sdk"
    "Runtime"            = "runtime"
    "NetCoreRuntime"     = "core-runtime"
    "DesktopCoreRuntime" = "desktop-core-runtime"
    "AspNetCoreRuntime"  = "aspnet-core-runtime"
}

$PrintableTarget = $PrintableTargets[$Target]



$ReleasesIndexUri = "${DATABASE_BASE_URI}/releases-index.json"

$ReleasesIndexData = Read-Database -Uri $ReleasesIndexUri

if ($Channel) {
    if ($Runtime) {
        Uninstall-Runtime -ReleasesIndexData $ReleasesIndexData
    } else {
        Uninstall-Channel -ReleasesIndexData $ReleasesIndexData
    }
}

if ($XVersion) {
    Uninstall-XVersion -ReleasesIndexData $ReleasesIndexData
}

exit 0
