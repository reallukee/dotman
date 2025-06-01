#
# ------
# DotMan
# ------
#
# A Manager for .NET
#
# https://github.com/reallukee/dotman
#
# list.ps1
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

if ([version]$PSVersionTable.PSVersion -lt [version]"7.0.0.0") {
    Write-Error -Message "Unsupported PowerShell version!"

    exit 1
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
        [object] $Parent,
        [object] $Item,
        [bool]   $UseValidTarget
    )

    if ($UseValidTarget) {
        $FixedItem = $Item."${ValidTarget}"
    } else {
        $FixedItem = $Item
    }

    $Tag = Get-Tag -Version $FixedItem."version"

    if ($FixedItem."runtime-version") {
        $RuntimeVersion = $FixedItem."runtime-version"
    } else {
        $RuntimeVersion = $FixedItem."version"
    }

    $Object = [PSCustomObject]@{
        "Type"    = $PrintableTarget

        "Channel" = $Parent."channel-version"
        "Version" = $FixedItem."version"
        "Display" = $FixedItem."version-display"
        "Runtime" = $RuntimeVersion

        "Tag"     = $Tag
    }

    return $Object
}

function Test-Skip {
    param (
        [object] $Locals,
        [object] $Item,
        [bool]   $UseValidTarget
    )

    if ($UseValidTarget) {
        $FixedItem = $Item."${ValidTarget}"
    } else {
        $FixedItem = $Item
    }

    if (-not $Online) {
        $Local = $FixedItem."version"

        if (-not ($Locals -contains $Local)) {
            return $true
        }
    }

    if ($Platform -eq "Current") {
        $RID = Get-Rid

        $Contains = $FixedItem."files" | Where-Object {
            $PSItem."rid" -eq $RID
        }

        if (-not $Contains) {
            return $true
        }
    }

    return $false
}



function Receive-List {
    param (
        [object] $ReleasesIndexData
    )

    if (-not $Online) {
        $Locals = Get-Locals
    }

    $Output = $ReleasesIndexData."releases-index" | ForEach-Object {
        $Parent = $PSItem

        $ReleasesUri = $PSItem."releases.json"

        $ReleasesData = Read-Database -Uri $ReleasesUri

        $ReleasesData."releases" | ForEach-Object {
            $Skip = Test-Skip `
                -Locals $Locals `
                -Item $PSItem `
                -UseValidTarget $true

            if ($Skip) {
                return
            }

            Get-Output-Object `
                -Parent $Parent `
                -Item $PSItem `
                -UseValidTarget $true
        }
    }

    return $Output
}

function Receive-List-Channel {
    param (
        [object] $ReleasesIndexData
    )

    if (-not $Online) {
        $Locals = Get-Locals
    }

    $ReleasesData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database -Uri $ReleasesUri
        }
    }

    if (-not $ReleasesData) {
        exit 1
    }

    $Output = $ReleasesData."releases" | ForEach-Object {
        $Skip = Test-Skip `
            -Locals $Locals `
            -Item $PSItem `
            -UseValidTarget $true

        if ($Skip) {
            return
        }

        Get-Output-Object `
            -Parent $ReleasesData `
            -Item $PSItem `
            -UseValidTarget $true
    }

    return $Output
}

function Receive-List-Runtime {
    param (
        [object] $ReleasesIndexData
    )

    if (-not $Online) {
        $Locals = Get-Locals
    }

    $ReleasesData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database -Uri $ReleasesUri
        }
    }

    if (-not $ReleasesData) {
        exit 1
    }

    $ReleasesData = $ReleasesData."releases" | Where-Object {
        $PSItem."release-version" -eq $Runtime
    }

    if (-not $ReleasesData) {
        exit 1
    }

    $Fix = ""

    if ($Target -eq "sdk") {
        $Fix = "s"
    }

    $Output = $ReleasesData."${ValidTarget}${Fix}" | ForEach-Object {
        $Skip = Test-Skip `
            -Locals $Locals `
            -Item $PSItem `
            -UseValidTarget $false

        if ($Skip) {
            return
        }

        Get-Output-Object `
            -Parent $ReleasesData `
            -Item $PSItem `
            -UseValidTarget $false
    }

    return $Output
}



function Receive-List-Channels {
    param (
        [object] $ReleasesIndexData
    )

    $Output = $ReleasesIndexData."releases-index" | ForEach-Object {
        $ReleasesUri = $PSItem."releases.json"

        $ReleasesData = Read-Database -Uri $ReleasesUri

        if ($Online) {
            [PSCustomObject]@{
                "Channel" = $ReleasesData."channel-version"
            }
        } else {
            $Locals = Get-Locals

            $Parent = $PSItem

            $ReleasesData."releases" | ForEach-Object {
                if ($Locals -contains $PSItem."${ValidTarget}"."version") {
                    [PSCustomObject]@{
                        "Type"    = $PrintableTarget

                        "Channel" = $Parent."channel-version"
                    }
                }
            }
        }
    }

    return $Output
}

function Receive-List-Runtimes {
    param (
        [object] $ReleasesIndexData
    )

    $ReleasesData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database -Uri $ReleasesUri
        }
    }

    if (-not $ReleasesData) {
        exit 1
    }

    $Output = $ReleasesData."releases" | ForEach-Object {
        if ($Online) {
            [PSCustomObject]@{
                "Runtime" = $PSItem."release-version"
            }
        } else {
            $Locals = Get-Locals

            if ($Locals -contains $PSItem."${ValidTarget}"."version") {
                [PSCustomObject]@{
                    "Type"    = $PrintableTarget

                    "Runtime" = $PSItem."release-version"
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
