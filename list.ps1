param (
    [Parameter(Position = 0)]
    [ValidateSet(
        "SDK",
        "Runtime"
    )]
    [string] $Command,

    [switch] $Help,

    [switch] $Online,

    [string] $ChannelVersion,

    [string] $RuntimeVersion,

    [ValidateSet(
        "All",
        "Releases",
        "ReleaseCandidates",
        "Previews"
    )]
    [string] $Filter,

    [switch] $Latest
)

$ReleasesIndexUri = "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/releases-index.json"
$ReleasesIndexContent = (Invoke-WebRequest -Uri $ReleasesIndexUri -UseBasicParsing).Content
$ReleasesIndexData = $ReleasesIndexContent | ConvertFrom-Json

function Online-ChannelVersion {
    $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $ChannelVersion) {
            $ReleasesUri = $PSItem."releases.json"
            $ReleasesContent = (Invoke-WebRequest -Uri $ReleasesUri -UseBasicParsing).Content
            $ReleasesData = $ReleasesContent | ConvertFrom-Json
        }
    }

    $Output = $ReleasesData."releases" | ForEach-Object {
        [PSCustomObject]@{
            "Version"            = $PSItem.sdk."version"
            "Runtime Version"    = $PSItem.sdk."runtime-version"
            "Version Display"    = $PSItem.sdk."version-display"

            "IsRelease"          = $PSItem.sdk."version" -notmatch "rc|preview"
            "IsReleaseCandidate" = $PSItem.sdk."version" -match    "rc"
            "IsPreview"          = $PSItem.sdk."version" -match    "preview"
        }
    }

    return $Output
}

function Online-RuntimeVersion {
    $ReleasesIndexData."releases-index" | ForEach-Object {
        if ($PSItem."channel-version" -eq $ChannelVersion) {
            $ReleasesUri = $PSItem."releases.json"
            $ReleasesContent = (Invoke-WebRequest -Uri $ReleasesUri -UseBasicParsing).Content
            $ReleasesData = $ReleasesContent | ConvertFrom-Json
        }
    }

    $ReleasesData."releases" | ForEach-Object {
        if ($PSItem."release-version" -eq $RuntimeVersion) {
            $Output = $PSItem."sdks" | ForEach-Object {
                [PSCustomObject]@{
                    "Version"            = $PSItem."version"
                    "Version Display"    = $PSItem."version-display"
                    "Runtime Version"    = $PSItem."runtime-version"

                    "IsRelease"          = $PSItem."version" -notmatch "rc|preview"
                    "IsReleaseCandidate" = $PSItem."version" -match    "rc"
                    "IsPreview"          = $PSItem."version" -match    "preview"
                }
            }
        }
    }

    return $Output
}

function Online {
    $Output = $ReleasesIndexData."releases-index" | ForEach-Object {
        $ReleasesUri = $PSItem."releases.json"
        $ReleasesContent = (Invoke-WebRequest -Uri $ReleasesUri -UseBasicParsing).Content
        $ReleasesData = $ReleasesContent | ConvertFrom-Json

        $ReleasesData."releases" | ForEach-Object {
            [PSCustomObject]@{
                "Version"            = $PSItem.sdk."version"
                "Version Display"    = $PSItem.sdk."version-display"
                "Runtime Version"    = $PSItem.sdk."runtime-version"

                "IsRelease"          = $PSItem.sdk."version" -notmatch "rc|preview"
                "IsReleaseCandidate" = $PSItem.sdk."version" -match    "rc"
                "IsPreview"          = $PSItem.sdk."version" -match    "preview"
            }
        }
    }

    return $Output
}

if (-not $Command) {
    if (-not (Test-Path "list.hlp")) {
        exit 1
    }

    Get-Content -Path "list.hlp" | Where-Object {
        $PSItem -notmatch "^\s*#"
    } | ForEach-Object {
        Write-Host $PSItem
    }

    exit 0
}

if ($Online) {
    if ($ChannelVersion) {
        if ($RuntimeVersion) {
            $Output = Online-RuntimeVersion
        } else {
            $Output = Online-ChannelVersion
        }
    } else {
        $Output = Online
    }

    if ($Filter) {
        $Filters = @{
            "Releases"          = "IsRelease"
            "ReleaseCandidates" = "IsReleaseCandidate"
            "Previews"          = "IsPreview"
        }

        if ($Filters.ContainsKey($Filter)) {
            $Property = $Filters[$Filter]

            $Output = $Output | Where-Object {
                $PSItem.$Property
            }
        }
    }

    if ($Latest) {
        $Output = $Output | Select-Object -First 1
    }

    $Output | Format-Table -Property "Version", "Version Display", "Runtime Version" -AutoSize
}

exit 0
