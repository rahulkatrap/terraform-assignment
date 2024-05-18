terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region = "ap-south-1"

}

resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_subnet" "mysubnet1" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
}
resource "aws_subnet" "mysubnet2" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
}
resource "aws_internet_gateway" "ing" {
  vpc_id = aws_vpc.myvpc.id
}
resource "aws_route_table" "rt1" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ing.id
  }
}
resource "aws_route_table_association" "rta" {
  route_table_id = aws_route_table.rt1.id
  subnet_id = aws_subnet.mysubnet1.id 
}
resource "aws_route_table_association" "rta2" {
  route_table_id = aws_route_table.rt1.id
  subnet_id = aws_subnet.mysubnet2.id 
}
    
resource "aws_security_group" "sg" {    
    name = "mysg"
    vpc_id = aws_vpc.myvpc.id 

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
     ingress {
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
resource "aws_ecs_cluster" "ecs" {
    name = "my-cluster"
  
}



resource "aws_ecs_task_definition" "ecsd" {
    family = "test"
    requires_compatibilities = ["FARGATE"]
    network_mode = "awsvpc"
    execution_role_arn = "arn:aws:iam::312356219605:role/taskexe"
    cpu = 1024
    memory = 2048
    container_definitions = <<TASK_DEFINITION
      [
        {
          "name": "hello-world",
          "image": "312356219605.dkr.ecr.ap-south-1.amazonaws.com/my-repo:latest",
          "cpu": 1024,
          "memory": 2048,
          "essential": true,
          "networkMode": "awsvpc",
          "portMappings": [
            {
            "containerPort": 3000,
            "hostPort":  3000
            }
          ]
        }
      ]
    TASK_DEFINITION
  
}

resource "aws_ecs_service" "ecss" {
    name = "hello-world"
    cluster = aws_ecs_cluster.ecs.id
    task_definition = aws_ecs_task_definition.ecsd.arn
    desired_count = 1
    launch_type = "FARGATE"

    network_configuration {
      subnets = [aws_subnet.mysubnet1.id , aws_subnet.mysubnet2.id]
      security_groups = [aws_security_group.sg.id]

    }
    load_balancer {
      target_group_arn = aws_lb_target_group.tg.arn
      container_name = "hello-world"
      container_port = 3000
    }
  
}

resource "aws_lb" "mylb" {
  name = "my-lb"
  internal = false 
  load_balancer_type = "application"
  security_groups = [aws_security_group.sg.id]
  subnets = [aws_subnet.mysubnet1.id , aws_subnet.mysubnet2.id]
}
resource "aws_lb_target_group" "tg" {
  name = "tg"
  port = 3000
  protocol = "HTTP"
  vpc_id = aws_vpc.myvpc.id
  target_type = "ip"
  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_alb_listener" "lab" {
  load_balancer_arn = aws_lb.mylb.arn
  port = 3000
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

