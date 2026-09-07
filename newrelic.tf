resource "helm_release" "newrelic_kubernetes" {
  name       = "newrelic-bundle"
  repository = "https://helm-charts.newrelic.com"
  chart      = "nri-bundle"
  namespace  = "newrelic"

  create_namespace = true

  set {
    name  = "global.licenseKey"
    value = var.newrelic_license_key
  }

  set {
    name  = "global.cluster"
    value = var.newrelic_cluster_name
  }

  set {
    name  = "newrelic-infrastructure.enabled"
    value = "true"
  }

  set {
    name  = "kube-state-metrics.enabled"
    value = "true"
  }

  set {
    name  = "nri-metadata-injection.enabled"
    value = "true"
  }

  set {
    name  = "nri-kube-events.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-prometheus-agent.enabled"
    value = "true"
  }

  depends_on = [
    aws_eks_node_group.node_group
  ]
}