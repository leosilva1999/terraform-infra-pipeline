variable "bucket_name" {
  type = string
}

variable "ec2_instance_name" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}