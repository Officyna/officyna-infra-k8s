variable "aws_region" {
  description = "Região da AWS"
  type        = string
  default     = "us-east-1"
}
variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "officyna-service"
}

variable "cidr_vpc" {
  description = "CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  default = {
    Name = "officyna-service"
  }
}

variable "instance_type" {
  description = "Tamanho e família padrão da instância EC2 do node"
  type        = string
  default     = "t3.medium"
}

variable "vpc_id" {
  description = "ID da VPC utilizada pelo DocumentDB"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets do cluster. Se vazio, o módulo cria subnets na VPC informada."
  type        = list(string)
  default     = []
}

variable "newrelic_license_key" {
  description = "License key do New Relic"
  type        = string
  sensitive   = true
}

variable "docdb_endpoint" {
  description = "Endpoint do cluster DocumentDB (vem do SSM /officyna/db/endpoint, publicado pelo infra-db)"
  type        = string
  default     = ""
}

variable "docdb_password" {
  description = "Senha do usuário do DocumentDB (mesmo secret DB_PASSWORD do infra-db) — usada só pro mongo-express"
  type        = string
  sensitive   = true
  default     = ""
}

variable "mongo_express_basicauth_password" {
  description = "Senha de acesso única e compartilhada pro mongo-express (interface web de consulta ao DocumentDB)"
  type        = string
  sensitive   = true
  default     = ""
}