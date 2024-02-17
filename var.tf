variable "cidr" {
  default = "10.0.0.0/16"
}

variable "web_ingress" {
  default = {
    "443" = {
      port        = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    "80" = {
      port        = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

variable "secgrp_cidr" {
  default = ["0.0.0.0/0"]
}

variable "web_egress" {
  default = {
    "443" = {
      port        = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    "80" = {
      port        = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

variable "db_name" {
  sensitive = true
}

variable "db_user" {
  sensitive = true
}

variable "db_pass" {
  sensitive = true
}

