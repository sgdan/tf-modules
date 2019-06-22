data "aws_eks_cluster" "this" {
  name = var.name
}

data "aws_eks_cluster_auth" "this" {
  name = var.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}

resource "kubernetes_config_map" "aws_auth_configmap" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = {
    mapRoles = templatefile("${path.module}/map_roles.yml", {
      role_arn = var.worker_role_arn
    })
  }
}
