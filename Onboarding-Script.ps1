# Onboarding-Script.ps1
# Stories #5 (Loggning) + #6 (Felhantering) + #11 (Mappar)


# HJÄLPFUNKTION
# Write-Log: Hanterar logging till fil och till konsollen med färg
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
    
    try {
        Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
    }
    catch {
        Write-Warning "Kunde inte skriva till loggfil!"
    }

    # Skriv till konsollen med färg beroende på loggnivå 
    switch ($Level) {
        "INFO"    { Write-Host $LogEntry -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
        "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogEntry -ForegroundColor Red }
    }
}

# HJÄLPFUNKTION: New-UserFolderStructure #11
# Skapar hemkatalog + undermappar för en ny användare
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
        # Skapa hemkatalog om den inte finns
        if (-not (Test-Path $UserHome)) {
            New-Item -ItemType Directory -Path $UserHome -Force | Out-Null
            Write-Log "Skapade hemkatalog: $UserHome" "SUCCESS"
        }
        else {
            Write-Log "Hemkatalog finns redan: $UserHome" "WARNING"
        }

        # Skapar undermappar
        $SubFolders = @(
            "Dokument",
            "Skrivbord",
            "Nedladdningar",
            "Projekt",
            "Mallar"
            )

        foreach ($Folder in $SubFolders) {
            $FullPath = Join-Path $UserHome $Folder

            if (-not (Test-Path $FullPath)) {
                New-Item -ItemType Directory -Path $FullPath -Force | Out-Null
                Write-Log "Skapade undermapp: $FullPath" "SUCCESS"
            }
        }

        return $UserHome
    }
    catch {
        Write-Log "Fel vid skapande av mappar för $Username : $($_.Exception.Message)" "ERROR"
        throw
    }

}

# HJÄLPFUNKTION: Invoke-Onboardingstep #6
# Kör ett steg med felhantering och loggar resultatet 
# Gör det enkelt att lägga till nya steg utan att hela scriptet kraschar
function Invoke-OnboardingStep {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$StepName,

        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock
    )

    try {
        Write-Log "Startar: $StepName" "INFO"

        & $ScriptBlock

        Write-Log "Slutfört: $StepName" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "FEL i steg '$StepName': $($_.Exception.Message)" "ERROR"
        return $false
    }
}
