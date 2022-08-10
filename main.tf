provider "aws" {
  region = var.region
  profile = "terraform"
}

// using default VPC for buld.
resource "aws_default_vpc" "default" {}

// Selecting two subnets
resource "aws_default_subnet" "default_az1" {
  availability_zone = "us-east-1a"

  tags = {
    "Name" : "prod_subnet"
  }
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = "us-east-1b"

  tags = {
    "Name" : "prod_subnet"
  }
}

// creating security prod_web and open port 80 and 443
resource "aws_security_group" "prod_web" {
  name        = "drupal_web"
  description = "Allow http and https ports inbound and everything outbound"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name : "production-web"
  }
}

resource "aws_security_group" "prod_db" {
  name        = "prod_db"
  description = "Allow DB port inbound and from EC2"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.prod_web.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name : "production-DB"
  }
}

resource "aws_iam_role_policy" "test_policy" {
  name = "test_policy"
  role = aws_iam_role.test_role.id

  
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowRDSDescribe",
        "Effect" : "Allow",
        "Action" : "rds:Describe*",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role" "test_role" {
  name = "test_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = aws_iam_role.test_role.name
}

#Creating Mysql DB enabeling Multi Availability zones
#resource "aws_rds_cluster" "prod-db" {
#  cluster_identifier      = "aurora-cluster-prod"
#  engine                  = "aurora-mysql"
#  engine_version          = "5.7.mysql_aurora.2.03.2"
#  availability_zones      = [ "us-east-1a","us-east-1b" ]
#  database_name           = "mydbprod"
#  master_username         = "admin"
# master_password         = "Admin1234"
#  backup_retention_period = 5
#  preferred_backup_window = "07:00-09:00"
#  vpc_security_group_ids = [ aws_security_group.prod_db.id ]
#}

resource "aws_db_instance" "drupal-db" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "8.0.23"
  instance_class       = "db.t2.micro"
  name                 = "db"
  username             = "admin"
  password             = "Admin1234"
  security_group_names =   [aws_security_group.prod.db]
  skip_final_snapshot  = true
}


# Creating ELB
resource "aws_elb" "prod_web_elb" {
  name            = "prod-web-elb"
  subnets         = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
  security_groups = [aws_security_group.prod_web.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  tags = {
    Name : "production_ELB"
  }
}
resource "aws_launch_template" "prod_web_template" {
  name_prefix            = "prod-web-template"
  image_id               = "ami-0dd3393c69c9751fd"
  vpc_security_group_ids = [aws_security_group.prod_web.id]
  key_name               = "drupal"
  user_data              = filebase64("/files/data.sh")
  iam_instance_profile {
    arn = aws_iam_instance_profile.test_profile.arn
  }

  instance_type = "t2.micro"

 depends_on = [ aws_db_instance.drupal-db ]


  tags = {
    Name : "production"
  }
}



resource "aws_autoscaling_group" "prod_group" {
  vpc_zone_identifier = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1

  launch_template {
    id      = aws_launch_template.prod_web_template.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_attachment" "prod_web" {
  autoscaling_group_name = aws_autoscaling_group.prod_group.id
  elb                    = aws_elb.prod_web_elb.id
}

