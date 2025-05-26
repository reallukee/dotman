param (
    [Parameter(Position = 0)]
    [ValidateSet(
        "List"
    )]
    [string]   $Command,

    [switch]   $Help,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Args
)

if (-not $Command) {
    if (-not (Test-Path "dotman.hlp")) {
        exit 1
    }

    Get-Content -Path "dotman.hlp" | Where-Object {
        $PSItem -notmatch "^\s*#"
    } | ForEach-Object {
        Write-Host $PSItem
    }

    exit 0
}

& pwsh "$Command.ps1" @Args

exit 0
