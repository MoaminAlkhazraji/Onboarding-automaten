# ============================================================
# Onboarding-Automaten.ps1
# Huvudskript som skapar AD-användare från Google Formulär
# ============================================================
#
# Hämta in hjälpfunktioner från Oboarding-Script.ps1
. "$PSScriptRoot\Onboarding-Script.ps1"

# Börjar använda Active Directory kommandon
# Formulär/API -> JSON -> AD -> OU -> Grupp -> Manager -> Hemkatalog
# API-token och standardlösenord hämtas från miljövariabler av säkerhetsskäl
Import-Module ActiveDirectory

# Hämta hemlig API-nyckel från datorns inställningar (säkert sätt)
# Om nyckeln saknas så skriver vi ut ett felmeddelande och avslutar
$ApiToken = [Environment]::GetEnvironmentVariable("ONBOARDING_API_TOKEN", "Machine")
if ([string]::IsNullOrWhiteSpace($ApiToken)) {
    Write-Host "FEL: Miljövariabeln ONBOARDING_API_TOKEN saknas." -ForegroundColor Red
    Write-Host "Skapa den med:" -ForegroundColor Yellow
    Write-Host '[Environment]::SetEnvironmentVariable("ONBOARDING_API_TOKEN", "DIN_TOKEN_HÄR", "Machine")' -ForegroundColor Yellow
    exit
}

# Hämta standardlösenordet som alla nya användare får från början
$DefaultPasswordPlain = [Environment]::GetEnvironmentVariable("ONBOARDING_DEFAULT_PASSWORD", "Machine")
if ([string]::IsNullOrWhiteSpace($DefaultPasswordPlain)) {
    Write-Host "FEL: Miljövariabeln ONBOARDING_DEFAULT_PASSWORD saknas." -ForegroundColor Red
    Write-Host "Skapa den med:" -ForegroundColor Yellow
    Write-Host '[Environment]::SetEnvironmentVariable("ONBOARDING_DEFAULT_PASSWORD", "DITT_STANDARDLÖSENORD", "Machine")' -ForegroundColor Yellow
    exit
}

# Gör om lösenordet till ett säkert format som Active Directory förstår
$Password = ConvertTo-SecureString $DefaultPasswordPlain -AsPlainText -Force

# Adressen till vårt Google Apps Script som hämtar data från formuläret
$Uri = "https://script.google.com/macros/s/AKfycbwFnx_-ZwAeEszfJ9Z72MDfkRddqQsNiVbt6VAlIPftcpvf9zFkYYy8UzYkFV-BPwU/exec?token=$ApiToken"

# Anger var alla filer och mappar ska ligga på servern
$DataFolder = "C:\Onboarding\Data"
$LogFolder  = "C:\Onboarding\Logs"
$ScriptFolder = "C:\Onboarding\Scripts"
$HemkatalogBase = "C:\Onboarding\Hemkatalog"

$DataFile = "$DataFolder\employees.json"
$LogFile  = "$LogFolder\onboarding.log"
$Script:LogFile = $LogFile
$LockFile = "C:\Onboarding\onboarding.lock"

$Domain = "itsec2026.local"

# Anger var i Active Directory de olika avdelningarna ska ligga (OU = Organizational Unit)
$CheferOU  = "OU=Chefer,OU=ITSEC2026,DC=itsec2026,DC=local"
$EkonomiOU = "OU=Ekonomi,OU=ITSEC2026,DC=itsec2026,DC=local"
$SaljOU    = "OU=Sälj,OU=ITSEC2026,DC=itsec2026,DC=local"

# Anger vilka grupper i Active Directory som användarna ska läggas i
$CheferGroup  = "GG_Chefer"
$EkonomiGroup = "GG_Ekonomi_Users"
$SaljGroup    = "GG_Salj_Users"

# Anger vem som ska vara chef för alla nya anställda (standardchef)
$ManagerFirstName = "Anna"
$ManagerLastName  = "Andersson"
$ManagerUsername  = "anna.andersson"
$ManagerUPN       = "$ManagerUsername@$Domain"

# Skapar de mappar som skriptet behöver om de inte redan finns
$FoldersToCreate = @(
    $DataFolder,
    $LogFolder,
    $ScriptFolder,
    $HemkatalogBase
)

foreach ($Folder in $FoldersToCreate) {
    if (-not (Test-Path $Folder)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    }
}

#  Skapar en "låsfil" så att skriptet inte kan köras två gånger samtidigt
#  Detta skyddar Active Directory från att få dubbla eller felaktiga ändringar
if (Test-Path $LockFile) {
    Write-Log "Scriptet körs redan eller avslutades felaktigt tidigare. Avslutar." "WARNING"
    exit
}

New-Item -ItemType File -Path $LockFile -Force | Out-Null

try {
    Write-Log "=== Startar Onboarding-Automaten ===" "INFO"      

    # Se till att de tre AD-grupperna finns (skapa dem om de saknas)
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
            
        }
    }
    
    # Se till att standardchefen "Anna Andersson" finns i Active Directory
    # Om hon inte finns så skapas hon 
    # Vi sparar också var hon ligger så vi kan koppla henne som chef senare
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
        $Script:ManagerDN = (Get-ADUser -Filter "SamAccountName -eq '$ManagerUsername'").DistinguishedName

        $ManagerIsMember = Get-ADGroupMember -Identity $CheferGroup -Recursive | Where-Object { $_.SamAccountName -eq $ManagerUsername }
        if (-not $ManagerIsMember) {
            Add-ADGroupMember -Identity $CheferGroup -Members $ManagerUsername
            Write-Log "Lade till $ManagerUsername i gruppen $CheferGroup" "SUCCESS"
        }
    }

    # Hämta alla nya anställda från Google Formuläret via API:t
    # Resultatet sparas i en fil (employees.json) så vi kan se vad som hämtades
    # Sparas som även som JSON för spårbarhet och felsökning
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
    
    # Förbered räknare som visar hur många som skapades, hoppades över eller fick fel
    $NewUsersCreated = 0
    $ExistingUsersSkipped = 0
    $UsersWithErrors = 0
    $FoldersCreatedOrChecked = 0

    # ============================================================
    # HUVUDLOOP - Här börjar vi gå igenom varje ny anställd en efter en
    # ============================================================
    # För varje person i listan gör vi följande:
    # Kontrollerar att all information finns
    # Bestämmer vilken avdelning de ska till
    # Skapar ett nytt användarkonto i Active Directory
    # Lägger dem i rätt grupp
    # Skapar en personlig hemkatalog (H:-disk)
    foreach ($Employee in $Employees) {

        # Hämta informationen om personen från formuläret
        $FirstName  = $Employee.firstName
        $LastName   = $Employee.lastName
        $Username   = $Employee.username
        $Department = $Employee.department
        $Role       = $Employee.role
        $Manager    = $Employee.manager
        $RowId      = $Employee.rowId
        $StartDate  = $Employee.startDate

        # Om det inte finns något användarnamn men det finns för- och efternamn -> 
        # skapa ett användarnamn automatiskt
        if ([string]::IsNullOrWhiteSpace($Username) -and
            -not [string]::IsNullOrWhiteSpace($FirstName) -and
            -not [string]::IsNullOrWhiteSpace($LastName)) {
            $Username = "$($FirstName.ToLower()).$($LastName.ToLower())"
        }
        
        # Gör användarnamnet "rent" (ta bort åäö och konstiga tecken)
        if (-not [string]::IsNullOrWhiteSpace($Username)) {
            $Username = $Username.Trim().ToLower()
            $Username = $Username `
                -replace "å", "a" `
                -replace "ä", "a" `
                -replace "ö", "o" `
                -replace "[^a-z0-9\.-]", ""

            if ($Username.Length -gt 20) { $Username = $Username.Substring(0, 20) }
        }

        try {
            # Kontrollera att alla obligatoriska uppgifter finns ifyllda
            if ([string]::IsNullOrWhiteSpace($FirstName) -or
                [string]::IsNullOrWhiteSpace($LastName) -or
                [string]::IsNullOrWhiteSpace($Username) -or
                [string]::IsNullOrWhiteSpace($Department) -or
                [string]::IsNullOrWhiteSpace($Role) -or
                [string]::IsNullOrWhiteSpace($Manager)) {
                throw "Saknar obligatorisk data för RowID $RowId"
            }

            # Kontrollera att chefen är "Anna Andersson" (det är den enda chefen vi stödjer just nu)
            if ($Manager -ne "Anna Andersson") {
                throw "Okänd chef för RowID $RowId : $Manager"
            }

            # Välj rätt plats (OU) och rätt grupp beroende på vilken avdelning personen ska till
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

            # Kolla om användaren redan finns i Active Directory
            # Om ja → hoppa över personen och räkna upp "hoppades över"
            $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue
            if ($ExistingUser) {
                $ExistingUsersSkipped++
                Write-Log "Befintlig användare hoppades över: $Username" "WARNING"
                continue
            }

             Write-Log "Startar onboarding av $Username" "INFO"

            # Skapa det nya användarkontot i Active Directory
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

            # Lägg till den nya användaren i rätt säkerhetsgrupp (t.ex. GG_Ekonomi_Users)
            Add-ADGroupMember -Identity $TargetGroup -Members $Username -ErrorAction Stop
            Write-Log "Lade till $Username i gruppen $TargetGroup" "SUCCESS"

            # Skapa en personlig hemkatalog för användaren och koppla den till H:-disken
            $HomePath = New-UserFolderStructure -Username $Username -BasePath $HemkatalogBase -Department $Department
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

    # Skriv ut en slutrapport så vi ser hur det gick
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
    # Ta bort låsfilen så att skriptet kan köras igen nästa gång
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}