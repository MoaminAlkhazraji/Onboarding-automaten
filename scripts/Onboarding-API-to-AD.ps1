# ==============================
# Hämta in Onboarding-Script.ps1
# ==============================
. "$PSScriptRoot\Onboarding-Script.ps1"

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
$Script:LogFile = $LogFile
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

$FoldersToCreate = @(
    $DataFolder,
    $LogFolder,
    $ScriptFolder,
    $HomeFolderBase
)

foreach ($Folder in $FoldersToCreate) {
    if (-not (Test-Path $Folder)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    }
}

# ==============================
# Hindra dubbelkörning
# ==============================

if (Test-Path $LockFile) {
    Write-Log "Scriptet körs redan eller avslutades felaktigt tidigare. Avslutar." "WARNING"
    exit
}

New-Item -ItemType File -Path $LockFile -Force | Out-Null

try {
    Write-Log "=== Startar Onboarding-Automaten ===" "INFO"      

    # ==============================
    # Säkerställ att grupper finns
    # ==============================

    $null = Invoke-OnboardingStep "Kontrollera och skapa AD-grupper" {

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

    $null = Invoke-OnboardingStep "Kontrollera och skapa standardchef" {

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

    $null = Invoke-OnboardingStep "Hämta onboarding-data från API" {

        $EmployeesFromUrl = Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec 30

        if ($null -eq $EmployeesFromUrl -or $EmployeesFromUrl.Count -eq 0) {
            Write-Log "Ingen data hämtades från API:t." "WARNING"
            $Script:Employees = @()
            return
        }

        $EmployeesFromUrl | ConvertTo-Json -Depth 10 | Out-File $DataFile -Encoding UTF8

        Write-Log "Hämtade onboarding-data från API och sparade till $DataFile. Antal poster: $($EmployeesFromUrl.Count)" "SUCCESS"

        $Script:Employees = Get-Content $DataFile -Raw | ConvertFrom-Json
    }

    if ($null -eq $Employees -or $Employees.Count -eq 0) {
        Write-Log "Inga användare att behandla. Avslutar." "WARNING"
        exit
    }

    # ==============================
    # Räknare för summering
    # ==============================

    $NewUsersCreated = 0
    $ExistingUsersSkipped = 0
    $UsersWithErrors = 0
    $FoldersCreatedOrChecked = 0

    # ==============================
    # Skapa nya användare i AD
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

        if ([string]::IsNullOrWhiteSpace($Username) -and
            -not [string]::IsNullOrWhiteSpace($FirstName) -and
            -not [string]::IsNullOrWhiteSpace($LastName)) {

            $Username = "$($FirstName.ToLower()).$($LastName.ToLower())"
        }

        if (-not [string]::IsNullOrWhiteSpace($Username)) {
            $Username = $Username.Trim().ToLower()

            $Username = $Username `
                -replace "å", "a" `
                -replace "ä", "a" `
                -replace "ö", "o" `
                -replace "[^a-z0-9\.-]", ""

            if ($Username.Length -gt 20) {
                $Username = $Username.Substring(0, 20)
            }
        }

        try {
            Write-Log "Startar onboarding av $Username" "INFO"

            # ==============================
            # Validering: obligatoriska fält
            # ==============================

            if ([string]::IsNullOrWhiteSpace($FirstName) -or
                [string]::IsNullOrWhiteSpace($LastName) -or
                [string]::IsNullOrWhiteSpace($Username) -or
                [string]::IsNullOrWhiteSpace($Department) -or
                [string]::IsNullOrWhiteSpace($Role) -or
                [string]::IsNullOrWhiteSpace($Manager)) {

                throw "Saknar obligatorisk data för RowID $RowId"
            }

            # ==============================
            # Validering: chef från formuläret
            # ==============================

            if ($Manager -ne "Anna Andersson") {
                throw "Okänd chef för RowID $RowId : $Manager"
            }

            # ==============================
            # Välj OU och grupp baserat på avdelning
            # ==============================

            $DepartmentKey = $Department.Trim().ToLowerInvariant()

            switch -Wildcard ($DepartmentKey) {
                "ekonomi" {
                    $TargetOU = $EkonomiOU
                    $TargetGroup = $EkonomiGroup
                }
                "s*lj" {
                    $TargetOU = $SaljOU
                    $TargetGroup = $SaljGroup
                }
                default {
                    throw "Okänd avdelning för $Username : $Department"
                }
            }

            # ==============================
            # Kontrollera om användaren redan finns
            # ==============================

            $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue

            if ($ExistingUser) {
                $ExistingUsersSkipped++
                Write-Log "Befintlig användare hoppades över: $Username" "WARNING"
                continue
            }

            # ==============================
            # Skapa AD-användare
            # ==============================

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
                -ChangePasswordAtLogon $true `
                -ErrorAction Stop

            Write-Log "Skapade AD-användare: $Username i $TargetOU" "SUCCESS"
            $NewUsersCreated++

            # ==============================
            # Lägg användaren i rätt grupp
            # ==============================

            Add-ADGroupMember -Identity $TargetGroup -Members $Username -ErrorAction Stop
            Write-Log "Lade till $Username i gruppen $TargetGroup" "SUCCESS"

            # ==============================
            # Skapa hemkatalog + undermappar
            # ==============================

            $HomePath = New-UserFolderStructure -Username $Username -BasePath $HomeFolderBase -Department $Department

            Set-ADUser -Identity $Username -HomeDirectory $HomePath -HomeDrive "H:" -ErrorAction Stop

            Write-Log "Satte hemkatalog för $Username till $HomePath" "SUCCESS"

            $FoldersCreatedOrChecked++

            Write-Log "Onboarding slutförd för $Username" "SUCCESS"
        }
        catch {
            Write-Log "Fel vid onboarding av $Username : $($_.Exception.Message)" "ERROR"
            $UsersWithErrors++
            continue
        }
    }

    # ==============================
    # Summering
    # ==============================

    Write-Log "=== Onboarding-Automaten är klar ===" "INFO"
    Write-Log "Nya användare skapade: $NewUsersCreated" "SUCCESS"
    Write-Log "Befintliga användare hoppades över: $ExistingUsersSkipped" "WARNING"
    Write-Log "Hemkataloger skapade/kontrollerade: $FoldersCreatedOrChecked" "INFO"

    if ($UsersWithErrors -eq 0) {
        Write-Log "Fel: $UsersWithErrors" "SUCCESS"
    }
    else {
        Write-Log "Fel: $UsersWithErrors" "ERROR"
    }
}
finally {
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}