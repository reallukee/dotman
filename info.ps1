#
# ------
# DotMan
# ------
#
# A Manager for .NET
#
# https://github.com/reallukee/dotman
#
# info.ps1
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

    [switch] $Help,
    [switch] $Version,

    [switch] $Online,
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



function Help {
    param (
        [string] $HelpFile
    )

    if (-not (Test-Path $HelpFile)) {
        exit 1
    }

    try {
        Get-Content -Path $HelpFile | Where-Object {
            $PSItem -notmatch "^\s*#"
        } | ForEach-Object {
            $Version = Version

            $PSItem -replace "A.B.C", $Version
        }
    }
    catch {
        exit 1
    }
}

function Version {
    if (-not (Test-Path -Path "${PSScriptRoot}/VERSION" -PathType Leaf)) {
        exit 1
    }

    try {
        $Version = Get-Content -Path "${PSScriptRoot}/VERSION" -Raw
    }
    catch {
        exit 1
    }

    return $Version
}

if ($Version) {
    Version

    exit 0
}

if ($Help -or -not $PSBoundParameters.Count) {
    Help -HelpFile "${PSScriptRoot}/info.hlp"

    exit 0
}



if ($IsWindows) {
    exit 1
}

if ($Runtime -and -not $Channel) {
    exit 1
}

if ($Runtimes -and -not $Channel) {
    exit 1
}

if ($Target -and $Channels) {
    exit 1
}

if ($Target -and $Runtimes) {
    exit 1
}

if ($Channel -and $Channels) {
    exit 1
}

if ($Runtime -and $Runtimes) {
    exit 1
}

if (-not $Target -and -not $Online) {
    if ($Channels -or $Runtimes) {
        exit 1
    }
}



$DATABASE_BASE_URI = "https://builds.dotnet.microsoft.com/dotnet/release-metadata"

function Receive-Database {
    param (
        [string] $Uri,
        [bool]   $NoCache
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
        [string] $Uri,
        [bool]   $NoCache
    )

    $LocalFile = $Uri -replace [regex]::Escape($DATABASE_BASE_URI), "${PSScriptRoot}/.cache"
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
            $Data = Receive-Database -Uri $Uri -NoCache $NoCache
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
        $Data = Receive-Database -Uri $Uri -NoCache $NoCache
    }

    return $Data
}



if ($IsLinux) {
    $DOTNET_PATH = "/usr/share/dotnet"
}

if ($IsMacOS) {
    $DOTNET_PATH = "/usr/local/share/dotnet"
}

function Get-DotNet-Path {
    param (
        [string] $Target
    )

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
    param (
        [string] $Target
    )

    $TargetPath = Get-DotNet-Path -Target $Target

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
        [string] $PrintableTarget,
        [string] $ValidTarget,
        [bool]   $UseValidTarget
    )

    if ($UseValidTarget) {
        $FixedItem = $Item."${ValidTarget}"
    } else {
        $FixedItem = $Item
    }

    $Tag = Get-Tag -Tag $FixedItem."version"

    if ($FixedItem."runtime-version") {
        $RuntimeVersion = $FixedItem."runtime-version"
    } else {
        $RuntimeVersion = $FixedItem."version"
    }

    $Object = [PSCustomObject]@{
        "Type"             = $PrintableTarget

        "Channel Version"  = $Parent."channel-version"
        "Support Phase"    = $Parent."support-phase"
        "Release Type"     = $Parent."release-type"
        "EOL Date"         = $Parent."eol-date"
        "Lifecycle Policy" = $Parent."lifecycle-policy"
        "Release Date"     = $Item."release-date"
        "Release Version"  = $Item."release-version"
        "Security"         = $Item."security"
        "Version"          = $FixedItem."version"
        "Version Display"  = $FixedItem."version-display"
        "Runtime Version"  = $RuntimeVersion
        "VS Version"       = $FixedItem."vs-version"
        "VS Mac Display"   = $FixedItem."vs-mac-version"
        "C# Version"       = $FixedItem."csharp-version"
        "F# Version"       = $FixedItem."fsharp-version"
        "VB .NET Version"  = $FixedItem."vb-version"

        "Tag"              = $Tag
    }

    return $Object
}

function Test-Skip {
    param (
        [object] $Locals,
        [bool]   $Online,
        [object] $Item,
        [string] $ValidTarget,
        [string] $Platform,
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



function Receive-Info {
    param (
        [object] $ReleasesIndexData,
        [string] $Target,
        [string] $PrintableTarget,
        [string] $ValidTarget,
        [bool]   $NoCache
    )

    if (-not $Online) {
        $Locals = Get-Locals -Target $Target
    }

    $Output = $ReleasesIndexData."releases-index" | ForEach-Object {
        $Parent = $PSItem

        $ReleasesUri = $PSItem."releases.json"

        $ReleasesData = Read-Database -Uri $ReleasesUri -NoCache $NoCache

        $ReleasesData."releases" | ForEach-Object {
            $Skip = Test-Skip `
                -Locals $Locals `
                -Online $Online `
                -Item $PSItem `
                -ValidTarget $ValidTarget `
                -Platform $Platform `
                -UseValidTarget $true

            if ($Skip) {
                return
            }

            Get-Output-Object `
                -Parent $Parent `
                -Item $PSItem `
                -PrintableTarget $PrintableTarget `
                -ValidTarget $ValidTarget `
                -UseValidTarget $true
        }
    }

    return $Output
}

function Receive-Info-Channel {
    param (
        [object] $ReleasesIndexData,
        [string] $Target,
        [string] $PrintableTarget,
        [string] $ValidTarget,
        [bool]   $NoCache
    )

    if (-not $Online) {
        $Locals = Get-Locals -Target $Target
    }

    $ReleasesData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database -Uri $ReleasesUri -NoCache $NoCache
        }
    }

    if (-not $ReleasesData) {
        exit 1
    }

    $Parent = $ReleasesData

    $Output = $ReleasesData."releases" | ForEach-Object {
        $Skip = Test-Skip `
            -Locals $Locals `
            -Online $Online `
            -Item $PSItem `
            -ValidTarget $ValidTarget `
            -Platform $Platform `
            -UseValidTarget $true

        if ($Skip) {
            return
        }

        Get-Output-Object `
            -Parent $Parent `
            -Item $PSItem `
            -PrintableTarget $PrintableTarget `
            -ValidTarget $ValidTarget `
            -UseValidTarget $true
    }

    return $Output
}

function Receive-Info-Runtime {
    param (
        [object] $ReleasesIndexData,
        [string] $Target,
        [string] $PrintableTarget,
        [string] $ValidTarget,
        [bool]   $NoCache
    )

    if (-not $Online) {
        $Locals = Get-Locals -Target $Target
    }

    $ReleasesData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database -Uri $ReleasesUri -NoCache $NoCache
        }
    }

    if (-not $ReleasesData) {
        exit 1
    }

    $Parent = $ReleasesData

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
            -Online $Online `
            -Item $PSItem `
            -ValidTarget $ValidTarget `
            -Platform $Platform `
            -UseValidTarget $false

        if ($Skip) {
            return
        }

        Get-Output-Object `
            -Parent $Parent `
            -Item $PSItem `
            -PrintableTarget $PrintableTarget `
            -ValidTarget $ValidTarget `
            -UseValidTarget $false
    }

    return $Output
}



function Receive-Info-Channels {
    param (
        [object] $ReleasesIndexData,
        [string] $PrintableTarget,
        [string] $ValidTarget,
        [bool]   $NoCache
    )

    $Output = $ReleasesIndexData."releases-index" | ForEach-Object {
        $ReleasesUri = $PSItem."releases.json"

        $ReleasesData = Read-Database -Uri $ReleasesUri -NoCache $NoCache

        [PSCustomObject]@{
            "Channel" = $ReleasesData."channel-version"
        }
    }

    return $Output
}

function Receive-Info-Runtimes {
    param (
        [object] $ReleasesIndexData,
        [string] $PrintableTarget,
        [string] $ValidTarget,
        [bool]   $NoCache
    )

    $ReleasesData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database -Uri $ReleasesUri -NoCache $NoCache
        }
    }

    if (-not $ReleasesData) {
        exit 1
    }

    $Output = $ReleasesData."releases" | ForEach-Object {
        [PSCustomObject]@{
            "Runtime" = $PSItem."release-version"
        }
    }

    return $Output
}



function Get-ValidTarget {
    param (
        [string] $Target
    )

    $ValidTargets = @{
        "SDK"                = "sdk"
        "Runtime"            = "runtime"
        "NetCoreRuntime"     = "runtime"
        "DesktopCoreRuntime" = "windowsdesktop"
        "AspNetCoreRuntime"  = "aspnetcore-runtime"
    }

    $ValidTarget = $ValidTargets[$Target]

    return $ValidTarget
}

function Get-PrintableTarget {
    param (
        [string] $Target
    )

    $PrintableTargets = @{
        "SDK"                = "sdk"
        "Runtime"            = "runtime"
        "NetCoreRuntime"     = "core-runtime"
        "DesktopCoreRuntime" = "desktop-core-runtime"
        "AspNetCoreRuntime"  = "aspnet-core-runtime"
    }

    $PrintableTarget = $PrintableTargets[$Target]

    return $PrintableTarget
}

$PrintableTarget = Get-PrintableTarget $Target
$ValidTarget = Get-ValidTarget $Target



$ReleasesIndexUri = "${DATABASE_BASE_URI}/releases-index.json"

$ReleasesIndexData = Read-Database -Uri $ReleasesIndexUri -NoCache $NoCache

function Write-Output {
    param (
        [object] $Output,
        [string] $Filter
    )

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

if ($online -and -not $Target) {
    if ($Channels) {
        $Output = Receive-Info-Channels `
            -ReleasesIndexData $ReleasesIndexData `
            -PrintableTarget $PrintableTarget `
            -ValidTarget $ValidTarget `
            -NoCache $NoCache
    }

    if ($Channel -and $Runtimes) {
        $Output = Receive-Info-Runtimes `
            -ReleasesIndexData $ReleasesIndexData `
            -PrintableTarget $PrintableTarget `
            -ValidTarget $ValidTarget `
            -NoCache $NoCache
    }
} else {
    if ($Channel) {
        if ($Runtime) {
            $Output = Receive-Info-Runtime `
                -ReleasesIndexData $ReleasesIndexData `
                -Target $Target `
                -PrintableTarget $PrintableTarget `
                -ValidTarget $ValidTarget `
                -NoCache $NoCache
        } else {
            $Output = Receive-Info-Channel `
                -ReleasesIndexData $ReleasesIndexData `
                -Target $Target `
                -PrintableTarget $PrintableTarget `
                -ValidTarget $ValidTarget `
                -NoCache $NoCache
        }
    } else {
        $Output = Receive-Info `
            -ReleasesIndexData $ReleasesIndexData `
            -Target $Target `
            -PrintableTarget $PrintableTarget `
            -ValidTarget $ValidTarget `
            -NoCache $NoCache
    }
}

Write-Output -Output $Output -Filter $Filter

exit 0
