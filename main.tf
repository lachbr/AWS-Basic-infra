provider "aws" {
 region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "cts-statebucket"
    key    = "s3://cts-statebucket/YoMama/terraform.tfstate"
    region = "us-east-1"
  }
}

#module "new-AWS-Basic-infra" {
  #source      = "git::https://github.com/monmichael32/new-AWS-Basic-infra.git"
#}

module "default_label" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  attributes  = var.attributes
  delimiter   = var.delimiter
  name        = var.name
  namespace   = var.namespace
  stage       = var.stage
  environment = var.environment
  tags        = var.tags
}

#resource "aws_security_group_rule" "egress" {
 # type              = "egress"
 #from_port         = "0"
  #to_port           = "0"
  #protocol          = "-1"
  #cidr_blocks       = ["0.0.0.0/0"]
  #security_group_id = aws_security_group.default.id
#}

#resource "aws_security_group_rule" "http_ingress" {
  #count             = var.http_enabled ? 1 : 0
  #type              = "ingress"
  #from_port         = var.http_port
  #to_port           = var.http_port
  #protocol          = "tcp"
  #cidr_blocks       = var.http_ingress_cidr_blocks
  #prefix_list_ids   = var.http_ingress_prefix_list_ids
  #security_group_id = aws_security_group.default.id
#}

#resource "aws_security_group_rule" "https_ingress" {
  #count             = var.https_enabled ? 1 : 0
  #type              = "ingress"
  #from_port         = var.https_port
  #to_port           = var.https_port
  #protocol          = "tcp"
  #cidr_blocks       = var.https_ingress_cidr_blocks
  #prefix_list_ids   = var.https_ingress_prefix_list_ids
  #security_group_id = aws_security_group.default.id
#}


resource "aws_lb" "default" {
  name               = module.default_label.id
  tags               = module.default_label.tags
  internal           = var.internal
  load_balancer_type = "application"

  #security_groups = [aws_security_group.web_rules.sg-08343d046fcafb32e]
  security_groups = ["sg-0c0ea473548739c09"]

  #security_groups = compact(
    #concat(var.security_group_ids, [aws_security_group.default.id]),
 #)

  #subnets                          = [aws_subnet.subnet_public_a.id,aws_subnet.subnet_public_b.id] #var.subnet_ids
  subnets                          = ["subnet-09c1dddc913c0343d","subnet-0a995e300bffcc391"] #var.subnet_ids
  enable_http2                     = var.http2_enabled
  idle_timeout                     = var.idle_timeout
  ip_address_type                  = var.ip_address_type
  enable_deletion_protection       = var.deletion_protection_enabled

}

module "default_target_group_label" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  attributes  = concat(var.attributes, ["default"])
  delimiter   = var.delimiter
  name        = var.name
  namespace   = var.namespace
  stage       = var.stage
  environment = var.environment
  tags        = var.tags
}

resource "aws_lb_target_group" "default" {
  name                 = var.target_group_name == "" ? module.default_target_group_label.id : var.target_group_name
  port                 = var.target_group_port
  protocol             = var.target_group_protocol
  vpc_id               = "vpc-0efd49d241b4528a6"
  target_type          = var.target_group_target_type
  deregistration_delay = var.deregistration_delay

  health_check {
    protocol            = var.target_group_protocol
    path                = var.health_check_path
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
  }

  dynamic "stickiness" {
    for_each = var.stickiness == null ? [] : [var.stickiness]
    content {
      type            = "lb_cookie"
      cookie_duration = stickiness.value.cookie_duration
      enabled         = var.target_group_protocol == "TCP" ? false : stickiness.value.enabled
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    module.default_target_group_label.tags,
    var.target_group_additional_tags
  )
}

resource "aws_lb_target_group" "pennypinchers" {
  name                 = "pennypinchers"
  port                 = var.db_target_group_port 
  protocol             = var.target_group_protocol
  vpc_id               = "vpc-0efd49d241b4528a6"
  target_type          = var.target_group_target_type
  deregistration_delay = var.deregistration_delay
  
  health_check {
    protocol            = var.target_group_protocol
    path                = var.health_check_path
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
  } 

  dynamic "stickiness" {
    for_each = var.stickiness == null ? [] : [var.stickiness]
    content {
      type            = "lb_cookie"
      cookie_duration = stickiness.value.cookie_duration
      enabled         = var.target_group_protocol == "TCP" ? false : stickiness.value.enabled
    } 
  } 
  
  lifecycle {
    create_before_destroy = true
  } 
  
  tags = merge(
    module.default_target_group_label.tags,
    var.target_group_additional_tags
  ) 
} 

resource "aws_lb_listener" "db_forward" {
  count             = var.http_enabled && var.http_redirect != true ? 1 : 0
  load_balancer_arn = aws_lb.default.arn
  port              = 27017
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.pennypinchers.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "web-1" {
  target_group_arn = aws_lb_target_group.default.arn
  target_id = aws_instance.web-1.private_ip
  port = 80
}

resource "aws_lb_target_group_attachment" "web-2" {
  target_group_arn = aws_lb_target_group.default.arn
  target_id = aws_instance.web-2.private_ip
  port = 80
}

resource "aws_lb_listener" "http_forward" {
  count             = var.http_enabled && var.http_redirect != true ? 1 : 0
  load_balancer_arn = aws_lb.default.arn
  port              = var.http_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.default.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "http_redirect" {
  count             = var.http_enabled && var.http_redirect == true ? 1 : 0
  load_balancer_arn = aws_lb.default.arn
  port              = var.http_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.default.arn
    type             = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = var.https_enabled ? 1 : 0
  load_balancer_arn = aws_lb.default.arn

  port            = var.https_port
  protocol        = "HTTPS"
  ssl_policy      = var.https_ssl_policy
  certificate_arn = var.certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.default.arn
    type             = "forward"
  }
}


resource "aws_instance" "web-2" {
  ami      = "ami-0a7f1556c36aaf776"
  instance_type = "t2.micro"
  #vpc_security_group_ids = [aws_security_group.web_rules.id,aws_security_group.ssh_rules.id]
  vpc_security_group_ids = ["sg-0c0ea473548739c09","sg-09a35bc544d2d1d8a"]
  key_name = "deployer-key"
  #depends_on=[aws_internet_gateway.igw]
  #depends_on=[igw-0af98f4b272665cd4]
  subnet_id="subnet-09c1dddc913c0343d"
 }


resource "aws_instance" "web-1" {
 ami      = "ami-0a7f1556c36aaf776"
 instance_type = "t2.micro"
 #vpc_security_group_ids = [aws_security_group.ssh_rules.id,aws_security_group.web_rules.id] 
  vpc_security_group_ids = ["sg-0c0ea473548739c09","sg-09a35bc544d2d1d8a"]
  key_name = "deployer-key"
  #depends_on=[aws_internet_gateway.igw]
  #depends_on="igw-0a8b26222d5ca77e9"
  subnet_id="subnet-0a995e300bffcc391"
}

#resource "aws_s3_bucket" "cts-statebucket" {
    #bucket = "cts-statebucket"
    #acl    = "public-read"
#}

