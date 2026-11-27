variable "kubeconfig_path" {
  description = "Ścieżka do kubeconfigu."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kontekst z kubeconfigu (klaster szkoleniowy)."
  type        = string
  default     = "aiops"
}

variable "namespace" {
  description = "Namespace z Kantyną (= login uczestnika)."
  type        = string
  default     = "pawel-m"
}
