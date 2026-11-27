# Druga rola CI: Azure Pipelines (azure-pipelines.yml) przez OIDC service connection.
# Osobny provider i rola, bo issuer Azure DevOps to nie GitHub. Uprawnienia te same co kantyna-ci.
#
# Włączenie: azure_devops_org_id + azure_devops_org + azure_devops_project.
# Puste azure_devops_org_id = nic nie tworzymy (tylko GitHub Actions).

variable "azure_devops_org_id" {
  description = "GUID organizacji Azure DevOps (issuer: https://vstoken.dev.azure.com/<GUID>). Puste = brak roli dla Azure Pipelines."
  type        = string
  default     = ""
}

variable "azure_devops_org" {
  description = "Nazwa organizacji Azure DevOps (jak w dev.azure.com/<org>)"
  type        = string
  default     = ""
}

variable "azure_devops_project" {
  description = "Nazwa projektu Azure DevOps z pipeline'em Kantyny"
  type        = string
  default     = ""
}

variable "azure_devops_service_connection" {
  description = "Nazwa service connection AWS (musi zgadzać się z awsServiceConnection w azure-pipelines.yml)"
  type        = string
  default     = "aws-kantyna-oidc"
}

variable "azure_devops_audience" {
  description = "Audience tokenu OIDC z Azure DevOps"
  type        = string
  default     = "api://AzureADTokenExchange"
}

locals {
  azdo_enabled = var.azure_devops_org_id != ""
  azdo_issuer  = "vstoken.dev.azure.com/${var.azure_devops_org_id}"
}

resource "aws_iam_openid_connect_provider" "azure_devops" {
  count = local.azdo_enabled ? 1 : 0

  url            = "https://${local.azdo_issuer}"
  client_id_list = [var.azure_devops_audience]
}

data "aws_iam_policy_document" "ci_azure_devops_trust" {
  count = local.azdo_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.azure_devops[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.azdo_issuer}:aud"
      values   = [var.azure_devops_audience]
    }

    # sub wskazuje jeden konkretny service connection. Token Azure DevOps nie niesie gałęzi,
    # więc ograniczenie "tylko main" ustawia się w Azure DevOps: Branch control na service connection.
    condition {
      test     = "StringEquals"
      variable = "${local.azdo_issuer}:sub"
      values   = ["sc://${var.azure_devops_org}/${var.azure_devops_project}/${var.azure_devops_service_connection}"]
    }
  }
}

resource "aws_iam_role" "ci_azure_devops" {
  count = local.azdo_enabled ? 1 : 0

  name                 = "kantyna-ci-azure-devops"
  assume_role_policy   = data.aws_iam_policy_document.ci_azure_devops_trust[0].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "ci_azure_devops" {
  count = local.azdo_enabled ? 1 : 0

  name   = "kantyna-ci"
  role   = aws_iam_role.ci_azure_devops[0].id
  policy = data.aws_iam_policy_document.ci.json
}

output "azure_devops_role_arn" {
  description = "ARN roli do wpisania w service connection AWS w Azure DevOps"
  value       = local.azdo_enabled ? aws_iam_role.ci_azure_devops[0].arn : null
}
