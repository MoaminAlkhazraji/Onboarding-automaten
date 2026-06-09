# Roadmap

Roadmapen visar projektets övergripande plan fram till redovisningen. Planen kan justeras under projektets gång om gruppen behöver prioritera om.

## Projektmål

Målet är att utveckla en onboarding-automat som kan använda information från HR för att skapa användarkonton och tilldela rätt grupper, mappar och behörigheter i en labbmiljö.

## Sprintplan

| Sprint | Datum | Fokus | Förväntat resultat |
|--------|--------|-------|--------------------|
| Sprint 1 | 9–10 juni | Sprintplanering, labbmiljö och påbörjad utveckling | Gruppen har valt user stories, satt upp labbmiljö och börjat utveckla onboarding-skriptet |
| Sprint 2 | 11 juni | Fortsatt utveckling | Fler delar av skriptet är påbörjade eller färdigställda |
| Sprint 3 | 12 juni | Testning och förbättringar | Funktioner testas, fel rättas och dokumentationen uppdateras |
| Helg | 13–14 juni | Ingen planerad utveckling | Paus i projektarbetet |
| Sprint 4 | 15–17 juni | Slutförande och presentation | Projektet färdigställs, sluttestas och presenteras |

## Övergripande arbetsflöde

```text
HR-data
   │
   ▼
Formulär / JSON-fil
   │
   ▼
Onboarding-skript
   │
   ├── Skapa användare
   ├── Tilldela grupper
   ├── Skapa mappar
   ├── Hantera behörigheter
   ├── Logga åtgärder
   └── Hantera fel
   │
   ▼
Färdig onboarding i labbmiljö
