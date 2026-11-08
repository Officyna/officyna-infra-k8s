# ============================================================
# Mapa da saga (eventos/tópicos do diagrama de sequência)
#
# Fonte única de verdade: pra adicionar um novo evento, adiciona um item
# aqui em "saga_map" e, se "gerenciado = true", um resource correspondente
# abaixo. O step de CI (terraform.yml) lê o output "saga_map" e loga a
# tabela com o status real de cada fila/tópico ao final do apply.
#
# "gerenciado = false" = ainda não tem publisher/consumer implementado em
# nenhum serviço (fluxo de recusa/estorno, fase futura da saga) — entra no
# mapa só pra documentação, não cria nada na AWS.
#
# Por enquanto os serviços continuam criando sozinhos as filas que já
# criavam antes (os-service tem seu próprio CommandLineRunner pra
# eventForDiagnostics/eventGeneratePayment) — não removemos isso agora
# pra não arriscar o deploy de hoje. Isso é consolidado numa próxima rodada.
# ============================================================

locals {
  saga_map = [
    {
      nome       = "eventForDiagnostics"
      tipo       = "SQS"
      publica    = "os-service"
      consome    = "production-service"
      dlq        = "eventForDiagnosticsDlq"
      gerenciado = true
    },
    {
      nome       = "eventDiagnosis"
      tipo       = "SQS"
      publica    = "production-service"
      consome    = "os-service"
      dlq        = "eventDiagnosisDlq"
      gerenciado = true
    },
    {
      nome       = "eventDiagnosisCompleted"
      tipo       = "SQS"
      publica    = "production-service"
      consome    = "os-service"
      dlq        = "eventDiagnosisCompletedDlq"
      gerenciado = true
    },
    {
      nome       = "eventGeneratePayment"
      tipo       = "SQS"
      publica    = "os-service"
      consome    = "billing-service"
      dlq        = "eventGeneratePaymentDlq"
      gerenciado = true
    },
    {
      nome       = "eventBugetGenerated"
      tipo       = "SQS"
      publica    = "billing-service"
      consome    = "os-service"
      dlq        = "eventBugetGeneratedDlq"
      gerenciado = true
    },
    {
      nome       = "eventServiceOrderRecused"
      tipo       = "SNS"
      publica    = "os-service"
      consome    = "production-service + billing-service"
      dlq        = "-"
      gerenciado = true
    },
    {
      nome       = "topicAprovacao"
      tipo       = "SNS"
      publica    = "billing-service"
      consome    = "os-service + production-service"
      dlq        = "-"
      gerenciado = true
    },
    {
      nome       = "topicRejeicao"
      tipo       = "SNS"
      publica    = "billing-service"
      consome    = "os-service"
      dlq        = "-"
      gerenciado = true
    },
  ]

  sqs_queues = {
    for item in local.saga_map : item.nome => item
    if item.gerenciado && item.tipo == "SQS"
  }

  max_receive_count = 3
}

# ============================================================
# Filas SQS (Tier 1 + Tier 2 do mapeamento) + suas DLQs
# ============================================================

resource "aws_sqs_queue" "dlq" {
  for_each = local.sqs_queues

  name                      = each.value.dlq
  message_retention_seconds = 1209600 # 14 dias

  tags = {
    Name    = each.value.dlq
    Project = "officyna"
  }
}

resource "aws_sqs_queue" "queue" {
  for_each = local.sqs_queues

  name = each.key

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = local.max_receive_count
  })

  tags = {
    Name    = each.key
    Project = "officyna"
  }
}

# ============================================================
# SNS topicAprovacao + fila assinante do os-service
#
# O billing-service cria o tópico sozinho (CreateTopic idempotente) na
# primeira publicação, então o resource do tópico aqui é só pra garantir
# que ele exista mesmo antes do primeiro pagamento aprovado. O os-service
# hoje lê "topicAprovacao" via GetQueueUrl, como se fosse uma fila SQS
# comum — por isso precisa de uma fila com esse nome exato, assinando o
# tópico (fan-out SNS->SQS). O código do AbstractSqsQueueListener já sabe
# desembrulhar o envelope {"Type":"Notification","Message":...} do SNS.
# ============================================================

resource "aws_sns_topic" "topic_aprovacao" {
  name              = "topicAprovacao"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name    = "topicAprovacao"
    Project = "officyna"
  }
}

resource "aws_sqs_queue" "topic_aprovacao_os_service" {
  name = "topicAprovacao"

  tags = {
    Name    = "topicAprovacao"
    Project = "officyna"
  }
}

resource "aws_sqs_queue_policy" "topic_aprovacao_os_service_policy" {
  queue_url = aws_sqs_queue.topic_aprovacao_os_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.topic_aprovacao_os_service.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.topic_aprovacao.arn }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "topic_aprovacao_os_service_sub" {
  topic_arn = aws_sns_topic.topic_aprovacao.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.topic_aprovacao_os_service.arn
}

# ============================================================
# SNS eventServiceOrderRecused + fila assinante do billing-service
#
# billing-service já consome (ServiceOrderRecusedEventListener, dispara
# estorno no Mercado Pago quando a OS é recusada/cancelada com pagamento
# já aprovado). os-service ainda não publica — quando publicar, só
# precisa dar CreateTopic/Publish nesse mesmo tópico, nada a mudar aqui.
# Mesmo padrão fan-out do topicAprovacao: fila com o nome exato que o
# consumer espera (aws.sqs.service-order-recused-queue), assinando o
# tópico.
# ============================================================

resource "aws_sns_topic" "event_service_order_recused" {
  name              = "eventServiceOrderRecused"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name    = "eventServiceOrderRecused"
    Project = "officyna"
  }
}

resource "aws_sqs_queue" "event_service_order_recused_billing_service" {
  name = "eventServiceOrderRecused"

  tags = {
    Name    = "eventServiceOrderRecused"
    Project = "officyna"
  }
}

resource "aws_sqs_queue_policy" "event_service_order_recused_billing_service_policy" {
  queue_url = aws_sqs_queue.event_service_order_recused_billing_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.event_service_order_recused_billing_service.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.event_service_order_recused.arn }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "event_service_order_recused_billing_service_sub" {
  topic_arn = aws_sns_topic.event_service_order_recused.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.event_service_order_recused_billing_service.arn
}

# ============================================================
# SNS topicRejeicao
#
# billing-service publica (RejectionTopicPublisher, quando o Mercado
# Pago recusa um pagamento) — ainda sem consumer (os-service trataria
# isso pra cancelar a OS). Só o tópico é criado aqui; quando o consumer
# existir, segue o mesmo padrão de fila assinante acima.
# ============================================================

resource "aws_sns_topic" "topic_rejeicao" {
  name              = "topicRejeicao"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name    = "topicRejeicao"
    Project = "officyna"
  }
}

output "saga_map" {
  value = local.saga_map
}
