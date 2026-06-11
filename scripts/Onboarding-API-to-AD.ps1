# ==============================
# Onboarding-Automaten
# Formulär/API -> JSON -> AD -> OU -> Grupp -> Manager
# API-token hämtas från miljövariabel
# ==============================

Import-Module ActiveDirectory

# ==============================
# Inställningar
# ==============================

$ApiToken = [Environment]::GetEnvironmentVariable("ONBOARDING_API_TOKEN", "Machine")

if ([string]::IsNullOrWhiteSpace($ApiToken)) {
    Write-Host "FEL: Miljövariabeln ONBOARDING_API_TOKEN saknas." -ForegroundColor Red
    Write-Host "Skapa den med:" -ForegroundColor Yellow
    Write-Host '[Environment]::SetEnvironmentVariable("ONBOARDING_API_TOKEN", "DIN_TOKEN_HÄR", "Machine")' -ForegroundColor Yellow
    exit
}

$Uri = "https://script.google.com/macros/s/AKfycbwFnx_-ZwAeEszfJ9Z72MDfkRddqQsNiVbt6VAlIPftcpvf9zFkYYy8UzYkFV-BPwU/exec?token=$ApiToken"

$DataFolder = "C:\Onboarding\Data"
$LogFolder  = "C:\Onboarding\Logs"

$DataFile = "$DataFolder\employees.json"
$LogFile  = "$LogFolder\onboarding.log"

$Domain = "itsec2026.local"

$CheferOU  = "OU=Chefer,OU=ITSEC2026,DC=itsec2026,DC=local"
$EkonomiOU = "OU=Ekonomi,OU=ITSEC2026,DC=itsec2026,DC=local"
$SaljOU    = "OU=Sälj,OU=ITSEC2026,DC=itsec2026,DC=local"

$CheferGroup  = "GG_Chefer"
$EkonomiGroup = "GG_Ekonomi_Users"
$SaljGroup    = "GG_Salj_Users"

$Password = ConvertTo-SecureString "Itsec2026!!" -AsPlainText -Force

$ManagerFirstName = "Anna"
$ManagerLastName  = "Andersson"
$ManagerUsername  = "anna.andersson"
$ManagerUPN       = "$ManagerUsername@$Domain"

# ==============================
# Skapa mappar om de saknas
# ==============================

if (-not (Test-Path $DataFolder)) {
    New-Item -ItemType Directory -Path $DataFolder -Force | Out-Null
}

if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

"[$(Get-Date)] Startar onboarding-script" | Out-File $LogFile -Append -Encoding UTF8