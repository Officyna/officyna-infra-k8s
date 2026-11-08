locals {
  # So sobe o mongo-express quando as 3 variaveis (endpoint + senha do docdb + senha do basic auth)
  # estiverem preenchidas. Sem elas, fica tudo desligado (default = "" nas variaveis).
  deploy_mongo_express = var.docdb_endpoint != "" && var.docdb_password != "" && var.mongo_express_basicauth_password != ""

  mongo_express_mongo_url = "mongodb://officynasoatdbuser:${var.docdb_password}@${var.docdb_endpoint}:27017/officyna?tls=true&tlsAllowInvalidCertificates=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
}

resource "kubernetes_secret" "mongo_express" {
  count = local.deploy_mongo_express ? 1 : 0

  metadata {
    name      = "mongo-express-secret"
    namespace = "default"
  }

  data = {
    mongodb-url        = local.mongo_express_mongo_url
    basicauth-username = "officyna"
    basicauth-password = var.mongo_express_basicauth_password
  }
}

resource "kubernetes_deployment" "mongo_express" {
  count = local.deploy_mongo_express ? 1 : 0

  metadata {
    name      = "mongo-express"
    namespace = "default"
    labels = {
      app = "mongo-express"
    }
  }

  # Nao trava o apply esperando o rollout ficar saudavel - como e uma ferramenta de teste que
  # sobe/derruba com frequencia, preferimos um apply rapido e debugar via kubectl se o pod nao
  # subir, em vez do CI ficar preso minutos esperando um timeout.
  wait_for_rollout = false

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mongo-express"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongo-express"
        }
      }

      spec {
        container {
          name  = "mongo-express"
          image = "mongo-express:1.0.2-20"

          port {
            container_port = 8081
          }

          env {
            name = "ME_CONFIG_MONGODB_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongo_express[0].metadata[0].name
                key  = "mongodb-url"
              }
            }
          }

          env {
            name = "ME_CONFIG_BASICAUTH_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongo_express[0].metadata[0].name
                key  = "basicauth-username"
              }
            }
          }

          env {
            name = "ME_CONFIG_BASICAUTH_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongo_express[0].metadata[0].name
                key  = "basicauth-password"
              }
            }
          }

          env {
            name  = "ME_CONFIG_MONGODB_ENABLE_ADMIN"
            value = "false"
          }

          # mongo-express manda essa flag pro driver do Mongo separado da URL de conexao - sem
          # isso ela vem false por padrao e entra em conflito com o "tls=true" que ja esta na
          # connection string (erro "All values of tls/ssl must be the same"). A imagem usada
          # e a release 1.0.2, que usa os nomes antigos (ME_CONFIG_MONGODB_SSL*), nao os novos
          # ME_CONFIG_MONGODB_TLS* que so existem em versao mais recente/nao lancada.
          env {
            name  = "ME_CONFIG_MONGODB_SSL"
            value = "true"
          }

          env {
            name  = "ME_CONFIG_MONGODB_SSLVALIDATE"
            value = "false"
          }

          # Sem isso o basic auth fica DESABILITADO por padrao (false) - na release 1.0.2 a
          # flag se chama ME_CONFIG_BASICAUTH, sem o sufixo _ENABLED.
          env {
            name  = "ME_CONFIG_BASICAUTH"
            value = "true"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mongo_express" {
  count = local.deploy_mongo_express ? 1 : 0

  metadata {
    name      = "mongo-express"
    namespace = "default"
  }

  spec {
    selector = {
      app = "mongo-express"
    }

    port {
      port        = 80
      target_port = 8081
    }

    type = "LoadBalancer"
  }
}
