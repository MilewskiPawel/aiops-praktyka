# PR #3: orders-api: szybciej

**Werdykt:** NIE MERGUJ

## Najważniejsze powody
1. Workflow dostaje `permissions: write-all`: każdy job i każda akcja ma token z zapisem do repo, a domyślnie było tylko `contents: read`.
2. `actions/checkout` jest przypięty do ruchomego tagu `@v4` zamiast pełnego SHA. Do tego to downgrade z v7.0.1.
3. Obraz `orders-api` ma tag `latest`, więc wdrożenie przestaje być powtarzalne. Dodatkowo usunięte są `resources.limits`, a opis „drobne poprawki” nie wyjaśnia, co i dlaczego się zmienia.

## Blokery
- `.github/workflows/ci.yml:14` — permissions: write-all w workflow — globalne `permissions: write-all` zastępuje `contents: read`. Run z tego PR-a (45829888384) już dostał token z pełnym zapisem.
- `.github/workflows/ci.yml:34` — akcja GitHub nieprzypięta do pełnego SHA — `actions/checkout@v4` zamiast `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`.
- `app/deploy/helm/kantyna/values.yaml:78` — obraz z tagiem latest albo bez tagu — `ordersApi.image.tag: latest`.

## Uwagi
- `app/deploy/helm/kantyna/values.yaml:92` — usunięte resources.limits — `ordersApi` traci limity `cpu: 500m` / `memory: 384Mi`. Pod bez limitów może zabrać zasoby całego węzła, a przy wycieku pamięci nic go nie zatrzyma.
- `PR #3 (opis)` — opis PR-a nie mówi, co i dlaczego się zmienia — treść to tylko „drobne poprawki”. Tytuł „szybciej” nie ma pokrycia w diffie: żadna z czterech zmian nie przyspiesza `orders-api`.

## Checki CI
- test orders-api — pass (18s)
- test payments — pass (14s)
- build ${{ matrix.service }} — skipping (oczekiwane: build tylko przy push na main)
- deploy — skipping (oczekiwane: deploy tylko przy push na main)
