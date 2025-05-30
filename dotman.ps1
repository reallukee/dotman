#
# ------
# DotMan
# ------
#
# A Manager for .NET
#
# https://github.com/reallukee/dotman
#
# dotman.ps1
#

param (
    [Parameter(Position = 0)]
    [ValidateSet(
        "List",
        "Info"
    )]
    [string]   $Command,

    [switch]   $Help,
    [switch]   $Version,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Args
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
    if ($Command) {
        $Args += "-Version"
    } else {
        Version

        exit 0
    }
}

if ($Help -or -not $Command) {
    if ($Command) {
        $Args += "-Help"
    } else {
        Help -HelpFile "${PSScriptRoot}/dotman.hlp"

        exit 0
    }
}




if (-not (Test-Path -Path "${PSScriptRoot}/${Command}.ps1" -PathType Leaf)) {
    exit 1
}

& pwsh "${PSScriptRoot}/${Command}.ps1" @Args

exit 0
