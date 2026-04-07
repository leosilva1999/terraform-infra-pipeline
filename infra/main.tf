data "aws_ami" "ecs" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*"]
  }

  owners = ["amazon"]
}

resource "aws_s3_bucket" "bucket"{
    bucket = var.bucket_name
}

resource "aws_security_group" "securitygoup" {
  name = "securitygroup"
  description = "allow http access and internet outbound"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 80
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "main" {
  name = "titools-cluster"
}

resource "aws_ecs_task_definition" "titools-app" {
  family = "titools-api"
  network_mode = "bridge"
  requires_compatibilities = ["EC2"]

  container_definitions = jsonencode([
    {
      name = "titools"
      image = "leozaodev99/titoolsbackend:latest"

      memory = 256
      
      portMapping = [
        {
          containerPort = 80
          hostPort = 80
        }
      ]
    }
  ])
}

resource "aws_instance" "ecs" {
  ami = data.aws_ami.ecs.id
  instance_type = "t3.micro"

  user_data = file("user_data.sh")
}

resource "aws_ecs_service" "titools" {
  name = "titools-api-service"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.titools-app.arn
  desired_count = 1
}