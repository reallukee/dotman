#
# -----------
# DotMan Info
# Module
# -----------
#
# A Manager for .NET
#
# https://github.com/reallukee/dotman
#
# By Luca Pollicino (https://github.com/reallukee)
#
# info.ps1
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

    [switch] $Online,
    [ValidateSet(
        "System",
        "Local",
        "Custom"
    )]
    [string] $Path = "System",
    [string] $CustomPath,

    [switch] $Channels,
    [string] $Channel,
    [switch] $Runtimes,
    [string] $Runtime,
    [ValidateSet(
        "All",
        "Release",
        "RC",
        "Preview"
    )]
    [string] $Filter,
    [ValidateSet(
        "All",
        "Current",
        "Windows",
        "Linux",
        "MacOS"
    )]
    [string] $Platform = "Current",
    [switch] $Latest,

    [switch] $NoCache
)



#
# Requirements
#

$PowerShellVersion = [version]$PSVersionTable.PSVersion

if ($PowerShellVersion -lt [version]"5.1.0.0") {
    Write-Error -Message "Unsupported PowerShell version!"

    exit 1
}

if ($PowerShellVersion -lt [version]"7.0.0.0") {
    Write-Warning -Message "Unsupported PowerShell version!"
}



#
# General Options
#

$COMMAND_NAME = "info"

$ABOUT_FILE   = "${PSScriptRoot}/abouts/${COMMAND_NAME}.about"
$VERSION_FILE = "${PSScriptRoot}/versions/${COMMAND_NAME}.version"
$HELP_FILE    = "${PSScriptRoot}/helps/${COMMAND_NAME}.help"

function Read-File {
    param (
        [string] $File
    )

    if (-not (Test-Path -Path $File -PathType Leaf)) {
        exit 1
    }

    try {
        $Content = Get-Content -Path $File -Encoding utf8 -Raw

        $Placeholders = @{
            "A.B.C"               = Read-Version -Key "Display_Version"
            "@DISPLAY_VERSION"    = Read-Version -Key "Display_Version"
            "@VERSION"            = Read-Version -Key "Version"
            "@MIN_VERSION"        = Read-Version -Key "Min_Version"
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
        exit 1
    }
}

function Read-Version {
    param (
        [string] $Key
    )

    if (-not (Test-Path -Path $VERSION_FILE -PathType Leaf)) {
        exit 1
    }

    try {
        $Version = Get-Content -Path $VERSION_FILE -Encoding utf8 | Where-Object {
            $PSItem -match "^${Key}="
        } | Select-Object -First 1

        $Version = ($Version -split "=", 2)[1].Trim()
    }
    catch {
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

if ($Runtime -and -not $Channel) {
    exit 1
}

if ($Runtimes -and -not $Channel) {
    exit 1
}

if ($Channel -and $Channels) {
    exit 1
}

if ($Runtime -and $Runtimes) {
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
        [string] $Uri
    )

    try {
        if (-not $Uri) {
            throw "MEOW!"
        }

        $Response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
        $Content = $Response.Content
        $Data = $Content | ConvertFrom-Json

        if (-not $NoCache) {
            $Content | Set-Content -Path $LocalFile -Encoding utf8
        }
    }
    catch {
        exit 1
    }

    return $Data
}

function Read-Database {
    param (
        [string] $Uri
    )

    $CacheFolder = "${PSScriptRoot}/.cache"

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
            $Data = Receive-Database -Uri $Uri
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
            $Data = Receive-Database -Uri $Uri
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
            $DOTNET_PATH = "C:\Program Files\dotnet"
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

function Get-DotNet-Path {
    if (-not (Test-Path -Path $DOTNET_PATH -PathType Container)) {
        exit 1
    }

    $DotNetPaths = @{
        "SDK"                = "${DOTNET_PATH}/sdk"
        "Runtime"            = "${DOTNET_PATH}/shared/Microsoft.NETCore.App"
        "NetCoreRuntime"     = "${DOTNET_PATH}/shared/Microsoft.NETCore.App"
        "DesktopCoreRuntime" = "${DOTNET_PATH}/shared/Microsoft.WindowsDesktop.App"
        "AspNetCoreRuntime"  = "${DOTNET_PATH}/shared/Microsoft.AspNetCore.App"
    }

    $DotNetPath = $DotNetPaths[$Target]

    if (-not $DotNetPath) {
        exit 1
    }

    if (-not (Test-Path -Path $DotNetPath -PathType Container)) {
        exit 1
    }

    return $DotNetPath
}

function Get-Locals {
    $TargetPath = Get-DotNet-Path

    $Locals = Get-ChildItem -Path $TargetPath -Directory | Select-Object -ExpandProperty "Name"

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

    $Tag = Get-Tag -Tag $FixedRelease."version"

    if ($FixedRelease."runtime-version") {
        $RuntimeVersion = $FixedRelease."runtime-version"
    } else {
        $RuntimeVersion = $FixedRelease."version"
    }

    $Object = [PSCustomObject]@{
        "Type"             = $PrintableTarget

        "Channel Version"  = $ReleaseIndex."channel-version"
        "Product"          = $ReleaseIndex."product"

        "Support Phase"    = $Channel."support-phase"
        "EOL Date"         = $Channel."eol-date"
        "Release Type"     = $Channel."release-type"
        "Lifecycle Policy" = $Channel."lifecycle-policy"

        "Release Date"     = $Runtime."release-date"
        "Release Version"  = $Runtime."release-version"
        "Security"         = $Runtime."security"
        "Release Notes"    = $Runtime."release-notes"

        "Version"          = $FixedRelease."version"
        "Version Display"  = $FixedRelease."version-display"
        "Runtime Version"  = $RuntimeVersion
        "VS Version"       = $FixedRelease."vs-version"
        "VS Mac Display"   = $FixedRelease."vs-mac-version"
        "C# Version"       = $FixedRelease."csharp-version"
        "F# Version"       = $FixedRelease."fsharp-version"
        "VB .NET Version"  = $FixedRelease."vb-version"

        "Tag"              = $Tag
    }

    return $Object
}

function Test-Skip {
    param (
        [object] $Locals,
        [object] $Release,
        [bool]   $UseValidTarget
    )

    if ($UseValidTarget) {
        $FixedRelease = $Release."${ValidTarget}"
    } else {
        $FixedRelease = $Release
    }

    if (-not $Online) {
        $Local = $FixedRelease."version"

        if (-not ($Locals -contains $Local)) {
            return $true
        }
    }

    if ($Platform -eq "Current") {
        $RID = Get-Rid

        $Contains = $FixedRelease."files" | Where-Object {
            $PSItem."rid" -eq $RID
        }

        if (-not $Contains) {
            return $true
        }
    }

    return $false
}



function Receive-Info {
    param (
        [object] $ReleasesIndexData
    )

    if (-not $Online) {
        $Locals = Get-Locals
    }

    $Output = $ReleasesIndexData."releases-index" | ForEach-Object {
        $ReleasesUri = $PSItem."releases.json"

        $ReleasesData = Read-Database -Uri $ReleasesUri

        $ReleaseIndexData = $PSItem
        $ChannelData = $ReleasesData

        $ReleasesData."releases" | ForEach-Object {
            $RuntimeData = $PSItem
            $ReleaseData = $PSItem

            $Skip = Test-Skip `
                -Locals $Locals `
                -Release $ReleaseData `
                -UseValidTarget $true

            if ($Skip) {
                return
            }

            Get-Output-Object `
                -ReleaseIndex $ReleaseIndexData `
                -Channel $ChannelData `
                -Runtime $RuntimeData `
                -Release $ReleaseData `
                -UseValidTarget $true
        }
    }

    return $Output
}

function Receive-Info-Channel {
    param (
        [object] $ReleasesIndexData
    )

    if (-not $Online) {
        $Locals = Get-Locals
    }

    $ChannelData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database -Uri $ReleasesUri
        }
    }

    if (-not $ChannelData) {
        exit 1
    }

    $ReleaseIndexData = $ChannelData

    $Output = $ChannelData."releases" | ForEach-Object {
        $RuntimeData = $PSItem
        $ReleaseData = $PSItem

        $Skip = Test-Skip `
            -Locals $Locals `
            -Release $ReleaseData `
            -UseValidTarget $true

        if ($Skip) {
            return
        }

        Get-Output-Object `
            -ReleaseIndex $ReleaseIndexData `
            -Channel $ChannelData `
            -Runtime $RuntimeData `
            -Release $ReleaseData `
            -UseValidTarget $true
    }

    return $Output
}

function Receive-Info-Runtime {
    param (
        [object] $ReleasesIndexData
    )

    if (-not $Online) {
        $Locals = Get-Locals
    }

    $ChannelData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database -Uri $ReleasesUri
        }
    }

    if (-not $ChannelData) {
        exit 1
    }

    $ReleaseIndexData = $ChannelData

    $RuntimeData = $ChannelData."releases" | Where-Object {
        $PSItem."release-version" -eq $Runtime
    }

    if (-not $RuntimeData) {
        exit 1
    }

    $Fix = ""

    if ($Target -eq "sdk") {
        $Fix = "s"
    }

    $Output = $RuntimeData."${ValidTarget}${Fix}" | ForEach-Object {
        $ReleaseData = $PSItem

        $Skip = Test-Skip `
            -Locals $Locals `
            -Release $ReleaseData `
            -UseValidTarget $false

        if ($Skip) {
            return
        }

        Get-Output-Object `
            -ReleaseIndex $ReleaseIndexData `
            -Channel $ChannelData `
            -Runtime $RuntimeData `
            -Release $ReleaseData `
            -UseValidTarget $false
    }

    return $Output
}



function Receive-Info-Channels {
    param (
        [object] $ReleasesIndexData
    )

    if (-not $Online) {
        $Locals = Get-Locals

        $regex = [regex]"([0-9]+.[0-9]+).([0-9]+)"

        $Parsed = $Locals | ForEach-Object {
            if ($regex.IsMatch($PSItem)) {
                $match = $regex.Match($PSItem)

                [PSCustomObject]@{
                    "Full Version" = $PSItem
                    "Channel"      = $match.Groups[1].Value
                    "Patch"        = $match.Groups[2].Value
                }
            }
        } | Group-Object -Property "Channel" | ForEach-Object {
            $PSItem.Group | Sort-Object -Property "Patch" -Descending | Select-Object -First 1
        }
    }

    $Output = $ReleasesIndexData."releases-index" | ForEach-Object {
        $ReleasesUri = $PSItem."releases.json"

        $ReleasesData = Read-Database -Uri $ReleasesUri

        $ReleaseIndexData = $PSItem
        $ChannelData = $ReleasesData

        if ($Online) {
            [PSCustomObject]@{
                "Channel Version"     = $ReleaseIndexData."channel-version"
                "Product"             = $ReleaseIndexData."product"

                "Latest Release"      = $ChannelData."latest-release"
                "Latest Release Date" = $ChannelData."latest-release-date"
                "Latest Runtime"      = $ChannelData."latest-runtime"
                "Latest SDK"          = $ChannelData."latest-sdk"
                "Support Phase"       = $ChannelData."support-phase"
                "EOL Date"            = $ChannelData."eol-date"
                "Release Type"        = $ChannelData."release-type"
                "Lifecycle Policy"    = $ChannelData."lifecycle-policy"
            }
        } else {
            $ChannelData."releases" | ForEach-Object {
                if ($Parsed."Full Version" -contains $PSItem."${ValidTarget}"."version") {
                    $RuntimeData = $PSItem
                    $ReleaseData = $PSItem

                    Get-Output-Object `
                        -ReleaseIndex $ReleaseIndexData `
                        -Channel $ChannelData `
                        -Runtime $RuntimeData `
                        -Release $ReleaseData `
                        -UseValidTarget $true
                }
            }
        }
    }

    return $Output
}

function Receive-Info-Runtimes {
    param (
        [object] $ReleasesIndexData
    )

    if (-not $Online) {
        $Locals = Get-Locals

        $regex = [regex]"([0-9]+.[0-9]+).([0-9])+"

        $Parsed = $Locals | ForEach-Object {
            if ($regex.IsMatch($PSItem)) {
                $match = $regex.Match($PSItem)

                if ($match.Groups[1].Value -eq $Channel) {
                    [PSCustomObject]@{
                        "Full Version" = $PSItem
                        "Channel"      = $match.Groups[1].Value
                        "Patch"        = $match.Groups[2].Value
                    }
                }
            }
        }
    }

    $ChannelData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database -Uri $ReleasesUri
        }
    }

    if (-not $ChannelData) {
        exit 1
    }

    $ReleaseIndexData = $ChannelData

    $Output = $ChannelData."releases" | ForEach-Object {
        $RuntimeData = $PSItem

        if ($Online) {
            [PSCustomObject]@{
                "Channel Version"  = $ReleaseIndexData."channel-version"
                "Product"          = $ReleaseIndexData."product"

                "Support Phase"    = $ChannelData."support-phase"
                "EOL Date"         = $ChannelData."eol-date"
                "Release Type"     = $ChannelData."release-type"
                "Lifecycle Policy" = $ChannelData."lifecycle-policy"
                "Release Date"     = $RuntimeData."release-date"
                "Release Version"  = $RuntimeData."release-version"
                "Security"         = $RuntimeData."security"
                "Release Notes"    = $RuntimeData."release-notes"
            }
        } else {
            if ($Parsed."Full Version" -contains $RuntimeData."${ValidTarget}"."version") {
                $RuntimeData = $PSItem
                $ReleaseData = $PSItem

                Get-Output-Object `
                    -ReleaseIndex $ReleaseIndexData `
                    -Channel $ChannelData `
                    -Runtime $RuntimeData `
                    -Release $ReleaseData `
                    -UseValidTarget $true
            }
        }
    }

    return $Output
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

function Write-Output {
    if ($Filter) {
        $Filters = @{
            "Release" = "release"
            "RC"      = "rc"
            "Preview" = "preview"
        }

        if ($Filters.ContainsKey($Filter)) {
            $Property = $Filters[$Filter].ToLower()

            $Output = $Output | Where-Object {
                $PSItem."Tag".ToLower() -eq $Property
            }
        }
    }

    if ($Latest) {
        $Output = $Output | Select-Object -First 1
    }

    $Output
}

if ($Target) {
    if ($Channel) {
        if ($Runtime) {
            $Output = Receive-Info-Runtime -ReleasesIndexData $ReleasesIndexData
        } elseif ($Runtimes) {
            $Output = Receive-Info-Runtimes -ReleasesIndexData $ReleasesIndexData
        } else {
            $Output = Receive-Info-Channel -ReleasesIndexData $ReleasesIndexData
        }
    } elseif ($Channels) {
        $Output = Receive-Info-Channels -ReleasesIndexData $ReleasesIndexData
    } else {
        $Output = Receive-Info -ReleasesIndexData $ReleasesIndexData
    }
} else {
    if ($Online) {
        if ($Channels) {
            $Output = Receive-Info-Channels -ReleasesIndexData $ReleasesIndexData
        }

        if ($Channel -and $Runtimes) {
            $Output = Receive-Info-Runtimes -ReleasesIndexData $ReleasesIndexData
        }
    }
}

Write-Output

exit 0
