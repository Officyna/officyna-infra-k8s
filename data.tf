data "aws_iam_user" "principal_user" {
  user_name = "admin"
}

data "aws_iam_user" "github_actions_user" {
  user_name = "github-actions-officyna"
}
