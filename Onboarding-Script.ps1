# FUNKTIONER
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO","SUCCESS","WARNING","ERROR")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"


# Skriv till Loggfil
$LogPath = "C:\Logs\Onboarding\Onboarding_$(Get-Date -Format 'yyyy-MM-dd').log"
try {
    if (-not (Test-Path (Split-Path $Logpath))) {
        New-item -Itemtype Directory -Path (Split-Path $LogPath) -Force | Out-Null
    }
    Add-Content -Path $LogPath -Value $LogEntry -Encoding UTF8
}
catch {
    Write-Warning "Kunde inte skriva till loggfil!"
}

# Skriv till konsoll med färg
switch ($Level) {
    "INFO"    { Write-Host $LogEntry -ForegroundColor Cyan }
    "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
    "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
    "ERROR"   { Write-Host $LogEntry -ForegroundColor Red }
    }
}