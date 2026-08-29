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
| `aws_eks_cluster.cluster` | Cluster EKS (`eks-officyna-service`) |
| `aws_eks_node_group.node_group` | Node group gerenciado (1-2 nós `t3.medium`) |
| `aws_iam_role.cluster` / `aws_iam_role.node` | Roles IAM do cluster e dos nodes |
| `aws_route_table.route_table_public` | Rota pública associada às subnets do cluster |
| `aws_eks_access_entry` | Acesso administrativo ao cluster via IAM |

O cluster roda na **mesma VPC/subnets criadas pelo
[officyna-infra-db](https://github.com/Officyna/officyna-infra-db)** —
`vpc_id` e `subnet_ids` são lidos do SSM Parameter Store em tempo de
`plan`/`apply`/`destroy` (veja CI/CD abaixo), então o `officyna-infra-db`
precisa ter sido aplicado antes deste repositório.

O estado do Terraform é armazenado remotamente no bucket S3
`projeto-officyna-soat` (`eks/terraform.tfstate`).

## Pré-requisitos

- [Terraform >= 1.5](https://developer.hashicorp.com/terraform/install)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  configurado com permissões de EKS/IAM/EC2
- Credenciais AWS com acesso ao bucket de state remoto

## Como aplicar localmente

`vpc_id` é obrigatório (não tem default) e vem do output do `officyna-infra-db`;
`subnet_ids` é opcional — se não for informado, o módulo cria 3 subnets próprias na VPC.

```bash
terraform init
terraform plan -var="vpc_id=<vpc-id-do-officyna-infra-db>"
terraform apply -var="vpc_id=<vpc-id-do-officyna-infra-db>"
```

## Como destruir

```bash
terraform destroy
```

## CI/CD

Um único workflow, [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml),
cuida de tudo:

- **Pull Request para `main`**: `terraform fmt -check`, `terraform validate` e
  `terraform plan` (job `plan`) — antes do plan, lê `vpc_id`/`subnet_ids`
  publicados pelo `officyna-infra-db` no SSM Parameter Store.
- **Push em `main`**: `terraform apply -auto-approve` (job `apply`, infraestrutura fica no ar), lendo a mesma rede via SSM.
- **Manual** (aba *Actions* → *Terraform CI/CD (EKS)* → *Run workflow*):
  escolha `action: apply` para reaplicar, ou `action: destroy` (digitando
  `destroy` no campo de confirmação) para desligar o cluster quando não
  estiver em uso e evitar custo na AWS.

### Secrets necessários no repositório

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key com permissão de provisionar EKS/IAM/EC2/SSM |
| `AWS_SECRET_ACCESS_KEY` | Secret key correspondente |
| `AWS_REGION` | Região da AWS (ex: `us-east-1`) |

### Regras de proteção da branch `main`

- Bloqueada para commits diretos.
- Merge somente via Pull Request, com deploy automático (`terraform apply`)
  disparado após o merge.

## Repositórios relacionados

- [officyna-service](https://github.com/Officyna/officyna-service) — aplicação principal
- [officyna-infra-db](https://github.com/Officyna/officyna-infra-db) — banco de dados gerenciado
