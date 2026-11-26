# Diagnoza awarii

Skopiuj blok niżej i uzupełnij pola `<...>`. Dane wklejaj przycięte i zredagowane (bez haseł, kluczy, danych osobowych).

Jesteś SRE. Środowisko: namespace kantyna, EKS 1.36, eu-central-1 kantyna-orders-api-7d4b9c6f8-8xk2p.
Objaw: od ok. 07:10 zwraca 502 na /api/menu i /api/orders. Wczoraj o 18:00 zespół platformy wymienił node group na nową (nowy typ instancji). Od tego czasu nikt nic nie wdrażał.
Dane:

### $ kubectl -n kantyna get pods
NAME                                  READY   STATUS             RESTARTS        AGE
kantyna-loadgen-6c9f7d8b5-q2kxw       1/1     Running            0               13h
kantyna-orders-api-7d4b9c6f8-8xk2p    0/1     CrashLoopBackOff   11 (2m ago)     41m
kantyna-orders-api-7d4b9c6f8-tw7rn    0/1     CrashLoopBackOff   11 (3m ago)     41m
kantyna-payments-5b8f6d9c7-hp4zt      1/1     Running            0               13h
kantyna-payments-5b8f6d9c7-m9vxs      1/1     Running            0               13h
kantyna-postgres-0                    0/1     Pending            0               41m
kantyna-web-84c7b5d9f-5dqzl           1/1     Running            0               13h
kantyna-web-84c7b5d9f-wj8nc           1/1     Running            0               13h
kantyna-worker-6f5d8c9b4-x7tqm        1/1     Running            0               13h

### $ kubectl -n kantyna logs kantyna-orders-api-7d4b9c6f8-8xk2p --previous --tail=14
{"ts":"2026-10-05T07:49:58Z","level":"INFO","logger":"kantyna.orders","msg":"starting orders-api","version":"1.0.0","variant":"default"}
{"ts":"2026-10-05T07:49:58Z","level":"INFO","logger":"kantyna.db","msg":"db config","db_url":"postgresql://kantyna:Kn7-wr0c!aw-26@kantyna-postgres:5432/kantyna","pool_max":10}
{"ts":"2026-10-05T07:49:58Z","level":"DEBUG","logger":"kantyna.db","msg":"pool init host=kantyna-postgres port=5432 user=kantyna password=Kn7-wr0c!aw-26 sslmode=prefer"}
{"ts":"2026-10-05T07:49:59Z","level":"INFO","logger":"kantyna.payments","msg":"payments client ready url=http://kantyna-payments:8080 api_token=kntn_int_4f9a2c7e1b8d6035"}
{"ts":"2026-10-05T07:50:01Z","level":"WARNING","logger":"kantyna.db","msg":"db connect attempt 1/5 failed","error":"connection to server at \"kantyna-postgres\" (172.20.41.118), port 5432 failed: Connection refused"}
{"ts":"2026-10-05T07:50:03Z","level":"WARNING","logger":"kantyna.db","msg":"db connect attempt 2/5 failed","error":"connection to server at \"kantyna-postgres\" (172.20.41.118), port 5432 failed: Connection refused"}
{"ts":"2026-10-05T07:50:07Z","level":"WARNING","logger":"kantyna.db","msg":"db connect attempt 3/5 failed","error":"connection to server at \"kantyna-postgres\" (172.20.41.118), port 5432 failed: Connection refused"}
{"ts":"2026-10-05T07:50:15Z","level":"WARNING","logger":"kantyna.db","msg":"db connect attempt 4/5 failed","error":"connection to server at \"kantyna-postgres\" (172.20.41.118), port 5432 failed: Connection refused"}
{"ts":"2026-10-05T07:50:31Z","level":"WARNING","logger":"kantyna.db","msg":"db connect attempt 5/5 failed","error":"connection to server at \"kantyna-postgres\" (172.20.41.118), port 5432 failed: Connection refused"}
{"ts":"2026-10-05T07:50:31Z","level":"ERROR","logger":"kantyna.orders","msg":"startup failed: database unavailable","exc":"psycopg.OperationalError: connection to server at \"kantyna-postgres\" (172.20.41.118), port 5432 failed: Connection refused\n\tIs the server running on that host and accepting TCP/IP connections?"}

### $ kubectl -n kantyna describe pod kantyna-postgres-0   (fragment)
Name:             kantyna-postgres-0
Namespace:        kantyna
Node:             <none>
Status:           Pending
Controlled By:    StatefulSet/kantyna-postgres
Containers:
  postgres:
    Image:      postgres:17-alpine
    Requests:   cpu: 100m, memory: 256Mi
    Limits:     cpu: 500m, memory: 512Mi
Volumes:
  data:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  data-kantyna-postgres-0
    ReadOnly:   false
Events:
  Type     Reason            Age                  From               Message
  ----     ------            ----                 ----               -------
  Warning  FailedScheduling  41m                  default-scheduler  0/3 nodes are available: 3 node(s) had volume node affinity conflict. preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
  Warning  FailedScheduling  2m (x9 over 38m)     default-scheduler  0/3 nodes are available: 3 node(s) had volume node affinity conflict. preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.

Już sprawdziłem: Ingress i Service web działają, web zwraca stronę, błąd jest dopiero przy wywołaniu orders-api.
Zadanie: podaj 3 najbardziej prawdopodobne hipotezy, od najbardziej prawdopodobnej.
Ograniczenia: proponuj tylko komendy read-only. Nie proponuj jeszcze poprawki.
Jeśli brakuje danych, napisz, jakiej komendy potrzebujesz, zamiast zgadywać.
Format: tabela | hipoteza | dowód z danych powyżej | komenda weryfikująca |.
lab01b/awaria-zred.txt
Zbierz dane komendami read-only (kubectl get/describe/logs). Zredaguj sekrety przed analizą.