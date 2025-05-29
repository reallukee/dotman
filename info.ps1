#
# ------------------------
# DotMan                .
# A Manager for .NET   /|\
# v0.1.0               / \
# ------------------------
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

if (-not $Target) {
    exit 1
}

if ($Channel -and $Channels) {
    exit 1
}

if ($Channels -and $Runtime) {
    exit 1
}

function Read-Database {
    param (
        [string] $Uri
    )

    $LocalFile  = $Uri -replace [regex]::Escape($BaseUri), "cache"
    $RemoteFile = Invoke-WebRequest -Uri $Uri -Method Head -UseBasicParsing

    if (-not $NoCache) {
        $CachePath = Split-Path $LocalFile -Parent

        if (-not (Test-Path -Path $CachePath -PathType Container)) {
            New-Item -Path $CachePath -ItemType Directory | Out-Null
        }
    }

    if (Test-Path -Path $LocalFile -PathType Leaf) {
        $LocalDate  = (Get-Item $LocalFile).LastWriteTime
        $RemoteDate = [datetime]::Parse($RemoteFile.Headers["Last-Modified"])

        if ($RemoteDate -gt $LocalDate) {
            $Response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
            $Content  = $Response.Content
            $Data     = $Content | ConvertFrom-Json

            if (-not $NoCache) {
                $Content | Set-Content -Path $LocalFile -Encoding UTF8
            }
        } else {
            $Response = "HELLO! MEOW!!!"
            $Content  = Get-Content -Path $LocalFile -Raw -Encoding UTF8
            $Data     = $Content | ConvertFrom-Json
        }
    } else {
        $Response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
        $Content  = $Response.Content
        $Data     = $Content | ConvertFrom-Json

        if (-not $NoCache) {
            $Content | Set-Content -Path $LocalFile -Encoding UTF8
        }
    }

    return $Data
}

function Get-Version-Type {
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

    $VersionType = Get-Version-Type $Item."${ValidTarget}"."version"

    if ($Item."runtime-version") {
        $RuntimeVersion = $Item."${ValidTarget}"."runtime-version"
    } else {
        $RuntimeVersion = $Item."${ValidTarget}"."version"
    }

    $Object = [PSCustomObject]@{
        "Type"             = $PrintableTarget

        "Channel Version"  = $ReleasesData."channel-version"
        "Support Phase"    = $ReleasesData."support-phase"
        "Release Type"     = $ReleasesData."release-type"
        "EOL Date"         = $ReleasesData."eol-date"
        "Lifecycle Policy" = $ReleasesData."lifecycle-policy"
        "Release Date"     = $PSItem."release-date"
        "Release Version"  = $PSItem."release-version"
        "Security"         = $PSItem."security"
        "Version"          = $PSItem."${ValidTarget}"."version"
        "Version Display"  = $PSItem."${ValidTarget}"."version-display"
        "Runtime Version"  = $RuntimeVersion
        "VS Version"       = $PSItem."${ValidTarget}"."vs-version"
        "VS Mac Display"   = $PSItem."${ValidTarget}"."vs-mac-version"
        "C# Version"       = $PSItem."${ValidTarget}"."csharp-version"
        "F# Version"       = $PSItem."${ValidTarget}"."fsharp-version"
        "VB .NET Version"  = $PSItem."${ValidTarget}"."vb-version"

        "Version Type"     = $VersionType
    }

    return $Object
}

$BaseUri = "https://builds.dotnet.microsoft.com/dotnet/release-metadata"

function Get-Online {
    param (
        [object] $ReleasesIndexData,
        [string] $PrintableTarget,
        [string] $ValidTarget
    )

    $Output = $ReleasesIndexData."releases-index" | ForEach-Object {
        $Parent = $PSItem

        $ReleasesUri = $PSItem."releases.json"

        $ReleasesData = Read-Database $ReleasesUri

        $ReleasesData."releases" | ForEach-Object {
            $Item = $PSItem

            Get-Output-Object $Parent $Item $PrintableTarget $ValidTarget
        }
    }

    return $Output
}

function Get-Online-Channels {
    param (
        [object] $ReleasesIndexData,
        [string] $PrintableTarget,
        [string] $ValidTarget
    )

    $Output = $ReleasesIndexData."releases-index" | ForEach-Object {
        $Parent = $PSItem

        $ReleasesUri = $PSItem."releases.json"

        $ReleasesData = Read-Database $ReleasesUri

        $ReleasesData."releases" | ForEach-Object {
            $Item = $PSItem

            Get-Output-Object $Parent $Item $PrintableTarget $ValidTarget
        } | Select-Object -First 1
    }

    return $Output
}

function Get-Online-Channel {
    param (
        [object] $ReleasesIndexData,
        [string] $PrintableTarget,
        [string] $ValidTarget
    )

    $ReleasesData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database $ReleasesUri
        }
    }

    $Parent = $ReleasesData

    $Output = $ReleasesData."releases" | ForEach-Object {
        $Item = $PSItem

        Get-Output-Object $Parent $Item $PrintableTarget $ValidTarget
    }

    return $Output
}

function Get-Online-Runtime {
    param (
        [object] $ReleasesIndexData,
        [string] $Target,
        [string] $PrintableTarget,
        [string] $ValidTarget
    )

    $ReleasesData = $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $Channel) {
            $ReleasesUri = $PSItem."releases.json"

            return Read-Database $ReleasesUri
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

        if ($Item."runtime-version") {
            $RuntimeVersion = $Item."runtime-version"
        } else {
            $RuntimeVersion = $Item."version"
        }

        $VersionType = Get-Version-Type $PSItem."version"

        [PSCustomObject]@{
            "Type"             = $PrintableTarget

            "Channel Version"  = $Parent."channel-version"
            "Support Phase"    = $Parent."support-phase"
            "Release Type"     = $Parent."release-type"
            "EOL Date"         = $Parent."eol-date"
            "Lifecycle Policy" = $Parent."lifecycle-policy"
            "Release Date"     = $ReleasesData."release-date"
            "Release Version"  = $ReleasesData."release-version"
            "Security"         = $ReleasesData."security"
            "Version"          = $Item."version"
            "Version Display"  = $Item."version-display"
            "Runtime Version"  = $RuntimeVersion
            "VS Version"       = $Item."vs-version"
            "VS Mac Display"   = $Item."vs-mac-version"
            "C# Version"       = $Item."csharp-version"
            "F# Version"       = $Item."fsharp-version"
            "VB .NET Version"  = $Item."vb-version"

            "Version Type"     = $VersionType
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

function Help {
    param (
        [string] $HelpFile
    )

    if (-not (Test-Path $HelpFile)) {
        exit 1
    }

    Get-Content -Path $HelpFile | Where-Object {
        $PSItem -notmatch "^\s*#"
    } | ForEach-Object {
        Write-Host $PSItem
    }
}

if ($Version) {
    Write-Host "0.1.0"

    exit 0
}

if ($Help) {
    Help "info.hlp"

    exit 0
}

$ReleasesIndexUri = "${BaseUri}/releases-index.json"

$ReleasesIndexData = Read-Database $ReleasesIndexUri

if ($Online) {
    if ($Channels) {
        $Output = Get-Online-Channels `
            -ReleasesIndexData $ReleasesIndexData `
            -PrintableTarget $PrintableTarget `
            -ValidTarget $ValidTarget
    } elseif ($Channel) {
        if ($Runtime) {
            $Output = Get-Online-Runtime `
                -ReleasesIndexData $ReleasesIndexData `
                -Target $Target `
                -PrintableTarget $PrintableTarget `
                -ValidTarget $ValidTarget
        } else {
            $Output = Get-Online-Channel `
                -ReleasesIndexData $ReleasesIndexData `
                -PrintableTarget $PrintableTarget `
                -ValidTarget $ValidTarget
        }
    } else {
        $Output = Get-Online `
            -ReleasesIndexData $ReleasesIndexData `
            -PrintableTarget $PrintableTarget `
            -ValidTarget $ValidTarget
    }
}

if ($Filter) {
    $Filters = @{
        "Release" = "release"
        "RC"      = "rc"
        "Preview" = "preview"
    }

    if ($Filters.ContainsKey($Filter)) {
        $Property = $Filters[$Filter].ToLower()

        $Output = $Output | Where-Object {
            $PSItem."Version Type".ToLower() -eq $Property
        }
    }
}

if ($Latest) {
    $Output = $Output | Select-Object -First 1
}

$Output

exit 0
