data "aws_availability_zones" "azs" {
  state = "available"
}

resource "aws_vpc" "my_vpc" {
  cidr_block       = var.cidr
  instance_tenancy = "default"

  tags = {
    Name = "my_vpc"
  }
}

resource "aws_subnet" "pubsub" {
  count                   = 2
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.azs.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "pubsub-${count.index + 1}"
  }
}

resource "aws_subnet" "prisub" {
  count                   = 2
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, 2 + count.index)
  availability_zone       = data.aws_availability_zones.azs.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "prisub-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "igw"
  }
}

resource "aws_route" "net_access" {
  route_table_id         = aws_vpc.my_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
/*
resource "aws_eip" "eip" {
  count = 2
  domain   = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  count = 2
  allocation_id = element(aws_eip.eip.*.id,count.index)
  subnet_id     = element(aws_subnet.pubsub.*.id,count.index)

  tags = {
    Name = "nat-${count.index}"
  }
}

resource "aws_route_table" "prirt" {
  count = 2
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.nat.*.id,count.index)
  }

  tags = {
    Name = "prirt-${count.index}"
  }
}

resource "aws_route_table_association" "priass" {
  count = 2
  subnet_id      = element(aws_subnet.pubsub.*.id,count.index)
  route_table_id = element(aws_route_table.prirt.*.id,count.index)
}
*/
/*
locals {
  inbound_ports = [443]
  outbound_ports = [{
	port = 443,
	cidr_block = var.secgrp_cidr
  	},
	{
	port = 80,
	cidr_block = "0.0.0.0/0"
	}]
}
*/
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  dynamic "ingress" {
    for_each = var.web_ingress
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
  dynamic "egress" {
    for_each = var.web_egress
    content {
      from_port   = egress.value.port
      to_port     = egress.value.port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_s3_bucket" "bucket" {
  bucket = "tf-s3-new-demo-tf"

  tags = {
    Name        = "tf-s3-new-demo-tf"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = "${file("s3policy.json")}"
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.bucket_access,
  ]

  bucket = aws_s3_bucket.bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_public_access_block" "bucket_access" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}



resource "aws_lb" "lb" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_tls.id]
  subnets            = aws_subnet.pubsub.*.id

  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.bucket.id
    prefix  = "test-lb"
    enabled = true
  }

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "targrp" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targrp.arn
  }
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true


  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }


  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


resource "aws_instance" "test" {

  ami                    = data.aws_ami.amazon-linux-2.id
  instance_type          = "t2.micro"
  key_name               = "north_virginia"
  vpc_security_group_ids = ["${aws_security_group.allow_tls.id}"]
  subnet_id              = aws_subnet.pubsub[0].id

  tags = {
    Name = "pub"
  }
}

resource "aws_instance" "test1" {

  ami                    = data.aws_ami.amazon-linux-2.id
  instance_type          = "t2.micro"
  key_name               = "north_virginia"
  vpc_security_group_ids = ["${aws_security_group.allow_tls.id}"]
  subnet_id              = aws_subnet.pubsub[1].id

  tags = {
    Name = "pub2"
  }
}


resource "aws_db_subnet_group" "subgrp" {
  name       = "main"
  subnet_ids = "${aws_subnet.prisub.*.id}"

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "db_ins" {
  allocated_storage    = 10
  db_subnet_group_name = aws_db_subnet_group.subgrp.id
  db_name              = var.db_name
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  username             = var.db_user
  password             = var.db_pass
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  multi_az = false
  availability_zone = "us-east-1a"
  identifier = "terraform-dbb"
}
