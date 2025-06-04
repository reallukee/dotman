#
# ----------------
# DotMan Installer
# Module
# ----------------
#
# A modular, open-source and multiplatform manager for .NET
#
# https://github.com/reallukee/dotman
#
# By Luca Pollicino (https://github.com/reallukee)
#
# installer.ps1
#
# Licensed under the MIT license!
#

param (
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

    [switch] $Force
)



#
# Requirements
#

if ($IsWindows) {
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

$COMMAND_NAME = "installer"

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

if ($Help) {
    Read-File -File $HELP_FILE

    exit 0
}



switch ($Path) {
    "System" {
        if ($IsMacOS) {
            $DOTMAN_PATH = "/usr/local/share/dotman"
        }

        if ($IsLinux) {
            $DOTMAN_PATH = "/usr/share/dotman"
        }
    }

    "Local" {
        $DOTMAN_PATH = "${HOME}/.dotman"
    }

    "Custom" {
        if ($CustomPath) {
            $DOTMAN_PATH = $CustomPath
        } else {
            exit 1
        }
    }
}

if (-not (Test-Path -Path $DOTMAN_PATH -PathType Container)) {
    try {
        New-Item -Path $DOTMAN_PATH -ItemType Directory -Force | Out-Null
    }
    catch {
        exit 1
    }
}

try {
    Copy-Item -Path "${PSScriptRoot}/*" -Destination $DOTMAN_PATH -Recurse -Force
}
catch {
    exit 1
}

exit 0
