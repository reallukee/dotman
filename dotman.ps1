#
# ------------------------
# DotMan                .
# A Manager for .NET   /|\
# v0.1.1               / \
# ------------------------
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

    Get-Content -Path $HelpFile | Where-Object {
        $PSItem -notmatch "^\s*#"
    } | ForEach-Object {
        $PSItem
    }
}

if ($Help) {
    if ($Command) {
        $Args += "-Help"
    } else {
        Help -HelpFile "${PSScriptRoot}/dotman.hlp"

        exit 0
    }
}

if ($Version) {
    if ($Command) {
        $Args += "-Version"
    } else {
        Write-Host "0.1.1"

        exit 0
    }
}



if (-not (Test-Path -Path "${PSScriptRoot}/${Command}.ps1" -PathType Leaf)) {
    exit 1
}

& pwsh "${PSScriptRoot}/${Command}.ps1" @Args

exit 0
