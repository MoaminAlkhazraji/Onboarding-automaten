# Laddar in hjälpfunktioner från ett externt script i samma katalog
. "$PSScriptRoot\Onboarding-Script.ps1"

# Importerar Active Directory-modulen så att AD-cmdlets kan användas
Import-Module ActiveDirectory

# Hämtar API-token från en maskinmiljövariabel
$ApiToken = [Environment]::GetEnvironmentVariable("ONBOARDING_API_TOKEN", "Machine")

# Kontrollerar att API-token finns
if ([string]::IsNullOrWhiteSpace($ApiToken)) {

    # Skriver felmeddelande i rött
    Write-Host "FEL: Miljövariabeln ONBOARDING_API_TOKEN saknas." -ForegroundColor Red

    # Visar instruktion för hur variabeln skapas
    Write-Host "Skapa den med:" -ForegroundColor Yellow

    # Exempelkommando för att skapa miljövariabeln
    Write-Host '[Environment]::SetEnvironmentVariable("ONBOARDING_API_TOKEN", "DIN_TOKEN_HÄR", "Machine")' -ForegroundColor Yellow

    # Avslutar scriptet
    exit
}

# Hämtar standardlösenord från maskinmiljövariabel
$DefaultPasswordPlain = [Environment]::GetEnvironmentVariable("ONBOARDING_DEFAULT_PASSWORD", "Machine")

# Kontrollerar att standardlösenordet finns
if ([string]::IsNullOrWhiteSpace($DefaultPasswordPlain)) {

    # Skriver felmeddelande i rött
    Write-Host "FEL: Miljövariabeln ONBOARDING_DEFAULT_PASSWORD saknas." -ForegroundColor Red

    # Visar instruktion för hur variabeln skapas
    Write-Host "Skapa den med:" -ForegroundColor Yellow

    # Exempelkommando för att skapa miljövariabeln
    Write-Host '[Environment]::SetEnvironmentVariable("ONBOARDING_DEFAULT_PASSWORD", "DITT_STANDARDLÖSENORD", "Machine")' -ForegroundColor Yellow

    # Avslutar scriptet
    exit
}

# Konverterar lösenordet från vanlig text till SecureString
$Password = ConvertTo-SecureString $DefaultPasswordPlain -AsPlainText -Force

# Bygger API-adressen inklusive token som används för autentisering
$Uri = "https://script.google.com/macros/s/AKfycbwFnx_-ZwAeEszfJ9Z72MDfkRddqQsNiVbt6VAlIPftcpvf9zFkYYy8UzYkFV-BPwU/exec?token=$ApiToken"

# Katalog där JSON-data sparas
$DataFolder = "C:\Onboarding\Data"

# Katalog där loggfiler sparas
$LogFolder  = "C:\Onboarding\Logs"

# Katalog för script
$ScriptFolder = "C:\Onboarding\Scripts"

# Baskatalog för användarnas hemkataloger
$HomeFolderBase = "C:\Onboarding\HomeFolders"

# Fil där hämtad personaldata lagras
$DataFile = "$DataFolder\employees.json"

# Loggfil för scriptets körning
$LogFile  = "$LogFolder\onboarding.log"

# Lockfil som används för att förhindra flera samtidiga körningar
$LockFile = "C:\Onboarding\onboarding.lock"

# Domännamn som används för UPN-adresser
$Domain = "itsec2026.local"

# OU för chefer
$CheferOU  = "OU=Chefer,OU=ITSEC2026,DC=itsec2026,DC=local"

# OU för ekonomiavdelningen
$EkonomiOU = "OU=Ekonomi,OU=ITSEC2026,DC=itsec2026,DC=local"

# OU för säljavdelningen
$SaljOU    = "OU=Sälj,OU=ITSEC2026,DC=itsec2026,DC=local"

# Säkerhetsgrupp för chefer
$CheferGroup  = "GG_Chefer"

# Säkerhetsgrupp för ekonomi
$EkonomiGroup = "GG_Ekonomi_Users"

# Säkerhetsgrupp för sälj
$SaljGroup    = "GG_Salj_Users"

# Standardchefens förnamn
$ManagerFirstName = "Anna"

# Standardchefens efternamn
$ManagerLastName  = "Andersson"

# Standardchefens användarnamn
$ManagerUsername  = "anna.andersson"

# Standardchefens User Principal Name
$ManagerUPN       = "$ManagerUsername@$Domain"


# Samlar alla mappar som måste finnas för att scriptet ska fungera
$FoldersToCreate = @(
    $DataFolder,
    $LogFolder,
    $ScriptFolder,
    $HomeFolderBase
)

# Loopar igenom varje mapp i listan
foreach ($Folder in $FoldersToCreate) {

    # Kontrollerar om mappen redan finns
    if (-not (Test-Path $Folder)) {

        # Skapar mappen om den saknas
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    }
}

# Kontrollerar om lockfilen redan existerar
# Detta används för att förhindra att flera instanser av scriptet körs samtidigt
if (Test-Path $LockFile) {

    # Loggar varning om scriptet redan verkar vara igång
    Write-Log "Scriptet körs redan eller avslutades felaktigt tidigare. Avslutar." "WARNING"

    # Avslutar scriptet
    exit
}

# Skapar lockfil som markerar att scriptet körs
New-Item -ItemType File -Path $LockFile -Force | Out-Null

# Startar huvudblocket
try {

    # Skriver startmeddelande till loggen
    Write-Log "=== Startar Onboarding-Automaten ===" "INFO"

    # Kör ett definierat onboardingsteg
    $null = Invoke-OnboardingStep "Kontrollera och skapa AD-grupper" {

        # Lista över grupper som måste finnas
        $GroupsToCheck = @(
            @{ Name = $CheferGroup;  Path = $CheferOU },
            @{ Name = $EkonomiGroup; Path = $EkonomiOU },
            @{ Name = $SaljGroup;    Path = $SaljOU }
        )

        # Loopar igenom varje grupp
        foreach ($Group in $GroupsToCheck) {

            # Söker efter gruppen i Active Directory
            $ExistingGroup = Get-ADGroup -Filter "Name -eq '$($Group.Name)'" -ErrorAction SilentlyContinue

            # Om gruppen inte finns
            if (-not $ExistingGroup) {

                # Skapar ny global säkerhetsgrupp
                New-ADGroup `
                    -Name $Group.Name `
                    -GroupScope Global `
                    -GroupCategory Security `
                    -Path $Group.Path

                # Loggar att gruppen skapades
                Write-Log "Skapade gruppen $($Group.Name)" "SUCCESS"
            }
            else {

                # Loggar att gruppen redan finns
                Write-Log "Gruppen finns redan: $($Group.Name)" "INFO"
            }
        }
    }

    # Nästa onboardingsteg
    $null = Invoke-OnboardingStep "Kontrollera och skapa standardchef" {

        # Söker efter chefskontot i Active Directory
        $ExistingManager = Get-ADUser -Filter "SamAccountName -eq '$ManagerUsername'" -ErrorAction SilentlyContinue

        # Om chefskontot inte finns
        if (-not $ExistingManager) {

            # Skapar chefskontot
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

            # Loggar att chefskontot skapades
            Write-Log "Skapade chefskonto: $ManagerUsername" "SUCCESS"
        }
        else {

            # Loggar att chefskontot redan finns
            Write-Log "Chefskontot finns redan: $ManagerUsername" "INFO"
        }

        # Hämtar chefens Distinguished Name
        # Detta används senare som Manager-attribut på nya användare
        $Script:ManagerDN = (
            Get-ADUser -Filter "SamAccountName -eq '$ManagerUsername'"
        ).DistinguishedName

        # Kontrollerar om chefen redan är medlem i chefsgruppen
        $ManagerIsMember = Get-ADGroupMember -Identity $CheferGroup -Recursive |
            Where-Object { $_.SamAccountName -eq $ManagerUsername }

        # Om medlemskap saknas
        if (-not $ManagerIsMember) {

            # Lägger till chefen i chefsgruppen
            Add-ADGroupMember -Identity $CheferGroup -Members $ManagerUsername

            # Loggar åtgärden
            Write-Log "Lade till $ManagerUsername i gruppen $CheferGroup" "SUCCESS"
        }
        else {

            # Loggar att medlemskapet redan finns
            Write-Log "$ManagerUsername är redan medlem i $CheferGroup" "INFO"
        }
    }


    # Kör onboardingsteg för att hämta användardata från API
    $null = Invoke-OnboardingStep "Hämta onboarding-data från API" {

        # Skickar GET-anrop mot API:t
        # Timeout sätts till 30 sekunder
        $EmployeesFromUrl = Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec 30

        # Kontrollerar om något svar överhuvudtaget kom tillbaka
        if ($null -eq $EmployeesFromUrl -or $EmployeesFromUrl.Count -eq 0) {

            # Loggar att ingen data hittades
            Write-Log "Ingen data hämtades från API:t." "WARNING"

            # Skapar tom användarlista
            $Script:Employees = @()

            # Avslutar detta steg
            return
        }

        # Sparar hämtad data lokalt som JSON-fil
        $EmployeesFromUrl |
            ConvertTo-Json -Depth 10 |
            Out-File $DataFile -Encoding UTF8

        # Loggar antal poster som hämtades
        Write-Log "Hämtade onboarding-data från API och sparade till $DataFile. Antal poster: $($EmployeesFromUrl.Count)" "SUCCESS"

        # Läser tillbaka JSON-filen som PowerShell-objekt
        $Script:Employees = Get-Content $DataFile -Raw | ConvertFrom-Json
    }

    # Om inga användare finns att behandla
    if ($null -eq $Employees -or $Employees.Count -eq 0) {

        # Loggar varning
        Write-Log "Inga användare att behandla. Avslutar." "WARNING"

        # Avslutar scriptet
        exit
    }

    # Räknare för statistik i slutrapporten

    # Antal nya användare som skapats
    $NewUsersCreated = 0

    # Antal användare som redan fanns
    $ExistingUsersSkipped = 0

    # Antal användare som gav fel
    $UsersWithErrors = 0

    # Antal hemkataloger som skapats eller verifierats
    $FoldersCreatedOrChecked = 0

# Loopar igenom varje användare som hämtats från API:t
foreach ($Employee in $Employees) {

    # Hämtar förnamn från objektet
    $FirstName  = $Employee.firstName

    # Hämtar efternamn
    $LastName   = $Employee.lastName

    # Hämtar användarnamn
    $Username   = $Employee.username

    # Hämtar avdelning
    $Department = $Employee.department

    # Hämtar roll/titel
    $Role       = $Employee.role

    # Hämtar chef
    $Manager    = $Employee.manager

    # Hämtar rad-ID från källsystemet
    $RowId      = $Employee.rowId

    # Hämtar startdatum
    $StartDate  = $Employee.startDate

    # Om användarnamn saknas men förnamn och efternamn finns
    if ([string]::IsNullOrWhiteSpace($Username) -and
        -not [string]::IsNullOrWhiteSpace($FirstName) -and
        -not [string]::IsNullOrWhiteSpace($LastName)) {

        # Skapar användarnamn enligt formatet:
        # fornamn.efternamn
        $Username = "$($FirstName.ToLower()).$($LastName.ToLower())"
    }

    # Om användarnamnet inte är tomt
    if (-not [string]::IsNullOrWhiteSpace($Username)) {

        # Tar bort onödiga blanksteg
        $Username = $Username.Trim().ToLower()

        # Ersätter svenska tecken
        # Detta minskar risken för problem i AD
        $Username = $Username `
            -replace "å", "a" `
            -replace "ä", "a" `
            -replace "ö", "o" `
            -replace "[^a-z0-9\.-]", ""

        # Säkerställer att användarnamnet inte blir för långt
        if ($Username.Length -gt 20) {

            # Begränsar till 20 tecken
            $Username = $Username.Substring(0, 20)
        }
    }

    try {

        # Loggar att onboarding påbörjas
        Write-Log "Startar onboarding av $Username" "INFO"

        # Kontrollerar att obligatoriska fält finns
        if ([string]::IsNullOrWhiteSpace($FirstName) -or
            [string]::IsNullOrWhiteSpace($LastName) -or
            [string]::IsNullOrWhiteSpace($Username) -or
            [string]::IsNullOrWhiteSpace($Department) -or
            [string]::IsNullOrWhiteSpace($Role) -or
            [string]::IsNullOrWhiteSpace($Manager)) {

            # Stoppar behandlingen om någon information saknas
            throw "Saknar obligatorisk data för RowID $RowId"
        }

        # Verifierar att användaren har rätt chef
        if ($Manager -ne "Anna Andersson") {

            # Stoppar behandlingen om chefen inte stämmer
            throw "Okänd chef för RowID $RowId : $Manager"
        }

        # Normaliserar avdelningsnamnet
        # Trim tar bort blanksteg
        # ToLowerInvariant gör jämförelsen oberoende av versaler/gemener
        $DepartmentKey = $Department.Trim().ToLowerInvariant()

        # Bestämmer OU och grupp baserat på avdelning
        switch -Wildcard ($DepartmentKey) {

            # Ekonomiavdelningen
            "ekonomi" {

                # Placera användaren i ekonomi-OU
                $TargetOU = $EkonomiOU

                # Lägg användaren i ekonomigruppen
                $TargetGroup = $EkonomiGroup
            }

            # Säljavdelningen
            # Matchar även eventuella teckenproblem med "Sälj"
            "s*lj" {

                # Placera användaren i säljavdelningens OU
                $TargetOU = $SaljOU

                # Lägg användaren i säljavdelningens grupp
                $TargetGroup = $SaljGroup
            }

            # Om avdelningen inte känns igen
            default {

                # Genererar fel
                throw "Okänd avdelning för $Username : $Department"
            }
        }

        # Kontrollerar om användaren redan finns i Active Directory
        $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue

        # Om användaren redan existerar
        if ($ExistingUser) {

            # Ökar räknaren för överhoppade användare
            $ExistingUsersSkipped++

            # Loggar att användaren redan finns
            Write-Log "Befintlig användare hoppades över: $Username" "WARNING"

            # Hoppar till nästa användare i loopen
            continue
        }

        # Skapar nytt Active Directory-konto
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

        # Loggar att användaren skapades
        Write-Log "Skapade AD-användare: $Username i $TargetOU" "SUCCESS"

        # Ökar räknaren för nya användare
        $NewUsersCreated++

        # Lägger användaren i rätt säkerhetsgrupp
        Add-ADGroupMember -Identity $TargetGroup -Members $Username -ErrorAction Stop

        # Loggar gruppmedlemskapet
        Write-Log "Lade till $Username i gruppen $TargetGroup" "SUCCESS"

        # Skapar användarens katalogstruktur
        # Funktionen returnerar sökvägen till hemkatalogen
        $HomePath = New-UserFolderStructure `
            -Username $Username `
            -BasePath $HomeFolderBase

        # Konfigurerar hemkatalogen i Active Directory
        Set-ADUser `
            -Identity $Username `
            -HomeDirectory $HomePath `
            -HomeDrive "H:" `
            -ErrorAction Stop

        # Loggar hemkatalogens sökväg
        Write-Log "Satte hemkatalog för $Username till $HomePath" "SUCCESS"

        # Ökar räknaren för skapade/verifierade mappar
        $FoldersCreatedOrChecked++

        # Loggar att hela onboardingprocessen lyckades
        Write-Log "Onboarding slutförd för $Username" "SUCCESS"
    }

    # Fångar alla fel som uppstår under onboarding av användaren
    catch {

        # Skriver detaljerat felmeddelande till loggen
        Write-Log "Fel vid onboarding av $Username : $($_.Exception.Message)" "ERROR"

        # Ökar felräknaren
        $UsersWithErrors++

        # Fortsätter med nästa användare
        continue
    }
}

# Loggar att hela scriptkörningen är färdig
Write-Log "=== Onboarding-Automaten är klar ===" "INFO"

# Visar antal skapade användare
Write-Log "Nya användare skapade: $NewUsersCreated" "SUCCESS"

# Visar antal användare som redan fanns
Write-Log "Befintliga användare hoppades över: $ExistingUsersSkipped" "WARNING"

# Visar antal hemkataloger som skapats eller verifierats
Write-Log "Hemkataloger skapade/kontrollerade: $FoldersCreatedOrChecked" "INFO"

# Om inga fel inträffade
if ($UsersWithErrors -eq 0) {

    # Loggar felantal som framgång
    Write-Log "Fel: $UsersWithErrors" "SUCCESS"
}
else {

    # Loggar felantal som fel
    Write-Log "Fel: $UsersWithErrors" "ERROR"
}
}

# Körs alltid oavsett om scriptet lyckas eller kraschar
finally {

    # Tar bort lockfilen
    # Detta säkerställer att nästa körning inte blockeras
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}
