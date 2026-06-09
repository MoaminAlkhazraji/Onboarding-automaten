# Skriv till Loggfil
$Logpath = "C:\Logs\Onboarding\Onboarding_$(Get-Date -Format 'yyyy-MM-dd').log"
try {
    if (-not (Test-Path (Split-Path $Logpath))) {
        New-item -Itemtype Directory -Path (Split-Path $Logpath) -Force | Out-Null
    }
    Add-Content -Path $LogPath -Value $LogEntry -Encoding UTF8
}
catch {
    Write-Warning "Kunde inte skriva till loggfil!"
}