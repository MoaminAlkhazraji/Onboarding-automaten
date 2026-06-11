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

# ==============================
# Säkerställ att grupper finns
# ==============================

$GroupsToCheck = @(
    @{ Name = $CheferGroup;  Path = $CheferOU },
    @{ Name = $EkonomiGroup; Path = $EkonomiOU },
    @{ Name = $SaljGroup;    Path = $SaljOU }
)

foreach ($Group in $GroupsToCheck) {
    try {
        $ExistingGroup = Get-ADGroup -Filter "Name -eq '$($Group.Name)'" -ErrorAction Stop

        if (-not $ExistingGroup) {
            New-ADGroup `
                -Name $Group.Name `
                -GroupScope Global `
                -GroupCategory Security `
                -Path $Group.Path

            "[$(Get-Date)] Skapade gruppen $($Group.Name)" | Out-File $LogFile -Append -Encoding UTF8
        }
        else {
            "[$(Get-Date)] Gruppen finns redan: $($Group.Name)" | Out-File $LogFile -Append -Encoding UTF8
        }
    }
    catch {
        "[$(Get-Date)] FEL: Kunde inte kontrollera/skapa gruppen $($Group.Name). $($_.Exception.Message)" | Out-File $LogFile -Append -Encoding UTF8
        Write-Host "Kunde inte kontrollera/skapa gruppen $($Group.Name)" -ForegroundColor Red
        exit
    }
}


# ==============================
# Säkerställ att Anna Andersson finns som chef
# ==============================

try {
    $ExistingManager = Get-ADUser -Filter "SamAccountName -eq '$ManagerUsername'" -ErrorAction Stop

    if (-not $ExistingManager) {
        New-ADUser `
            -Name "$ManagerFirstName $ManagerLastName" `
            -GivenName $ManagerFirstName `
            -Surname $ManagerLastName `
            -SamAccountName $ManagerUsername `
            -UserPrincipalName $ManagerUPN `
            -DisplayName "$ManagerFirstName $ManagerLastName" `
            -Department "Ledning" `
            -Title "Chef" `
            -Description "Skapad av Onboarding-Automaten | Standardchef" `
            -Path $CheferOU `
            -AccountPassword $Password `
            -Enabled $true `
            -ChangePasswordAtLogon $true

        "[$(Get-Date)] Skapade chefskonto: $ManagerUsername" | Out-File $LogFile -Append -Encoding UTF8
        Write-Host "Skapade chefskonto: $ManagerUsername" -ForegroundColor Green
    }
    else {
        "[$(Get-Date)] Chefskontot finns redan: $ManagerUsername" | Out-File $LogFile -Append -Encoding UTF8
    }

    $ManagerDN = (Get-ADUser -Filter "SamAccountName -eq '$ManagerUsername'").DistinguishedName

    $ManagerIsMember = Get-ADGroupMember -Identity $CheferGroup -Recursive |
    Where-Object { $_.SamAccountName -eq $ManagerUsername }

    if (-not $ManagerIsMember) {
        Add-ADGroupMember -Identity $CheferGroup -Members $ManagerUsername
        "[$(Get-Date)] Lade till $ManagerUsername i gruppen $CheferGroup" | Out-File $LogFile -Append -Encoding UTF8
    }
    else {
        "[$(Get-Date)] $ManagerUsername är redan medlem i $CheferGroup" | Out-File $LogFile -Append -Encoding UTF8
    }
}
catch {
    "[$(Get-Date)] FEL: Kunde inte skapa eller hämta chefskontot $ManagerUsername. $($_.Exception.Message)" | Out-File $LogFile -Append -Encoding UTF8
    Write-Host "Kunde inte skapa eller hämta chefskontot" -ForegroundColor Red
    exit
}

# ==============================
# Hämta data från API och spara som JSON
# ==============================

try {
    $EmployeesFromUrl = Invoke-RestMethod -Uri $Uri -Method Get

    $EmployeesFromUrl | ConvertTo-Json -Depth 10 | Out-File $DataFile -Encoding UTF8

    "[$(Get-Date)] Hämtade onboarding-data från API och sparade till $DataFile. Antal poster: $($EmployeesFromUrl.Count)" | Out-File $LogFile -Append -Encoding UTF8
}
catch {
    "[$(Get-Date)] FEL: Kunde inte hämta data från API. $($_.Exception.Message)" | Out-File $LogFile -Append -Encoding UTF8
    Write-Host "Kunde inte hämta data från API" -ForegroundColor Red
    exit
}


# ==============================
# Läs in användare från JSON-fil
# ==============================

try {
    $Employees = Get-Content $DataFile -Raw | ConvertFrom-Json

    "[$(Get-Date)] Läste in användardata från $DataFile" | Out-File $LogFile -Append -Encoding UTF8
}
catch {
    "[$(Get-Date)] FEL: Kunde inte läsa employees.json. $($_.Exception.Message)" | Out-File $LogFile -Append -Encoding UTF8
    Write-Host "Kunde inte läsa employees.json" -ForegroundColor Red
    exit
}
