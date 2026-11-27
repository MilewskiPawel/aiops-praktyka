# Odpowiednik k8s/netpol-postgres.yaml.
# Do Postgresa wolno wejść tylko z podów orders-api (ten sam namespace), tylko na 5432/TCP.
# Cały inny ruch przychodzący do kantyna-postgres jest odrzucany. Ruch wychodzący bez zmian.
# Tylko orders-api ma DATABASE_URL; payments, web i worker do bazy nie łączą się.
# kubectl exec / port-forward nie przechodzą przez sieć podów, więc dalej działają.
resource "kubernetes_network_policy_v1" "postgres_ingress" {
  metadata {
    name      = "kantyna-postgres-ingress"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "postgres"
      "app.kubernetes.io/instance"  = "kantyna"
      "app.kubernetes.io/component" = "postgres"
      "app.kubernetes.io/part-of"   = "kantyna"
    }
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name"     = "postgres"
        "app.kubernetes.io/instance" = "kantyna"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name"     = "orders-api"
            "app.kubernetes.io/instance" = "kantyna"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "5432"
      }
    }
  }
}
