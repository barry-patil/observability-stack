terraform {
  required_version = ">= 1.3"
  required_providers {
    aws  = { source = "hashicorp/aws"; version = "~> 5.0" }
    helm = { source = "hashicorp/helm"; version = "~> 2.12" }
  }
}

provider "aws" { region = var.aws_region }

# Prometheus + Grafana via kube-prometheus-stack
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "58.2.0"

  values = [file("${path.module}/../helm/kube-prometheus-stack-values.yaml")]

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
}

# CloudWatch log group for EKS control plane logs
resource "aws_cloudwatch_log_group" "eks_logs" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30
  tags              = var.common_tags
}

# CloudWatch alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.cluster_name}-high-node-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "EKS node CPU above 85% for 15 minutes"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "failed_node_count" {
  alarm_name          = "${var.cluster_name}-failed-nodes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "cluster_failed_node_count"
  namespace           = "ContainerInsights"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "One or more EKS nodes have failed"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.common_tags
}
