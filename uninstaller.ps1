#
# ------
# DotMan
# ------
#
# A Manager for .NET
#
# https://github.com/reallukee/dotman
#
# uninstaller.ps1
#

param (
    [switch] $Help,
    [switch] $Version,

    [switch] $Force
)

function Write-Output-VTS {
    param (
        [int]    $Color,
        [string] $Message,
        [int]    $IndentLevel
    )

    $Indent = " " * $IndentLevel * 2

    Write-Output "${Indent}`e[${Color}m${Message}`e[0m"
}

function Write-Output-Info  {
    param (
        [string] $Message,
        [int]    $IndentLevel
    )

    Write-Output-VTS -Color 0 -Message $Message -IndentLevel $IndentLevel
}

function Write-Output-Background  {
    param (
        [string] $Message,
        [int]    $IndentLevel
    )

    Write-Output-VTS -Color 30 -Message $Message -IndentLevel $IndentLevel
}

function Write-Output-Success {
    param (
        [string] $Message,
        [int]    $IndentLevel
    )

    Write-Output-VTS -Color 32 -Message $Message -IndentLevel $IndentLevel
}

function Write-Output-Warning {
    param (
        [string] $Message,
        [int]    $IndentLevel
    )

    Write-Output-VTS -Color 33 -Message $Message -IndentLevel $IndentLevel
}

function Write-Output-Error {
    param (
        [string] $Message,
        [int]    $IndentLevel
    )

    Write-Output-VTS -Color 31 -Message $Message -IndentLevel $IndentLevel
}

if (-not (Test-Path -Path "${PSScriptRoot}/VERSION" -PathType Leaf)) {
    exit 1
}

$THISVERSION = Get-Content -Path "${PSScriptRoot}/VERSION" -Encoding utf8 -Raw
$PATH = "~/.dotman"

if (-not $IsMacOS) {
    exit 1
}

if ($PSVersionTable.PSEdition -ne "Core") {
    exit 1
}

function Read-Json {
    param (
        [string] $Target
    )

    try {
        $Content = Get-Content -Path $Target -Encoding utf8 -Raw
        $Data = $Content | ConvertFrom-Json
    }
    catch {
        exit 1
    }

    return $Data
}

$CONFIG = Read-Json -Target "uninstaller.json"

Write-Output-Info "Uninstalling DotMan..."

if (Test-Path -Path $PATH -PathType Container) {
    if (Test-Path -Path "${PATH}/VERSION" -PathType Leaf) {
        try {
            $InstalledVersion = Get-Content -Path "${PATH}/VERSION" -Encoding utf8 -Raw

            if ([version]$InstalledVersion -lt [version]$THISVERSION -and -not $Force) {
                Write-Output-Error "DotMan is already uninstalled!"

                exit 1
            }
        }
        catch {
            exit 1
        }
    }
} else {
    Write-Output-Success -Message "DotMan succefully uninstalled!"

    exit 0
}

Write-Output-Info "Deleting files..."

$CONFIG."files" | ForEach-Object {
    if (Test-Path -Path $PSItem -PathType Leaf) {
        Write-Output-Background -Message "Deleting `"${PSItem}`"..." -IndentLevel 1

        try {
            Remove-Item -Path "${PATH}/${PSItem}" -Force | Out-Null
        }
        catch {
            exit 1
        }

        Write-Output-Success -Message "`"${PSItem}`" deleted!" -IndentLevel 2
    }
}

Remove-Item -Path $PATH -Force | Out-Null

Write-Output-Success -Message "Files succefully deleted!"

Write-Output-Info -Message "Removing from PATH..."

$Configs = @(
    "~/.bashrc",
    "~/.zshrc"
)

$DotManPath = "export PATH=`"`$PATH:`$HOME/.dotman`""

$Configs | ForEach-Object {
    if (Test-Path -Path $PSItem -PathType Leaf) {
        $Content = Get-Content $PSItem -Raw

        Write-Output-Background -Message "Removing to `"${PSItem}`" PATH..." -IndentLevel 1

        if ($Content -match [regex]::Escape($DotManPath)) {
            $Content = $Content -replace ".*$([regex]::Escape($DotManPath)).*[\r\n]*", ""

            Set-Content -Path $PSItem -Value $Content
        } else {
            Write-Output-Success -Message "Already removed!" -IndentLevel 2
        }
    }
}

Write-Output-Info -Message "Succefully removed from PATH..."

Write-Output-Success -Message "DotMan succefully uninstalled!"

exit 0
