# Git-instruktioner

Denna guide beskriver hur gruppen arbetar med GitHub under projektets gång.

## Klona repot första gången

I Powershell, ställ er där ni vill att repot ska skapas, exempelvis i Documents.

```bash
git clone https://github.com/MoaminAlkhazraji/Onboarding-automaten.git
```

Gå sedan in i projektmappen:

```bash
cd Onboarding-automaten
```

Kontrollera att allt ser korrekt ut:

```bash
git status
```

## Daglig rutin innan du börjar jobba

```bash
git checkout main
git pull origin main
```

## Skapa en branch

```bash
git checkout -b feature/lagg-till-login
git branch
```

Kontrollera att du står i rätt branch.

## Jobba, spara och pusha ändringar

```bash
git status
git add .
git commit -m "Lade till login funktion i skriptet"
git push -u origin feature/lagg-till-login
```

Nästa gång räcker det med:

```bash
git push
```

## Skapa Pull Request

1. Gå till GitHub.
2. Klicka på **Compare & pull request**.
3. Skriv en tydlig titel och beskrivning.
4. Skicka Pull Requesten för granskning.

## Dag 2 och framåt

```bash
git checkout main
git pull origin main
git checkout ditt-branch-namn
```
