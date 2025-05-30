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

    [switch] $Help,
    [switch] $Version,

    [switch] $Online,
    [switch] $Channels,
    [string] $Channel,
    [string] $Runtime,
    [ValidateSet(
        "All",
        "Release",
        "RC",
        "Preview"
    )]
    [string] $Filter,
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

if ($Help -or -not $Target) {
    Help -HelpFile "${PSScriptRoot}/list.hlp"

    exit 0
}



if (-not $Target) {
    exit 1
}

if ($Channel -and $Channels) {
    exit 1
}

if ($Channels -and $Runtime) {
    exit 1
}



$DATABASEBASEURI = "https://builds.dotnet.microsoft.com/dotnet/release-metadata"

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

        if (-not $NoCache) {
            $Content | Set-Content -Path $LocalFile -Encoding utf8
        }
    }
    catch {
        exit 1
    }
}

function Read-Database {
    param (
        [string] $Uri,
        [bool]   $NoCache
    )

    $LocalFile = $Uri -replace [regex]::Escape($DATABASEBASEURI), "${PSScriptRoot}/.cache"
    $RemoteFile = Invoke-WebRequest -Uri $Uri -Method Head -UseBasicParsing

    if (-not $NoCache) {
        $CachePath = Split-Path $LocalFile -Parent

        if (-not (Test-Path -Path $CachePath -PathType Container)) {
            New-Item -Path $CachePath -ItemType Directory -Force | Out-Null
        }
    }

    if (Test-Path -Path $LocalFile -PathType Leaf) {
        $LocalDate = (Get-Item $LocalFile).LastWriteTime
        $RemoteDate = [datetime]::Parse($RemoteFile.Headers["Last-Modified"])

        if ($RemoteDate -gt $LocalDate) {
            Receive-Database -Uri $Uri -NoCache $NoCache
        }
    } else {
        Receive-Database -Uri $Uri -NoCache $NoCache
    }

    try {
        $Content = Get-Content -Path $LocalFile -Encoding utf8 -Raw
        $Data = $Content | ConvertFrom-Json
    }
    catch {
        exit 1
    }

    return $Data
}



$DOTNETROOT = "/usr/local/share/dotnet"

if (-not (Test-Path -Path $DOTNETROOT -PathType Container)) {
    exit 1
}

function Get-DotNet-Path {
    param (
        [string] $Target
    )

    $DotNetPaths = @{
        "SDK"                = "${DotNetRoot}/sdk"
        "Runtime"            = "${DotNetRoot}/shared/Microsoft.NETCore.App"
        "NetCoreRuntime"     = "${DotNetRoot}/shared/Microsoft.NETCore.App"
        "DesktopCoreRuntime" = "${DotNetRoot}/shared/Microsoft.WindowsDesktop.App"
        "AspNetCoreRuntime"  = "${DotNetRoot}/shared/Microsoft.AspNetCore.App"
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
        [string] $ValidTarget
    )

    $Tag = Get-Tag -Version $Item."${ValidTarget}"."version"

    if ($Item."${ValidTarget}"."runtime-version") {
        $RuntimeVersion = $Item."${ValidTarget}"."runtime-version"
    } else {
        $RuntimeVersion = $Item."${ValidTarget}"."version"
    }

    $Object = [PSCustomObject]@{
        "Type"    = $PrintableTarget

        "Channel" = $Parent."channel-version"
        "Version" = $Item."${ValidTarget}"."version"
        "Display" = $Item."${ValidTarget}"."version-display"
        "Runtime" = $RuntimeVersion

        "Tag"     = $Tag
    }

    return $Object
}



function Receive-List {
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
            $Item = $PSItem

            if (-not $Online) {
                $Local = $Item."${ValidTarget}"."version"

                if (-not ($Locals -contains $Local)) {
                    return
                }
            }

            Get-Output-Object `
                -Parent $Parent `
                -Item $Item `
                -PrintableTarget $PrintableTarget `
                -ValidTarget $ValidTarget
        }
    }

    return $Output
}

function Receive-List-Channels {
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
            $Item = $PSItem

            if (-not $Online) {
                $Local = $Item."${ValidTarget}"."version"

                if (-not ($Locals -contains $Local)) {
                    return
                }
            }

            Get-Output-Object `
                -Parent $Parent `
                -Item $Item `
                -PrintableTarget $PrintableTarget `
                -ValidTarget $ValidTarget
        } | Select-Object -First 1
    }

    return $Output
}

function Receive-List-Channel {
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

    $Parent = $ReleasesData

    $Output = $ReleasesData."releases" | ForEach-Object {
        $Item = $PSItem

        if (-not $Online) {
            $Local = $Item."${ValidTarget}"."version"

            if (-not ($Locals -contains $Local)) {
                return
            }
        }

        Get-Output-Object `
            -Parent $Parent `
            -Item $Item `
            -PrintableTarget $PrintableTarget `
            -ValidTarget $ValidTarget
    }

    return $Output
}

function Receive-List-Runtime {
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

    $Parent = $ReleasesData

    $ReleasesData = $ReleasesData."releases" | Where-Object {
        $PSItem."release-version" -eq $Runtime
    }

    $Fix = ""

    if ($Target -eq "sdk") {
        $Fix = "s"
    }

    $Output = $ReleasesData."${ValidTarget}${Fix}" | ForEach-Object {
        $Item = $PSItem

        if (-not $Online) {
            $Local = $Item."version"

            if (-not ($Locals -contains $Local)) {
                return
            }
        }

        if ($Item."runtime-version") {
            $RuntimeVersion = $Item."runtime-version"
        } else {
            $RuntimeVersion = $Item."version"
        }

        $Tag = Get-Tag -Version $Item."${ValidTarget}"."version"

        [PSCustomObject]@{
            "Type"    = $PrintableTarget

            "Channel" = $Parent."channel-version"
            "Version" = $Item."version"
            "Display" = $Item."version-display"
            "Runtime" = $RuntimeVersion

            "Tag "    = $Tag
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

$PrintableTarget = Get-PrintableTarget -Target $Target
$ValidTarget = Get-ValidTarget -Target $Target



$ReleasesIndexUri = "${DATABASEBASEURI}/releases-index.json"

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

    $Output | Format-Table -Property * -AutoSize
}

if ($Channels) {
    $Output = Receive-List-Channels `
        -ReleasesIndexData $ReleasesIndexData `
        -Target $Target `
        -PrintableTarget $PrintableTarget `
        -ValidTarget $ValidTarget `
        -NoCache $NoCache
} elseif ($Channel) {
    if ($Runtime) {
        $Output = Receive-List-Runtime `
            -ReleasesIndexData $ReleasesIndexData `
            -Target $Target `
            -PrintableTarget $PrintableTarget `
            -ValidTarget $ValidTarget `
            -NoCache $NoCache
    } else {
        $Output = Receive-List-Channel `
            -ReleasesIndexData $ReleasesIndexData `
            -Target $Target `
            -PrintableTarget $PrintableTarget `
            -ValidTarget $ValidTarget `
            -NoCache $NoCache
    }
} else {
    $Output = Receive-List `
        -ReleasesIndexData $ReleasesIndexData `
        -Target $Target `
        -PrintableTarget $PrintableTarget `
        -ValidTarget $ValidTarget `
        -NoCache $NoCache
}

Write-Output -Output $Output -Filter $Filter

exit 0
