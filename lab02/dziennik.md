# Dziennik incydentu — Kantyna, namespace `pawel-m`

**Data:** 2026-11-25, awaria wprowadzona ok. 13:21 (UTC)
**Objaw:** aplikacja zwraca HTTP 503 (web nie łączy się z orders-api)
**Wynik po naprawie:** `setup/check.sh pawel-m` → `SUKCES: 11/11`

| # | Co było zepsute | Dowód | Naprawa |
|---|---|---|---|
| 1 | `kantyna-web` używał obrazu `web:1.0.1`, którego nie ma w ECR | `ImagePullBackOff` … `web:1.0.1: not found` | `rollout undo --to-revision=1` (wraca obraz `1.0.0`) |
| 2 | `orders-api` łączył się z hostem `kantyna-postgresql` zamiast `kantyna-postgres` | `Name or service not known` w logach, CrashLoopBackOff | `rollout undo --to-revision=1` |
| 3 | `kantyna-worker` miał request pamięci `2Gi` i nie mieścił się w quocie | `exceeded quota: participant-quota, requested: requests.memory=2Gi` | `rollout undo --to-revision=1` (wraca `128Mi`) |
| 4 | Selektor Service `kantyna-payments` wskazywał `name: payment`, a pody mają etykietę `payments` | Service bez endpointów | `kubectl patch svc` z poprawionym selektorem |
| 5 | NetworkPolicy `kantyna-orders-api-ingress` wpuszczała ruch tylko od `name=frontend`, a pody web mają etykietę `web` | nginx: `upstream timed out … while connecting to upstream`, stąd 504/503 | `kubectl patch networkpolicy`: selektor zmieniony na `web` |
