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

    [switch] $NoCache
)



#
# Requirements
#

if (-not $IsMacOS) {
    Write-Error -Message "Unsupported platform!"

    exit 1
}

if ([version]$PSVersionTable.PSVersion -lt [version]"7.0.0.0") {
    Write-Error -Message "Unsupported PowerShell version!"

    exit 1
}



#
# General Options
#

$COMMAND_NAME = "uninstall"

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



if ($Path -eq "Local") {
    if ([System.Environment]::UserName -ne "root") {
        Write-Error -Message "root is required!"

        exit 1
    }
}



#
# Exclusions
#

if (-not $Channel) {
    exit 1
}

if (-not $Channel -and $Runtime) {
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

if ($IsMacOS) {
    switch ($Path) {
        "System" {
            $DOTNET_PATH = "/usr/local/share/dotnet"
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



function Uninstall-Channel {
    param (
        [object] $ReleasesIndexData
    )

    $Locals = Get-Locals

    $ReleasesData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database -Uri $ReleasesUri
        }
    }

    if (-not $ReleasesData) {
        exit 1
    }

    $Output = ($ReleasesData."releases" | Select-Object -First 1)."${ValidTarget}"

    if (-not ($Locals -contains $Output."version")) {
        exit 0
    }

    $Version = $Output."version"

    $TargetPath = Get-DotNet-Path

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

function Uninstall-Runtime {
    param (
        [object] $ReleasesIndexData
    )

    $Locals = Get-Locals

    $ReleasesData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database -Uri $ReleasesUri
        }
    }

    if (-not $ReleasesData) {
        exit 1
    }

    $Output = ($ReleasesData."releases" | Where-Object {
        $PSItem."release-version" -eq $Runtime
    } | Select-Object -First 1)."${ValidTarget}"

    if (-not ($Locals -contains $Output."version")) {
        exit 0
    }

    $Version = $Output."version"

    $TargetPath = Get-DotNet-Path

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



$ValidTargets = @{
    "SDK"                = "sdk"
    "Runtime"            = "runtime"
    "NetCoreRuntime"     = "runtime"
    "DesktopCoreRuntime" = "windowsdesktop"
    "AspNetCoreRuntime"  = "aspnetcore-runtime"
}

$ValidTarget = $ValidTargets[$Target]



$ReleasesIndexUri = "${DATABASE_BASE_URI}/releases-index.json"

$ReleasesIndexData = Read-Database -Uri $ReleasesIndexUri

if ($Channel) {
    if ($Runtime) {
        Uninstall-Runtime -ReleasesIndexData $ReleasesIndexData
    } else {
        Uninstall-Channel -ReleasesIndexData $ReleasesIndexData
    }
}

exit 0
