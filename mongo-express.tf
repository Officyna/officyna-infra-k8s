locals {
  # So sobe o mongo-express quando as 3 variaveis (endpoint + senha do docdb + senha do basic auth)
  # estiverem preenchidas. Sem elas, fica tudo desligado (default = "" nas variaveis).
  # nonsensitive() aqui so revela um booleano (se a senha foi preenchida ou nao), nunca o
  # valor em si - sem isso o for_each abaixo falha com "Invalid for_each argument" porque o
  # Terraform marca qualquer condicional derivado de uma sensitive var como sensitive tambem,
  # mesmo so comparando com "".
  deploy_mongo_express = nonsensitive(var.docdb_endpoint != "" && var.docdb_password != "" && var.mongo_express_basicauth_password != "")

  # O mongo-express 1.0.2 nao enumera corretamente os outros bancos do cluster (o
  # listDatabases que ele roda internamente fica restrito ao banco que esta na própria
  # connection string - confirmado com um mongosh direto, que ve todos os bancos
  # normalmente). Pra contornar isso sem esperar um fix/upgrade da imagem, sobe uma
  # instancia de mongo-express por banco, cada uma ja conectada direto nele.
  mongo_express_databases = local.deploy_mongo_express ? toset(["officyna", "officyna_supply", "officyna_labor", "officyna_snapshot", "officyna-users"]) : toset([])

  mongo_express_k8s_name = { for db in local.mongo_express_databases : db => "mongo-express-${replace(db, "_", "-")}" }

  mongo_express_mongo_url = { for db in local.mongo_express_databases :
    db => "mongodb://officynasoatdbuser:${var.docdb_password}@${var.docdb_endpoint}:27017/${db}?tls=true&tlsAllowInvalidCertificates=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  }
}

resource "kubernetes_secret" "mongo_express" {
  for_each = local.mongo_express_databases

  metadata {
    name      = "${local.mongo_express_k8s_name[each.key]}-secret"
    namespace = "default"
  }

  data = {
    mongodb-url        = local.mongo_express_mongo_url[each.key]
    basicauth-username = "officyna"
    basicauth-password = var.mongo_express_basicauth_password
  }

  depends_on = [
    aws_eks_node_group.node_group,
    aws_eks_access_entry.access_entry_github_actions,
    aws_eks_access_policy_association.access_entry_association_github_actions
  ]
}

resource "kubernetes_deployment" "mongo_express" {
  for_each = local.mongo_express_databases

  metadata {
    name      = local.mongo_express_k8s_name[each.key]
    namespace = "default"
    labels = {
      app = local.mongo_express_k8s_name[each.key]
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
        app = local.mongo_express_k8s_name[each.key]
      }
    }

    template {
      metadata {
        labels = {
          app = local.mongo_express_k8s_name[each.key]
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
                name = kubernetes_secret.mongo_express[each.key].metadata[0].name
                key  = "mongodb-url"
              }
            }
          }

          env {
            name = "ME_CONFIG_BASICAUTH_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongo_express[each.key].metadata[0].name
                key  = "basicauth-username"
              }
            }
          }

          env {
            name = "ME_CONFIG_BASICAUTH_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongo_express[each.key].metadata[0].name
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

  depends_on = [
    aws_eks_node_group.node_group,
    aws_eks_access_entry.access_entry_github_actions,
    aws_eks_access_policy_association.access_entry_association_github_actions
  ]
}

resource "kubernetes_service" "mongo_express" {
  for_each = local.mongo_express_databases

  metadata {
    name      = local.mongo_express_k8s_name[each.key]
    namespace = "default"
  }

  spec {
    selector = {
      app = local.mongo_express_k8s_name[each.key]
    }

    port {
      port        = 80
      target_port = 8081
    }

    type = "LoadBalancer"
  }

  depends_on = [
    aws_eks_node_group.node_group,
    aws_eks_access_entry.access_entry_github_actions,
    aws_eks_access_policy_association.access_entry_association_github_actions
  ]
}
