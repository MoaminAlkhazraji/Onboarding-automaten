# Teknisk Guide – Felsökning av Onboarding-Automaten

## 1. Kontrollera loggfilen först

Systemet loggar alla händelser med nivåerna:

INFO = Information
SUCCESS = Steg lyckades
WARNING = Varning
ERROR = Fel

Exempel:
[2026-05-10 08:15:01] [INFO] Startar: Skapa användare
[2026-05-10 08:15:02] [SUCCESS] Slutfört: Skapa användare
Vid fel
[2026-05-10 08:15:02] [ERROR] FEL i steg 'Skapa användare'

Åtgärd: Läs senaste ERROR-raden för att identifiera problemet

## 2. Problem: Loggfilen skapas inte

Symptom:
Kunde inte skriva till loggfil!

Möjliga orsaker:
Fel sökväg till loggfilen
Användaren saknar skrivbehörighet
Disken är full

Lösning:
Kontrollera att $LogFile pekar på en giltig plats och att skriptet har rättigheter att skriva där

## 3. Problem: Hemkatalog skapas inte
Symptom:
Fel vid skapande av mappar för användare
Möjliga orsaker
Basmappen finns inte
Felaktig sökväg i $BasePath
Otillräckliga rättigheter
Kontroll

Testa:
Test-Path $BasePath

Om resultatet är "False" måste sökvägen skapas eller korrigeras

## 4. Problem: Användarmappen finns redan

Symptom:
Hemkatalog finns redan

Orsak:
Användaren har redan onboardats tidigare

Åtgärd:
Kontrollera om:
Det är samma användare
Processen körts flera gånger
Detta är en varning (WARNING), inte ett kritiskt fel

## 5. Problem: Ett onboardingsteg misslyckas
Symptom:
FEL i steg 'Stegnamn'
Orsak:
Fel uppstod i ScriptBlock som körs via:
Invoke-OnboardingStep

Åtgärd:
Kontrollera:
Inkommande data
Variabler som används i steget
Behörigheter mot filsystem eller AD
Eftersom Try/Catch används fortsätter övriga steg utan att hela skriptet kraschar

## 6. Problem: JSON- eller CSV-fil kan inte läsas

Symptom:
Importen startar inte eller användare skapas inte

Möjliga orsaker:
Filen saknas
Fel filformat
Fel kolumnnamn
Ogiltig JSON-struktur

Kontrollera:
CSV:
Import-Csv .\anstallda.csv
JSON:
Get-Content .\anstallda.json | ConvertFrom-Json

Lösning:
Verifiera att filen innehåller alla obligatoriska fält:
Förnamn
Efternamn
Användarnamn
Avdelning
Roll

## 7. Problem: Behörigheter kan inte sättas

Symptom:
Användaren får konto men saknar åtkomst till mappar eller resurser

Möjliga orsaker:
Fel gruppnamn
Gruppen existerar inte
Konto saknar rättigheter att tilldela behörigheter

Åtgärd:
Kontrollera:
Gruppens namn.
Att gruppen finns i AD
Att tjänstekontot har nödvändiga rättigheter

## 8. Problem: Skriptet kan inte köras
Symptom:
Running scripts is disabled on this system
Orsak:
PowerShells Execution Policy blockerar skript
Lösning:
Kör PowerShell som administratör:
Set-ExecutionPolicy RemoteSigned

## 9. Checklista före drift

✔ JSON/CSV-fil validerad
✔ Loggfil fungerar
✔ Basmapp existerar
✔ Behörigheter testade
✔ Testanvändare skapad framgångsrikt
✔ Felmeddelanden verifierade i loggen
✔ HR har godkänt datamodellen
