# lab01b — notatki

## Część A: różnice `zly.yaml` vs `dobry.yaml`

> Do uzupełnienia po A1 (`zly.yaml` generowany w nowej sesji, bez kontekstu) i A3:
> `grep -niE 'image:|namespace:|password|port|path:' lab01b/zly.yaml lab01b/dobry.yaml`

1. …
2. …
3. …

## Czego walidator (`kubectl apply --dry-run=server`) nie sprawdził

`dobry.yaml` przeszedł dry-run (`deployment.apps/orders-api-lab created (server dry run)`), ale serwer API sprawdza tylko schemat i uprawnienia. Nie sprawdził m.in.:

- **Czy Secret `kantyna-db` istnieje i ma klucze `username`/`password`.** `secretKeyRef` do nieistniejącego Secretu przechodzi walidację. Błąd wyszedłby dopiero przy starcie poda (`CreateContainerConfigError`). Agent nie może tego sprawdzić, bo dostęp do Secretów jest zablokowany w `.claude/settings.json`.
- **Czy obraz da się pobrać.** Dry-run nie łączy się z rejestrem. Domyślny obraz z `values.yaml` (`123456789012.dkr.ecr…/kantyna/orders-api:0.0.0-dev`) też by przeszedł, a skończyłby się `ImagePullBackOff`.
- **Czy limity mają sens.** `limits.memory: 384Mi` jest poprawne składniowo, ale to, czy orders-api się w nim mieści (np. przy fladze `memory_leak_mb_per_min`), widać dopiero w `kubectl top` lub w metrykach.
- **Czy ServiceAccount `kantyna-orders-api` i ConfigMap `kantyna-flags` istnieją.** Dry-run tego nie wymaga. Sprawdziłem ręcznie przez `kubectl get`: oba istnieją.

## Część B: diagnoza (`awaria.txt`)

- **Naruszenie zasady „do modelu nie trafia żaden sekret”:** fragment `kubectl logs --previous` został wklejony z surowego `awaria.txt`. Trafiły do modelu hasło do bazy (`db_url`, `pool init`) i `api_token` do payments. Przyczyna: wklejanie zaznaczenia z oryginału zamiast z `awaria-zred.txt`. Część B do powtórzenia w nowej sesji (`/clear`).
- **Luka w redakcji z B1:** regex `(password|token|secret)=\S+` nie maskuje hasła w `postgresql://user:HASŁO@host`. Wyłapuje to dopiero kontrolny `grep '@'`. Potrzebna druga reguła: `s#(://[^:/\s]+:)[^@\s]+@#$1***REDACTED***@#g`.
- **Przypuszczenie modelu bez pokrycia w danych:** „pod postgresa działał na starym węźle do rana” to domysł, a „41 minut” w Events nie oznacza początku awarii (zdarzenia wygasają po ok. 1h).
- **Przyczyna źródłowa:** nowa node group tylko w `eu-central-1a` (3× `eu-central-1a`, `ip-10-0-1-*`). PV postgresa (gp3, 19d) jest w innej AZ, więc `volume node affinity conflict`, `kantyna-postgres-0` jest Pending, orders-api dostaje `Connection refused`, a web zwraca 502. Konkretnej strefy PV zrzut nie zawiera.
- **Otwarte pytanie:** strefy czasowe. Logi są w UTC (`07:49:58Z`), a opis („07:10”, „18:00”) nie podaje strefy.
