# officyna-infra-k8s

Infraestrutura como código (Terraform) do cluster Kubernetes (Amazon EKS) usado
pela aplicação [officyna-service](https://github.com/Officyna/officyna-service).

Parte do Tech Challenge da Pós Tech (Arquitetura de Software Orientada a
Serviços) — repositório separado conforme requisito de segregação de
infraestrutura em repositórios próprios com CI/CD.

## Tecnologias utilizadas

- [Terraform](https://developer.hashicorp.com/terraform) >= 1.5
- [AWS EKS](https://aws.amazon.com/eks/) (Elastic Kubernetes Service)
- GitHub Actions (CI/CD)

## Recursos provisionados

| Recurso | Descrição |
|---|---|
| `aws_eks_cluster.cluster_api` | Cluster EKS (`eks-officyna-service`) |
| `aws_eks_node_group.node_group` | Node group gerenciado (2-3 nós `t3.medium`) |
| `aws_iam_role.cluster` / `aws_iam_role.node` | Roles IAM do cluster e dos nodes |
| `aws_internet_gateway` / `aws_route_table` | Rede pública para os nodes |
| `aws_eks_access_entry` | Acesso administrativo ao cluster via IAM |

O estado do Terraform é armazenado remotamente no bucket S3
`officyna-terraform-state` (`eks/terraform.tfstate`).

## Pré-requisitos

- [Terraform >= 1.5](https://developer.hashicorp.com/terraform/install)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  configurado com permissões de EKS/IAM/EC2
- Credenciais AWS com acesso ao bucket de state remoto

## Como aplicar localmente

```bash
terraform init
terraform plan
terraform apply
```

## Como destruir

```bash
terraform destroy
```

## CI/CD

O workflow em [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml)
executa:

- **Pull Request para `main`**: `terraform fmt -check`, `terraform validate` e
  `terraform plan` (comentando o plano no PR).
- **Push em `main`**: `terraform apply -auto-approve`.

### Secrets necessários no repositório

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key com permissão de provisionar EKS/IAM/EC2 |
| `AWS_SECRET_ACCESS_KEY` | Secret key correspondente |

### Regras de proteção da branch `main`

- Bloqueada para commits diretos.
- Merge somente via Pull Request, com deploy automático (`terraform apply`)
  disparado após o merge.

## Repositórios relacionados

- [officyna-service](https://github.com/Officyna/officyna-service) — aplicação principal
- [officyna-infra-db](https://github.com/Officyna/officyna-infra-db) — banco de dados gerenciado
