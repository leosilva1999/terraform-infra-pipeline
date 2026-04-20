data "aws_ami" "ecs" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["amazon"]
}


data "aws_subnet" "default" {
  default_for_az = true
  availability_zone = "sa-east-1a"
}

resource "aws_cloudwatch_log_group" "ecs" {
  name = "/ecs/titools"
  retention_in_days = 7
}

resource "aws_s3_bucket" "bucket"{
    bucket = var.bucket_name
}

resource "aws_security_group" "titools-sg" {
  name = "titools-sg"
  description = "allow http access and internet outbound"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 3306
    to_port = 3306
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
  network_mode = "awsvpc"
  requires_compatibilities = ["EC2"]

  container_definitions = jsonencode([
    {
      name = "titools"
      image = "leozaodev99/titoolsbackend:latest"

      memory = 256
      
      dependsOn = [
        {
          containerName = "mysql"
          condition     = "HEALTHY"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/titools"
          awslogs-region        = "sa-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }

      portMappings = [
        {
          containerPort = 80
        }
      ]

      environment = [
      {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      },
      {
        name  = "ASPNETCORE_URLS"
        value = "http://+:80"
      },
      {
        name  = "ConnectionStrings__MySqlConnection"
        value = "Server=127.0.0.1;Port=3306;Database=titoolsdb;Uid=titools;Pwd=${var.db_password}"
      },
      {
        name  = "JwtTest__ValidIssuer"
        value = "http://localhost:80/"
      },
      {
        name  = "JwtTest__ValidAudience"
        value = "http://localhost:80"
      },
            {
        name  = "JwtTest__SecretKey"
        value = "CPfYHWwn0ewUdu9jpry+fyUtiwnYm2Zdr6KEpaWFuhA="
      }
    ]
    },
    {
    name  = "mysql"
    image = "mysql:8.0"

    memory = 512

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/titools"
        awslogs-region        = "sa-east-1"
        awslogs-stream-prefix = "ecs"
      }
    }

    portMappings = [
      {
        containerPort = 3306
      }
    ]

    environment = [
      {
        name  = "MYSQL_ROOT_PASSWORD"
        value = var.db_password
      },
      {
        name  = "MYSQL_DATABASE"
        value = "titoolsdb"
      },
      {
        name  = "MYSQL_USER"
        value = "titools"
      },
      {
        name  = "MYSQL_PASSWORD"
        value = var.db_password
      },
      {
        name  = "MYSQL_ROOT_HOST"
        value = "%"
      }
    ]

    healthCheck = {
      command = [
        "CMD-SHELL",
        "mysql -h 172.31.12.170 -u$MYSQL_USER -p$MYSQL_PASSWORD -e \"SELECT 1\""
      ]
      interval    = 10
      timeout     = 5
      retries     = 10
      startPeriod = 90
    }
  }
  ])
}

resource "aws_instance" "ecs" {
  ami = data.aws_ami.ecs.id
  instance_type = "t3.micro"

  key_name = "PrincipalKey"

  iam_instance_profile = aws_iam_instance_profile.ecs_profile.name
  vpc_security_group_ids = [aws_security_group.titools-sg.id]
  subnet_id = data.aws_subnet.default.id
  associate_public_ip_address = true

  user_data = file("user_data.sh")
}

resource "aws_ecs_service" "titools" {
  name = "titools-api-service"
  depends_on = [aws_instance.ecs]
  launch_type = "EC2"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.titools-app.arn
  desired_count = 1

  network_configuration {
    subnets         = [data.aws_subnet.default.id]
    security_groups = [aws_security_group.titools-sg.id]
  }
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}