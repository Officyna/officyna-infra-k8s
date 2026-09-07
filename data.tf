data "aws_iam_user" "principal_user" {
  user_name = "admin"
}

data "aws_iam_user" "github_actions_user" {
  user_name = "github-actions-officyna"
}
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.cluster.name
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.cluster.name
}