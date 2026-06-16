# Onboarding-Script.ps1
# Stories #5 (Loggning) + #11 (Mappar)


# HJÄLPFUNKTION
# Write-Log: Hanterar logging till fil + konsoll
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"


    # Skriv till loggfil
    $LogPath = "C:\Logs\Onboarding\Onboarding_$(Get-Date -Format 'yyyy-MM-dd').log"
    try {
        if (-not (Test-Path (Split-Path $LogPath))) {
            New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null
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

#HJÄLPFUNKTION
# New-UserFolderStructure: Skapar hemkatalog + undermappar
function New-UserFolderStructure {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )
    
    $UserHome = Join-Path $BasePath $Username

    try {
        # Skapa hemkatalog
        if (-not (Test-Path $UserHome)) {
            New-Item -ItemType Directory -Path $UserHome -Force | Out-Null
            Write-Log "Skapade hemkatalog: $UserHome" "SUCCESS"
        }
        else {
            Write-Log "Hemkatalog finns redan: $UserHome" "WARNING"
        }

        # Skapa vanliga undermappar
        $SubFolders = @("Dokument", "Skrivbord", "Nedladdningar", "Projekt", "Mallar")

        foreach ($folder in $SubFolders) {
            $fullPath = Join-Path $UserHome $folder

            if (-not (Test-Path $fullPath)) {
                New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
                Write-Log "Skapade undermapp: $fullPath" "SUCCESS"
            }
        }

        return $UserHome
    }
    catch {
        Write-Log "Fel vid skapande av mappar för $Username : $($_.Exception.Message)" "ERROR"
        throw
    }

}