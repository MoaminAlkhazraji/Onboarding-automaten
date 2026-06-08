# Git-instruktioner
Denna guide beskriver hur gruppen arbetar med GitHub under projektets gång.

## 1. Klona repot första gången

I Powershell, ställ er där ni vill att repon/mappen ska skapas, t.ex. Documents.

```bash
git clone https://github.com/MoaminAlkhazraji/Onboarding-automaten.git
```

Gå in i Documents och dubbelkolla att Onboarding-automaten-mappen har skapats.

Ställ er sedan i mappen i Powershell:

```bash
cd Onboarding-automaten
git status
```

Kontrollera att allt ser bra ut.

## 2. Daglig rutin innan du börjar jobba (VIKTIGT)

```bash
git checkout main
git pull origin main
```

Gå till main och hämta senaste ändringarna från GitHub.

## 3. Skapa en ny branch eller gå till din branch

```bash
git checkout -b feature/lagg-till-login
```

Nu har du skapat en branch.

Kontrollera att du står i rätt branch:

```bash
git branch
```

Det ska stå ett `*` framför den branch du jobbar i.

## 4. Jobba, spara och pusha upp ändringar

Kontrollera vilka filer som har ändrats:

```bash
git status
```

Lägg till ändringarna:

```bash
git add .
```

Skapa en commit:

```bash
git commit -m "Lade till login funktion i skriptet"
```

Pusha upp branchen till GitHub:

```bash
git push -u origin feature/lagg-till-login
```

Nästa gång du vill pusha ändringar räcker det med:

```bash
git push
```

Innan du kör `git push`, kontrollera alltid med:

```bash
git branch
```

att du står i rätt branch.

## 5. När du är klar och har pushat

Skapa en Pull Request på GitHub.

Gå till:

```text
https://github.com/MoaminAlkhazraji/Onboarding-automaten
```

Du ska se en gul ruta med din branch. Klicka på **Compare & pull request**.

Skriv gärna en tydlig titel och beskrivning om vad du har gjort.

Moamin granskar sedan och mergar din kod till main.

## 6. För dag 2 och framåt

```bash
git checkout main
git pull origin main
git checkout ditt-branch-namn
```

Gå sedan tillbaka till steg 4.
