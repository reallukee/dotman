#
# --------------
# DotMan Cleanup
# Module
# --------------
#
# A modular, open-source and multiplatform manager for .NET
#
# https://github.com/reallukee/dotman
#
# By Luca Pollicino (https://github.com/reallukee)
#
# cleanup.ps1
#
# Licensed under the MIT license!
#

param (
    [switch] $About,
    [switch] $Version,
    [switch] $Help,

    [string] $Channel
)



#
# Output
#

function Write-Output-Error {
    param (
        [string] $Message
    )

    Write-Host -Message "-------------" -ForegroundColor Red
    Write-Host -Message "YOOOOO! [>:(]" -ForegroundColor Red
    Write-Host -Message "DOTMAN   /|\ " -ForegroundColor Red
    Write-Host -Message "ERROR    / \ " -ForegroundColor Red
    Write-Host -Message "-------------" -ForegroundColor Red

    Write-Host -Message ""

    Write-Host -Message "[ERROR] ${Message}" -ForegroundColor Red
}

function Write-Output-Fail {
    param (
        [string] $Message
    )

    Write-Host -Message "[FAIL] ${Message}" -ForegroundColor Red
}



#
# General Options
#

$COMMAND_NAME = "cleanup"

$ABOUT_FILE   = "${PSScriptRoot}/../abouts/${COMMAND_NAME}.about"
$VERSION_FILE = "${PSScriptRoot}/../versions/${COMMAND_NAME}.version"
$HELP_FILE    = "${PSScriptRoot}/../helps/${COMMAND_NAME}.help"

function Read-File {
    param (
        [string] $File
    )

    if (-not (Test-Path -Path $File -PathType Leaf)) {
        Write-Output-Error -Message "Can't find `"${File}`"!"

        exit 1
    }

    try {
        $Content = Get-Content -Path $File -Encoding utf8 -Raw

        $Placeholders = @{
            "A.B.C"            = Read-Version -Key "Display_Version"
            "@DISPLAY_VERSION" = Read-Version -Key "Display_Version"
            "@VERSION"         = Read-Version -Key "Version"
            "@MIN_VERSION"     = Read-Version -Key "Min_Version"
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
        Write-Output-Error -Message "Can't read `"${File}`"!"

        exit 1
    }
}

function Read-Version {
    param (
        [string] $Key
    )

    if (-not (Test-Path -Path $VERSION_FILE -PathType Leaf)) {
        Write-Output-Error -Message "Can't find `"${VERSION_FILE}`"!"

        exit 1
    }

    try {
        $Version = Get-Content -Path $VERSION_FILE -Encoding utf8 | Where-Object {
            $PSItem -match "^${Key}="
        } | Select-Object -First 1

        $Version = ($Version -split "=", 2)[1].Trim()
    }
    catch {
        Write-Output-Error -Message "Can't read `"${VERSION_FILE}`"!"

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



#
# Database
#

$DATABASE_BASE_URI = "https://builds.dotnet.microsoft.com/dotnet/release-metadata"

function Receive-Database {
    param (
        [string] $Uri,
        [string] $LocalFile
    )

    if (-not $Uri) {
        Write-Output-Error -Message "Can't find `"${LocalFile}`"!"

        exit 1
    }

    try {
        $Response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
        $Content = $Response.Content
        $Data = $Content | ConvertFrom-Json

        if (-not $NoCache) {
            $Content | Set-Content -Path $LocalFile -Encoding utf8
        }
    }
    catch {
        Write-Output-Error -Message "Can't read `"${LocalFile}`"!"

        exit 1
    }

    return $Data
}

function Read-Database {
    param (
        [string] $Uri
    )

    $CacheFolder = "${PSScriptRoot}/../.cache"

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
            $Data = Receive-Database -Uri $Uri -LocalFile $LocalFile
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
        $Data = Receive-Database -Uri $Uri -LocalFile $LocalFile
    }

    return $Data
}



function Get-Cleanup {
    param (
        [object] $ReleasesIndexData
    )

    if (Test-Path -Path ".cache" -PathType Container) {
        try {
            Remove-Item -Path ".cache" -Recurse -Force | Out-Null
        }
        catch {
            exit 1
        }
    }
}

function Get-Cleanup-Channel {
    param (
        [object] $ReleasesIndexData
    )

    if (Test-Path -Path ".cache/${Channel}" -PathType Container) {
        try {
            Remove-Item -Path ".cache/${Channel}" -Recurse -Force | Out-Null
        }
        catch {
            exit 1
        }
    }
}



$ReleasesIndexUri = "${DATABASE_BASE_URI}/releases-index.json"

$ReleasesIndexData = Read-Database -Uri $ReleasesIndexUri

if ($Channel) {
    Get-Cleanup-Channel -ReleasesIndexData $ReleasesIndexData
} else {
    Get-Cleanup -ReleasesIndexData $ReleasesIndexData
}

exit 0
