# ==============================
# User Story #19 - Mappbehörigheter
# Sätter bara behörigheter på en mapp 
# ==============================



function Set-OnboardingFolderPermission {
    param (
        # Mappen som redan finns.
        [Parameter(Mandatory = $true)]
        [string]$FolderPath,
	
        # AD-gruppen som ska få åtkomst.
        [Parameter(Mandatory = $true)]
        [string]$GroupName,

        # Domännamn.
        [Parameter(Mandatory = $false)]
        [string]$DomainName = "ITSEC2026"
    )

    try {
        # Kontrollera att mappen finns.
        if (-not (Test-Path $FolderPath)) {
            Write-Host "Mappen finns inte: $FolderPath" -ForegroundColor Yellow
            return
        }

        # Hämta nuvarande NTFS-behörigheter
        $Acl = Get-Acl -Path $FolderPath

        # Stäng av ärvda behörigheter.
        $Acl.SetAccessRuleProtection($true, $false)

        # Ta bort gamla behörigheter från mappen
        foreach ($AccessRule in @($Acl.Access)) {
            $Acl.RemoveAccessRuleAll($AccessRule)
        }

        # Administratörer ska alltid ha full kontroll
        $AdminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "BUILTIN\Administrators",
            "FullControl",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )

        # SYSTEM ska också ha full kontroll
        $SystemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "NT AUTHORITY\SYSTEM",
            "FullControl",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )

        # Rätt AD-grupp får Modify.
        $GroupRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "$DomainName\$GroupName",
            "Modify",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )

        # Lägg till behörigheterna
        $Acl.AddAccessRule($AdminRule)
        $Acl.AddAccessRule($SystemRule)
        $Acl.AddAccessRule($GroupRule)

        # Spara behörigheterna på mappen
        Set-Acl -Path $FolderPath -AclObject $Acl

        Write-Host "#19: Behörighet satt för $DomainName\$GroupName på $FolderPath" -ForegroundColor Green
    }
    catch {
        Write-Host "#19: Fel vid mappbehörigheter på $FolderPath" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

