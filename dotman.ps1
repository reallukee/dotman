#
# ------
# DotMan
# Module
# ------
#
# A Manager for .NET
#
# https://github.com/reallukee/dotman
#
# By Luca Pollicino (https://github.com/reallukee)
#
# dotman.ps1
#
# Licensed under the MIT license!
#

param (
    [Parameter(Position = 0)]
    [ValidateSet(
        "Installer",
        "Uninstaller",
        "List",
        "Info",
        "Install",
        "Uninstall",
        "DotMan"
    )]
    [string]   $Command,

    [switch]   $About,
    [switch]   $Version,
    [switch]   $Help,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Args
)



#
# Requirements
#

$PowerShellVersion = [version]$PSVersionTable.PSVersion

if ($PowerShellVersion -lt [version]"5.1.0.0") {
    Write-Error -Message "Unsupported PowerShell version!"

    exit 1
}

if ($PowerShellVersion -lt [version]"7.0.0.0") {
    Write-Warning -Message "Unsupported PowerShell version!"
}



#
# General Options
#

$COMMAND_NAME = "dotman"

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

if (-not $Command) {
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
}



$Module = "${PSScriptRoot}/${Command}.ps1"

$ModuleArgs = @()

if ($About) {
    $ModuleArgs += "-About"
}

if ($Version) {
    $ModuleArgs += "-Version"
}

if ($Help) {
    $ModuleArgs += "-Help"
}

$ModuleArgs += $Args

if (-not (Test-Path -Path $Module -PathType Leaf)) {
    exit 1
}

& pwsh $Module @ModuleArgs

exit 0
