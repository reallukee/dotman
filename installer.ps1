#
# ------
# DotMan
# ------
#
# A Manager for .NET
#
# https://github.com/reallukee/dotman
#
# installer.ps1
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

$CONFIG = Read-Json -Target "installer.json"

Write-Output-Info "Installing DotMan..."

if (Test-Path -Path $PATH -PathType Container) {
    if (Test-Path -Path "${PATH}/VERSION" -PathType Leaf) {
        try {
            $InstalledVersion = Get-Content -Path "${PATH}/VERSION" -Encoding utf8 -Raw

            if ([version]$InstalledVersion -eq [version]$THISVERSION -and -not $Force) {
                Write-Output-Error "DotMan is already installed!"

                exit 1
            }
        }
        catch {
            exit 1
        }
    }
} else {
    New-Item -Path $PATH -ItemType Directory -Force | Out-Null
}

Write-Output-Info "Creating files..."

$CONFIG."files" | ForEach-Object {
    if (Test-Path -Path $PSItem -PathType Leaf) {
        Write-Output-Background -Message "Creating `"${PSItem}`"..." -IndentLevel 1

        try {
            Copy-Item -Path $PSItem -Destination "${PATH}/${PSItem}"
        }
        catch {
            exit 1
        }

        if ($CONFIG."executables" -contains $PSItem) {
            & chmod +x "$HOME/.dotman/${PSItem}"
        }

        Write-Output-Success -Message "`"${PSItem}`" created!" -IndentLevel 2
    }
}

Write-Output-Success -Message "Files succefully created!"

Write-Output-Info -Message "Adding to PATH..."

$Configs = @(
    "~/.bashrc",
    "~/.zshrc"
)

$DotManPath = "export PATH=`"`$PATH:`$HOME/.dotman`""

$Configs | ForEach-Object {
    if (Test-Path -Path $PSItem -PathType Leaf) {
        Copy-Item -Path $PSItem -Destination "${PSItem}.dotman.back"
    } else {
        New-Item -Path $PSItem -ItemType File -Force | Out-Null
    }

    $Content = Get-Content $PSItem -Raw

    Write-Output-Background -Message "Adding to `"${PSItem}`" PATH..." -IndentLevel 1

    if ($Content -notmatch [regex]::Escape($DotManPath)) {
        Add-Content -Path $PSItem -Value $DotManPath
    } else {
        Write-Output-Success -Message "Already added!" -IndentLevel 2
    }
}

Write-Output-Info -Message "Succefully added to PATH..."

Write-Output-Success -Message "DotMan succefully installed!"

exit 0
