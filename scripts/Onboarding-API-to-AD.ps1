# ==============================
# Onboarding-Automaten
# Formulär/API -> JSON -> AD -> OU -> Grupp -> Manager -> Hemkatalog
# API-token och standardlösenord hämtas från miljövariabler
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

$DefaultPasswordPlain = [Environment]::GetEnvironmentVariable("ONBOARDING_DEFAULT_PASSWORD", "Machine")

if ([string]::IsNullOrWhiteSpace($DefaultPasswordPlain)) {
    Write-Host "FEL: Miljövariabeln ONBOARDING_DEFAULT_PASSWORD saknas." -ForegroundColor Red
    Write-Host "Skapa den med:" -ForegroundColor Yellow
    Write-Host '[Environment]::SetEnvironmentVariable("ONBOARDING_DEFAULT_PASSWORD", "DITT_STANDARDLÖSENORD", "Machine")' -ForegroundColor Yellow
    exit
}

$Password = ConvertTo-SecureString $DefaultPasswordPlain -AsPlainText -Force

$Uri = "https://script.google.com/macros/s/AKfycbwFnx_-ZwAeEszfJ9Z72MDfkRddqQsNiVbt6VAlIPftcpvf9zFkYYy8UzYkFV-BPwU/exec?token=$ApiToken"

$DataFolder = "C:\Onboarding\Data"
$LogFolder  = "C:\Onboarding\Logs"
$ScriptFolder = "C:\Onboarding\Scripts"
$HomeFolderBase = "C:\Onboarding\HomeFolders"

$DataFile = "$DataFolder\employees.json"
$LogFile  = "$LogFolder\onboarding.log"
$LockFile = "C:\Onboarding\onboarding.lock"

$Domain = "itsec2026.local"

# OU-sökvägar
$CheferOU  = "OU=Chefer,OU=ITSEC2026,DC=itsec2026,DC=local"
$EkonomiOU = "OU=Ekonomi,OU=ITSEC2026,DC=itsec2026,DC=local"
$SaljOU    = "OU=Sälj,OU=ITSEC2026,DC=itsec2026,DC=local"

# AD-grupper
$CheferGroup  = "GG_Chefer"
$EkonomiGroup = "GG_Ekonomi_Users"
$SaljGroup    = "GG_Salj_Users"

# Standardchef
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

    Invoke-OnboardingStep "Kontrollera och skapa AD-grupper" {

        $GroupsToCheck = @(
            @{ Name = $CheferGroup;  Path = $CheferOU },
            @{ Name = $EkonomiGroup; Path = $EkonomiOU },
            @{ Name = $SaljGroup;    Path = $SaljOU }
        )

        foreach ($Group in $GroupsToCheck) {
            $ExistingGroup = Get-ADGroup -Filter "Name -eq '$($Group.Name)'" -ErrorAction SilentlyContinue

            if (-not $ExistingGroup) {
                New-ADGroup `
                    -Name $Group.Name `
                    -GroupScope Global `
                    -GroupCategory Security `
                    -Path $Group.Path

                Write-Log "Skapade gruppen $($Group.Name)" "SUCCESS"
            }
            else {
                Write-Log "Gruppen finns redan: $($Group.Name)" "INFO"
            }
        }
    }


# ==============================
    # Säkerställ att Anna Andersson finns som chef
    # ==============================

    Invoke-OnboardingStep "Kontrollera och skapa standardchef" {

        $ExistingManager = Get-ADUser -Filter "SamAccountName -eq '$ManagerUsername'" -ErrorAction SilentlyContinue

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

            Write-Log "Skapade chefskonto: $ManagerUsername" "SUCCESS"
        }
        else {
            Write-Log "Chefskontot finns redan: $ManagerUsername" "INFO"
        }

        $Script:ManagerDN = (Get-ADUser -Filter "SamAccountName -eq '$ManagerUsername'").DistinguishedName

        $ManagerIsMember = Get-ADGroupMember -Identity $CheferGroup -Recursive |
            Where-Object { $_.SamAccountName -eq $ManagerUsername }

        if (-not $ManagerIsMember) {
            Add-ADGroupMember -Identity $CheferGroup -Members $ManagerUsername
            Write-Log "Lade till $ManagerUsername i gruppen $CheferGroup" "SUCCESS"
        }
        else {
            Write-Log "$ManagerUsername är redan medlem i $CheferGroup" "INFO"
        }
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

# ==============================
# Räknare för summering
# ==============================

$NewUsersCreated = 0
$ExistingUsersSkipped = 0
$UsersWithErrors = 0


# ==============================
# Skapa nya användare i AD
# Befintliga användare hoppas över tyst
# ==============================

foreach ($Employee in $Employees) {

    $FirstName  = $Employee.firstName
    $LastName   = $Employee.lastName
    $Username   = $Employee.username
    $Department = $Employee.department
    $Role       = $Employee.role
    $Manager    = $Employee.manager
    $RowId      = $Employee.rowId
    $StartDate  = $Employee.startDate

    # Om API:t inte skickar username, skapa username automatiskt
    if ([string]::IsNullOrWhiteSpace($Username) -and
        -not [string]::IsNullOrWhiteSpace($FirstName) -and
        -not [string]::IsNullOrWhiteSpace($LastName)) {

        $Username = "$($FirstName.ToLower()).$($LastName.ToLower())"
    }


    # ==============================
    # Validering: obligatoriska fält
    # ==============================

    if ([string]::IsNullOrWhiteSpace($FirstName) -or
        [string]::IsNullOrWhiteSpace($LastName) -or
        [string]::IsNullOrWhiteSpace($Username) -or
        [string]::IsNullOrWhiteSpace($Department) -or
        [string]::IsNullOrWhiteSpace($Role) -or
        [string]::IsNullOrWhiteSpace($Manager)) {

        "[$(Get-Date)] FEL: Saknar obligatorisk data för RowID $RowId" | Out-File $LogFile -Append -Encoding UTF8
        Write-Host "Hoppar över RowID $RowId - saknar obligatorisk data" -ForegroundColor Red
        $UsersWithErrors++
        continue
    }


    # ==============================
    # Validering: chef från formuläret
    # ==============================

    if ($Manager -ne "Anna Andersson") {
        "[$(Get-Date)] FEL: Okänd chef för RowID $RowId : $Manager" | Out-File $LogFile -Append -Encoding UTF8
        Write-Host "Hoppar över $Username - okänd chef: $Manager" -ForegroundColor Red
        $UsersWithErrors++
        continue
    }


    # ==============================
    # Välj OU och grupp baserat på avdelning
    # ==============================

    switch ($Department.ToLower()) {
        "ekonomi" {
            $TargetOU = $EkonomiOU
            $TargetGroup = $EkonomiGroup
        }
        "sälj" {
            $TargetOU = $SaljOU
            $TargetGroup = $SaljGroup
        }
        default {
            "[$(Get-Date)] FEL: Okänd avdelning för $Username : $Department" | Out-File $LogFile -Append -Encoding UTF8
            Write-Host "Hoppar över $Username - okänd avdelning: $Department" -ForegroundColor Red
            $UsersWithErrors++
            continue
        }
    }


    # ==============================
    # Kontrollera om användaren redan finns
    # ==============================

    $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue

    if ($ExistingUser) {
        $ExistingUsersSkipped++
        "[$(Get-Date)] Befintlig användare hoppades över: $Username" | Out-File $LogFile -Append -Encoding UTF8
        continue
    }


    # ==============================
    # Skapa ny AD-användare
    # ==============================

    try {
        New-ADUser `
            -Name "$FirstName $LastName" `
            -GivenName $FirstName `
            -Surname $LastName `
            -SamAccountName $Username `
            -UserPrincipalName "$Username@$Domain" `
            -DisplayName "$FirstName $LastName" `
            -Department $Department `
            -Title $Role `
            -Manager $ManagerDN `
            -Description "Skapad av Onboarding-Automaten | RowID: $RowId | Startdatum: $StartDate" `
            -Path $TargetOU `
            -AccountPassword $Password `
            -Enabled $true `
            -ChangePasswordAtLogon $true

        "[$(Get-Date)] Skapade AD-användare: $Username i $TargetOU" | Out-File $LogFile -Append -Encoding UTF8
        Write-Host "Ny användare skapad: $Username" -ForegroundColor Green

        $NewUsersCreated++
    }
    catch {
        "[$(Get-Date)] FEL vid skapande av $Username : $($_.Exception.Message)" | Out-File $LogFile -Append -Encoding UTF8
        Write-Host "Fel vid skapande av: $Username" -ForegroundColor Red
        $UsersWithErrors++
        continue
    }


    # ==============================
    # Lägg ny användare i rätt grupp
    # ==============================

    try {
        $IsMember = Get-ADGroupMember -Identity $TargetGroup -Recursive |
        Where-Object { $_.SamAccountName -eq $Username }

        if ($IsMember) {
            "[$(Get-Date)] $Username är redan medlem i $TargetGroup" | Out-File $LogFile -Append -Encoding UTF8
        }
        else {
            Add-ADGroupMember -Identity $TargetGroup -Members $Username

            "[$(Get-Date)] Lade till $Username i gruppen $TargetGroup" | Out-File $LogFile -Append -Encoding UTF8
            Write-Host "Lade till $Username i gruppen $TargetGroup" -ForegroundColor Green
        }
    }
    catch {
        "[$(Get-Date)] FEL: Kunde inte lägga till $Username i gruppen $TargetGroup. $($_.Exception.Message)" | Out-File $LogFile -Append -Encoding UTF8
        Write-Host "Kunde inte lägga till $Username i gruppen $TargetGroup" -ForegroundColor Red
        $UsersWithErrors++
    }
}

# ==============================
# Klart
# ==============================

"[$(Get-Date)] Onboarding-scriptet är klart. Nya användare: $NewUsersCreated. Befintliga hoppades över: $ExistingUsersSkipped. Fel: $UsersWithErrors." | Out-File $LogFile -Append -Encoding UTF8

Write-Host "Onboarding-scriptet är klart" -ForegroundColor Green
Write-Host "Nya användare skapade: $NewUsersCreated" -ForegroundColor Green
Write-Host "Befintliga användare hoppades över: $ExistingUsersSkipped" -ForegroundColor Yellow
if ($UsersWithErrors -eq 0) {
    Write-Host "Fel: $UsersWithErrors" -ForegroundColor Green
}
else {
    Write-Host "Fel: $UsersWithErrors" -ForegroundColor Red
}