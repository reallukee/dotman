#
# -----------
# DotMan List
# Module
# -----------
#
# A modular, open-source and multiplatform manager for .NET
#
# https://github.com/reallukee/dotman
#
# By Luca Pollicino (https://github.com/reallukee)
#
# list.ps1
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

$COMMAND_NAME = "list"

$ABOUT_FILE   = "${PSScriptRoot}/abouts/${COMMAND_NAME}.about"
$VERSION_FILE = "${PSScriptRoot}/versions/${COMMAND_NAME}.version"
$HELP_FILE    = "${PSScriptRoot}/helps/${COMMAND_NAME}.help"

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
    Write-Output-Error -Message "Can't determine .NET path!"

    exit 1
}

if (-not (Test-Path -Path $DOTNET_PATH -PathType Container)) {
    # Write-Output-Error -Message "Can't find .NET path!"

    exit 0
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
        Write-Output-Error -Message "Can't determine .NET target path!"

        exit 1
    }

    if (-not (Test-Path -Path $DotNetPath -PathType Container)) {
        # Write-Output-Error -Message "Can't find .NET target path!"

        exit 0
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



function Get-Data {
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

        $MultipleReleases = $Target -eq "sdk"

        $ChannelData."releases" | ForEach-Object {
            $RuntimeData = $PSItem
            $ReleaseData = $PSItem

            if ($MultipleReleases) {
                $RuntimeData."${ValidTarget}s" | ForEach-Object {
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
            } else {
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
    }

    return $Output
}



function Receive-List {
    param (
        [object] $ReleasesIndexData
    )

    $Output = Get-Data -ReleasesIndexData $ReleasesIndexData

    return $Output
}

function Receive-List-Channel {
    param (
        [object] $ReleasesIndexData
    )

    $Output = Get-Data -ReleasesIndexData $ReleasesIndexData

    $Output = $Output | Where-Object {
        $PSItem."Channel" -eq $Channel
    }

    if (-not $Output) {
        Write-Output-Fail -Message "Channel `"${Channel}`" not found or not available for current platform!"
        Write-Output-Fail -Message "Please try:"

        $OnlineFlag = $Online ? "-online " : ""

        Write-Output-Fail -Message " * `"dotman list ${Target} ${OnlineFlag}-channels`""
        Write-Output-Fail -Message " * `"dotman list ${Target} ${OnlineFlag}-channel ${Channel} -Platform All`""
    }

    return $Output
}

function Receive-List-Runtime {
    param (
        [object] $ReleasesIndexData
    )

    $Output = Get-Data -ReleasesIndexData $ReleasesIndexData

    $Output = $Output | Where-Object {
        $PSItem."Runtime" -eq $Runtime
    }

    if (-not $Output) {
        Write-Output-Fail -Message "Runtime `"${Runtime}`" not found or not available for current platform!"
        Write-Output-Fail -Message "Please try:"

        $OnlineFlag = $Online ? "-online " : ""

        Write-Output-Fail -Message " * `"dotman list ${Target} ${OnlineFlag}-channel ${Channel} -runtimes`""
        Write-Output-Fail -Message " * `"dotman list ${Target} ${OnlineFlag}-channel ${Channel} -runtime ${Runtime} -Platform All`""
    }

    return $Output
}



function Receive-List-Channels {
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

        if ($Online) {
            [PSCustomObject]@{
                "Channel" = $ReleaseIndexData."channel-version"
            }
        } else {
            $ChannelData."releases" | ForEach-Object {
                if ($Locals -contains $PSItem."${ValidTarget}"."version") {
                    [PSCustomObject]@{
                        "Channel" = $ReleaseIndexData."channel-version"
                    }
                }
            } | Group-Object -Property "Channel" | ForEach-Object {
                $PSItem.Group[0]
            }
        }
    }

    return $Output
}

function Receive-List-Runtimes {
    param (
        [object] $ReleasesIndexData
    )

    if (-not $Online) {
        $Locals = Get-Locals
    }

    $ReleaseIndexData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database -Uri $ReleasesUri
        }
    }

    if (-not $ReleaseIndexData) {
        exit 1
    }

    $ChannelData = $ReleaseIndexData

    $Output = $ChannelData."releases" | ForEach-Object {
        $RuntimeData = $PSItem

        if ($Online) {
            [PSCustomObject]@{
                "Channel" = $ReleaseIndexData."channel-version"

                "Runtime" = $RuntimeData."release-version"
            }
        } else {
            if ($Locals -contains $PSItem."${ValidTarget}"."version") {
                $RuntimeData = $PSItem

                [PSCustomObject]@{
                    "Channel" = $ReleaseIndexData."channel-version"

                    "Runtime" = $RuntimeData."release-version"
                }
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

    $Output | Format-Table -Property * -AutoSize
}

if ($Target) {
    if ($Channel) {
        if ($Runtime) {
            $Output = Receive-List-Runtime -ReleasesIndexData $ReleasesIndexData
        } elseif ($Runtimes) {
            $Output = Receive-List-Runtimes -ReleasesIndexData $ReleasesIndexData
        } else {
            $Output = Receive-List-Channel -ReleasesIndexData $ReleasesIndexData
        }
    } elseif ($Channels) {
        $Output = Receive-List-Channels -ReleasesIndexData $ReleasesIndexData
    } else {
        $Output = Receive-List -ReleasesIndexData $ReleasesIndexData
    }
} else {
    if ($Online) {
        if ($Channels) {
            $Output = Receive-List-Channels -ReleasesIndexData $ReleasesIndexData
        }

        if ($Channel -and $Runtimes) {
            $Output = Receive-List-Runtimes -ReleasesIndexData $ReleasesIndexData
        }
    }
}

Write-Output

exit 0
