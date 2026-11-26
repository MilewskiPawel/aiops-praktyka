# Testy deployu: awaria `helm upgrade` w runie 45822905906

## Objaw

Job `deploy`, krok `helm upgrade` (Helm v4.3.0, EKS `aiops`, namespace `pawel-m`):

```text
Error: UPGRADE FAILED: conflict occurred while applying object pawel-m/kantyna-web apps/v1,
Kind=Deployment: Apply failed with 1 conflict: conflict with "kubectl.exe" using apps/v1:
.spec.template.spec.containers[name="web"].image
```

Logowanie do AWS przez OIDC działało: poświadczenia są w env kroku, a `kubeconfig` przeszedł.

## Diagnoza (według `docs/prompts/diagnoza.md`)

| hipoteza | dowód z danych | komenda weryfikująca |
|---|---|---|
| 1. Ktoś ręcznie zmienił obraz `web` (`kubectl set image` z Windows), a Helm 4 przy server-side apply nie nadpisuje pól należących do innego managera | Komunikat wskazuje managera `kubectl.exe` i pole `.image`. Przy `kantyna-web` jest wpis `kubectl.exe Update 2026-11-25T13:42:23Z` z polem `image`. Obraz to `.../kantyna/web:1.0.0` (inna ścieżka niż `pawel-m/kantyna/...`), a pozostałe deploymenty mają już SHA z CI | `kubectl -n pawel-m get deploy kantyna-web --show-managed-fields -o yaml` |
| 2. Inne pola też mają ręcznych właścicieli (np. `kubectl edit`/`scale`) i wyjdą przy kolejnym apply | Komunikat podaje tylko 1 konflikt, a inne pola nie mają managera `kubectl.exe` | ta sama komenda dla każdego `deploy/kantyna-*` |
| 3. `--reuse-values` przenosi stare wartości (`imageRegistry`) | Odrzucona: `--set global.imageRegistry/imageTag` nadpisuje je, a `orders-api`, `payments` i `worker` dostały poprawny obraz | `helm -n pawel-m get values kantyna` |

**Przyczyna:** hipoteza 1 jest potwierdzona w klastrze. Ręczny hotfix lub rollback obrazu `web` z 25.11 przejął własność pola `image`. Helm 4 przy server-side apply traktuje to jako konflikt i przerywa upgrade. Pozostałe deploymenty zostały już zaktualizowane, więc release jest częściowo wdrożony.

## Poprawka

W `.github/workflows/ci.yml` do `helm upgrade` doszła flaga `--force-conflicts`. Helm przejmuje wtedy własność pól, które ktoś zmienił ręcznie. Obrazy ustawia pipeline (źródło prawdy), więc nadpisanie ręcznej zmiany jest tu zamierzone.

Skutek: najbliższy deploy przywróci `web` na obraz `pawel-m/kantyna/web:<SHA>`. Jeśli ręczne `1.0.0` było świadomym rollbackiem, najpierw trzeba wycofać zmianę w kodzie i dopiero potem pushować.

**Ryzyko przy wprowadzaniu poprawki:** flagę `--force-conflicts` wpisaliśmy z pamięci o Helm 4. Nie sprawdziliśmy jej na v4.3.0 przed pushem, bo lokalnie nie było `helm`. Dopiero pierwszy run CI z poprawką mógł pokazać, czy Helm tę flagę przyjmie. Przy podobnych zmianach najpierw trzeba sprawdzić flagę na wersji z pipeline'u (np. `helm upgrade --help | grep force-conflicts` na Helm v4.3.0), a dopiero potem pushować na `main`.

**Wynik:** run `45823647104` (commit `329f749`) skończył się sukcesem we wszystkich jobach, łącznie z `helm upgrade`, rollout status i smoke testem `/healthz`. Flaga działa na v4.3.0. `kantyna-web` działa na `pawel-m/kantyna/web:329f749…`, a w managedFields pole `image` należy już tylko do `helm` (wpisu `kubectl.exe` nie ma).

Alternatywa, której nie wybraliśmy: `--server-side=false` (klasyczny 3-way merge jak w Helm 3). Taki merge po cichu nadpisuje dryf i nie mówi, że pole zmienił ktoś inny.

## Weryfikacja po kolejnym runie

```sh
gh run watch <run-id>
kubectl -n pawel-m get deploy kantyna-web -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl -n pawel-m get deploy kantyna-web --show-managed-fields -o yaml | grep -A2 "manager: kubectl.exe"   # pole image nie powinno już należeć do kubectl.exe
helm -n pawel-m history kantyna --max 3                                                                  # ostatnia rewizja: deployed
```

## Wniosek procesowy

Nie zmieniamy obrazów ręcznie przez `kubectl set image` na środowisku zarządzanym przez Helm. Rollback robimy przez `helm rollback` albo przez revert commita.
