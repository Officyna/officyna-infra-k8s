data "aws_iam_user" "principal_user" {
  user_name = "officyna"
}
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.cluster_api.name
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.cluster_api.name
}