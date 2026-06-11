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


    # Skapa loggfilens sökväg
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
        Write-Host "Ett fel uppstod i steg: $StepName - Se loggfil för detaljer" -ForegroundColor Red
        return $false
    }
}


# HUVUDLOOP - Kör Onboarding för varje ny användare

Write-Log "===Startar full Onboarding-process===" "INFO"


# TESTDATA (Ska senare ersättas med riktig JSON-hämtning från Google Form)

$TestUsers = @(
    [PSCustomObject]@{
        RowID = "1"
        FirstName = "Luke"
        LastName = "Skywalker"
        Username = "luke.skywalker"
        Department = "Ekonomi"
    
    }
)

# Kör hela onboarding-processen för alla användare
Invoke-OnboardingStep "Onboarding av alla användare" {

    foreach ($User in $TestUsers) {

        Invoke-OnboardingStep "Onboarding av $($User.Username)" {

            #Skapa Mappar och undermappar för varje användaren
            $HomePath = New-UserFolderStructure -Username $User.Username -BasePath "C:\TestOnboarding"

            Write-Log "Onboarding slutförd för $($User.FirstName) $($User.LastName)" "SUCCESS"
        }
    }

}

Write-Log "===Full Onboarding-process slutförd===" "INFO"
