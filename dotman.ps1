#
# ------------------------
# DotMan                .
# A Manager for .NET   /|\
# v0.1.0               / \
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
        Write-Host $PSItem
    }
}

if ($Version) {
    Write-Host "0.1.0"

    exit 0
}

if ($Help) {
    Help "dotman.hlp"

    exit 0
}

& pwsh "$Command.ps1" @Args

exit 0
