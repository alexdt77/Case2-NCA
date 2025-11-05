variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "owner" {
  type    = string
  default = "alex"
}

#VPC Cidr
variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.1.0/24", "10.10.2.0/24"]
}
variable "private_app_cidrs" {
  type    = list(string)
  default = ["10.10.3.0/24", "10.10.4.0/24"]
}

variable "private_data_cidrs" {
  type    = list(string)
  default = ["10.10.5.0/24", "10.10.6.0/24"]
}

variable "my_ip_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

#ECS App instelling
variable "app_image" {
  type    = string
  default = "public.ecr.aws/nginx/nginx:latest"
}

variable "app_cpu" {
  type    = number
  default = 256
}

variable "app_memory" {
  type    = number
  default = 512
}

variable "app_port" {
  type    = number
  default = 80

}

#Database 
variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_master_username" {
  type    = string
  default = "appadmin"
}

variable "db_master_password" {
  type      = string
  sensitive = true
}

#SOAR
variable "alert_email" {
  type    = string
  default = ""
}

variable "existing_lambda_arn" {
  type    = string
  default = ""
}

variable "onprem_cidr" {
  type    = string
  default = "172.16.2.0/24"
}

variable "wg_port" {
  type    = number
  default = 51820
}

variable "wg_transfer_cidr" {
  type    = string
  default = "10.250.0.0/30"
}


