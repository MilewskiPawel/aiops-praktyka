# Dziennik incydentu

## Podsumowanie

| Pole | Wartość |
|------|---------|
| ID incydentu | INC-2026-11-27-01 |
| Tytuł | orders-api niegotowe (0/1 Ready) w namespace pawel-m — podejrzenie wycieku puli połączeń DB |
| Status | 🟡 Mitygacja zakończona (serwis działa, 11/11) — do domknięcia: trwałe flagi w Helm, przyczyna zmiany flag |
| Severity | SEV1 / SEV2 / SEV3 |
| Data wykrycia | 2026-11-27 15:36 (UTC+1) |
| Dowódca incydentu (IC) | _imię_ |
| Osoba prowadząca dziennik | _imię_ |
| Dotknięte usługi | orders-api (obie repliki), namespace pawel-m |
| Wpływ na użytkowników | menu i zamówienia przez web niedostępne (check.sh 8/11) |

## Objawy

- Obie repliki `kantyna-orders-api` są `0/1 Ready` (pody orders-api mają ok. 24 h, start niegotowości po zmianie flag — patrz oś czasu; pozostałe pody payments, web, worker, postgres działają, 0 restartów).
- Event: `Readiness probe failed: /readyz ... context deadline exceeded`.
- Logi orders-api (WARNING): `Readiness check failed ... couldn't get a connection after 30.00 sec` (ok. 14:32 UTC).
- Alerty Grafany: brak firing/pending (reguły niezaładowane lub nie dotyczą tego namespace — do sprawdzenia).

## Oś czasu

> Jeden wpis = jedno zdarzenie lub działanie. Godziny w UTC+1. Najnowsze na dole.

| Czas | Kto | Zdarzenie / działanie | Wynik / dowód |
|------|-----|-----------------------|---------------|
| 15:26 | _nieustalono_ | Zmiana ConfigMapu `kantyna-flags` przez `kubectl patch` (nie przez Helm) | `managedFields`: manager `kubectl-patch`, Update, 2026-11-27T14:26:56Z; poprzednio tylko `helm` Apply z 2026-11-24 |
| ok. 15:32 | Claude | Diagnoza read-only: `kubectl`, logi orders-api, ConfigMap `kantyna-flags` | orders-api 0/2 Ready; `/readyz` timeout; log „couldn't get a connection after 30.00 sec”; `db_pool_leak: true`, `slow_menu_query: true` |
| ok. 15:33 | Claude | Próba odczytu `pg_stat_activity` (`kubectl exec` w postgres) | Odrzucone przez klasyfikator uprawnień — niezweryfikowane |
| 15:36 | Claude | Diagnoza ConfigMapu `kantyna-flags` (read-only) | `orders-api.db_pool_leak=true`, `orders-api.slow_menu_query=true`; pozostałe flagi `false`/`0`; `payments` i `worker` bez zaburzeń; CM zarządzany przez Helm (zmiana ręczna zostanie nadpisana przy `helm upgrade`); montowany do orders-api jako volume `flags` |
| 15:36 | Claude | Uruchomiono `setup/check.sh` (namespace pawel-m) | **8/11**. ❌ orders-api gotowe 0/2; ❌ menu przez web (exit code 1); ❌ zamówienie przez web (exit code 1). ✅ web 2/2, payments 2/2, worker 1/1, postgres, 4 serwisy z endpointami |
| 15:41 | Claude (na polecenie użytkownika) | **Zmiana:** `kubectl patch` ConfigMapu `kantyna-flags`: `orders-api.db_pool_leak` true→false, `orders-api.slow_menu_query` true→false (reszta bez zmian; kopia poprzedniej wartości w scratchpadzie) | ConfigMap zawiera `db_pool_leak: false`, `slow_menu_query: false` |
| 15:42 | Claude | Weryfikacja po zmianie (ok. 20 s po patchu): logi orders-api, `setup/check.sh` | Nadal **8/11**; orders-api 0/2 Ready, logi dalej „couldn't get a connection after 30 sec”. Same flagi nie zwolniły już zajętych połączeń w puli — wymagany restart (runbook KantynaDBPoolExhausted, akcja „Restart orders-api”) |
| 15:43 | Claude (na polecenie użytkownika) | **Zmiana:** `kubectl -n pawel-m rollout restart deploy/kantyna-orders-api` (runbook KantynaDBPoolExhausted, akcja safe) | Rollout zakończony ok. 15:43:40; nowe pody `7877648c74-mgrz4` i `-p24sc` 1/1 Ready, stare usunięte |
| 15:44 | Claude | Weryfikacja po restarcie: `setup/check.sh`, logi orders-api | **SUKCES: 11/11**; w logach `Order created` i `POST /pay → 200 OK`, brak „couldn't get a connection” |
| 15:50 | Claude | Prześledzenie pochodzenia flag: `app/deploy/helm/kantyna/values.yaml` (git), `managedFields` ConfigMapu, `audit.jsonl` agenta | W git (`5c02737`, jedyny commit values.yaml) flagi są `false`; `true` pojawiło się tylko w klastrze przez `kubectl patch` (14:26:56 UTC) — poza Helmem i poza git. Agent z lab06 tylko odczytywał flagi (reset odrzucony), nie ustawiał `true` |
| 15:5x | Claude | Branch `fix/flags-revert-db-pool-leak`, PR do forka: komentarz ostrzegawczy w `values.yaml` + dziennik incydentu | PR: https://github.com/MilewskiPawel/aiops-praktyka/pull/4 |
| 15:5x | Claude | Weryfikacja hipotezy wycieku połączeń: ponowna próba `pg_stat_activity` (exec w postgres) + metryki `db_pool_connections_in_use` (Prometheus, 90 min) + kod `app/orders-api/app/db.py` | `exec` ponownie odrzucony przez klasyfikator. Metryki: oba stare pody orders-api — pula 0 do 15:28 (UTC+1), 0→2→**10** i **stałe 10** do restartu (15:43), mimo ruchu z loadgen; nowe pody po restarcie: 0. Kod: `db_pool_leak` = `leak_one_connection()` pobiera połączenie z puli i **nie zwraca** (`_held_connections`) |
| _HH:MM_ | _kto_ | Rozwiązanie / potwierdzenie powrotu do normy | _link do metryk_ |

## Hipotezy

| # | Hipoteza | Status | Dowody |
|---|----------|--------|--------|
| 1 | Wyciek połączeń DB wymuszony flagą `orders-api.db_pool_leak=true` (runbook KantynaDBPoolExhausted) | ✅ Potwierdzona po stronie aplikacji (metryki puli + kod); ❓ po stronie Postgresa niezweryfikowana (`pg_stat_activity` zablokowane; po restarcie połączenia i tak zwolnione) | ConfigMap `kantyna-flags`: `db_pool_leak: true`; log „couldn't get a connection after 30 sec” |
| 2 | `slow_menu_query=true` pogłębia zajętość puli | ❓ Do sprawdzenia | ta sama flaga w ConfigMap |
| 3 | Postgres osiągnął `max_connections` | ❓ Do sprawdzenia | brak danych — `pg_stat_activity` niezweryfikowane (exec odrzucony) |

## Podjęte działania

- [x] Ustawienie `db_pool_leak=false` i `slow_menu_query=false` w ConfigMapie `kantyna-flags` — Claude, wykonane 15:41 (bez efektu na gotowość podów)
- [x] Restart `kantyna-orders-api` — Claude, wykonane 15:43; przywrócił gotowość (check.sh 11/11)
- [x] Wartości Helm w repo już mają flagi `false` (brak dryfu w git); PR dodaje ostrzeżenie w `values.yaml` — Claude, 15:5x
- [ ] Sprawdzić, czy `helm get values` release `kantyna` w `pawel-m` nie nadpisuje flag (odczyt sekretów Helm niedostępny dla Claude)

## Komunikacja

| Czas | Kanał | Odbiorcy | Treść |
|------|-------|----------|-------|
| _HH:MM_ | _Slack / mail / status page_ | _kto_ | _skrót komunikatu_ |

## Przyczyna źródłowa

_Uzupełnić po rozwiązaniu incydentu._

## Wnioski i działania następcze

| Działanie | Właściciel | Termin | Status |
|-----------|-----------|--------|--------|
| _np. dodać alert na X_ | _kto_ | _data_ | _otwarte_ |

## Co poszło dobrze / co poprawić

- **Dobrze:** _…_
- **Do poprawy:** _…_
