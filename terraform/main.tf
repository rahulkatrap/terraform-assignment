
provider "aws" {
  region = "ap-south-1"
}
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_subnet" "mysubnet" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.0.0/24"
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
    network_mode = "wasvpc"
    cpu = 1024
    memory = 2048
    container_definitions = jsonencode([{
        name = "hello-world"
        image = "312356219605.dkr.ecr.ap-south-1.amazonaws.com/my-repo:latest"
        portMappings=[{
            containerPort = 3000
            hostPort = 3000

        }]
    }])
  
}
resource "aws_ecs_service" "ecss" {
    name = "hello-world-service"
    cluster = aws_ecs_cluster.ecs.id
    task_definition = aws_ecs_task_definition.ecsd.arn
    desired_count = 1
    launch_type = "FARGATE"

    network_configuration {
      subnets = [aws_subnet.mysubnet.id]
      security_groups = [aws_security_group.sg.id]

    }
  
}
resource "aws_lb" "mylb" {
  name = "my-lb"
  internal = false 
  load_balancer_type = "application"
  security_groups = [aws_security_group.sg.id]
  subnets = [aws_subnet.mysubnet.id]
}
resource "aws_lb_target_group" "tg" {
  name = "tg"
  port = 3000
  protocol = "HTTP"
  vpc_id = aws_vpc.myvpc.id
  health_check {
    path = "/"
    port = "traffic-port"
  }
}
resource "aws_lb_target_group_attachment" "lba" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_ecs_service.ecss.id
  port = 3000

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
