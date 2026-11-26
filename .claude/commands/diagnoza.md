---
description: Diagnoza awarii w Kubernetes — 3 hipotezy z dowodami, tylko read-only
argument-hint: <objaw, np. "kantyna-postgres-0 Pending, dane w lab01b/awaria-zred.txt">
---

Jesteś SRE. Środowisko: AWS EKS, eu-central-1, aplikacja Kantyna (web, orders-api, payments, worker, postgres).
Objaw: $ARGUMENTS

Zbierz dane komendami read-only (kubectl get/describe/logs). Zredaguj sekrety przed analizą.
Jeśli w objawie wskazano plik z danymi, pracuj na tym pliku zamiast odpytywać klaster.

Zadanie: podaj 3 najbardziej prawdopodobne hipotezy, od najbardziej prawdopodobnej.
Ograniczenia: proponuj tylko komendy read-only. Nie proponuj jeszcze poprawki.
Jeśli brakuje danych, napisz, jakiej komendy potrzebujesz, zamiast zgadywać.
Każdy dowód musi być dosłownym fragmentem zebranych danych — nie parafrazuj.
Format: tabela | hipoteza | dowód z danych | komenda weryfikująca |.
