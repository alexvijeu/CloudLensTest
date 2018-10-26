provider "aws" {
   shared_credentials_file = "D:/SSH/AWS/sandbox-bucharest"
   region = "us-east-2"
}

data "aws_availability_zones" "available" {}

variable "ami_id" {
  default = "ami-0b59bfac6be064b78"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "keyname" {
  description = "The Key Pair used to connect to the instances"
  default = "CloudLens Tool"
}

resource "aws_security_group" "cloudlens_sg"{
  name = "CloudLens"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["193.226.172.43/32"]
  }

  ingress {
    from_port   = 19993
    to_port     = 19993
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "cloudlensclient" {
  name = "CloudLensClient"
  image_id = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  security_groups = ["${aws_security_group.cloudlens_sg.id}"]
  key_name = "${var.keyname}"

  user_data = <<-EOF
              #!/bin/bash
              sudo yum -y install gcc
              sudo yum -y install gcc-c++
              sudo yum -y install python-devel
              sudo yum -y install libpcap-devel
              sudo yum install -y tcpdump
              sudo yum install -y docker
              pip install psutil
              pip install scapy
              pip install --upgrade awscli
              service docker start
              docker run -v /var/log:/var/log/cloudlens -v /:/host -v /var/run/docker.sock:/var/run/docker.sock --privileged --name cloudlens-agent -d --restart=on-failure --net=host ixiacom/cloudlens-sandbox-agent --accept_eula yes --apikey srFNo1eBomXvZmr3QowHlaDdhe5YPwCD1K1qxwE17 --server agrsa-agent.ixia-cloudlens.net --custom_tags role=agg
              cd /home/ec2-user/
              wget https://github.com/appneta/tcpreplay/releases/download/v4.2.5/tcpreplay-4.2.5.tar.gz
              tar zxfv tcpreplay-4.2.5.tar.gz
              cd tcpreplay-4.2.5
              bash configure
              make
              make install
              cd /home/ec2-user/
              wget https://github.com/esnet/iperf/archive/3.1.7.tar.gz
              tar zxvf 3.1.7.tar.gz
              cd iperf-3.1.7
              bash configure
              make
              make install
              cd /home/ec2-user/
              aws s3api get-object --bucket accountglobal-cloudlens-test-resources --key tools/pcap_diff.py pcap_diff.py
              aws s3api get-object --bucket accountglobal-cloudlens-test-resources --key task_controller/vic01/task_ctrl.tar task_ctrl.tar
              tar -xvf task_ctrl.tar
              chown -R ec2-user:root tmp/
              ldconfig
              rm -rf tcpreplay-4.2.5*
              rm task_ctrl.tar
              rm 3.1.7.tar.gz
              rm -rf iperf-3.1.7
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "cloudlenstool" {
  name = "CloudLensTool"
  image_id = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  security_groups = ["${aws_security_group.cloudlens_sg.id}"]
  key_name = "${var.keyname}"

  user_data = <<-EOF
              #!/bin/bash
              yum update
              yum install -y docker
              service docker start
              docker run -v /var/log:/var/log/cloudlens -v /:/host -v /var/run/docker.sock:/var/run/docker.sock --privileged --name cloudlens-agent -d --restart=on-failure --net=host ixiacom/cloudlens-sandbox-agent --accept_eula yes --apikey srFNo1eBomXvZmr3QowHlaDdhe5YPwCD1K1qxwE17
              yum install -y tcpdump
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg_client" {
  name = "ASG_CloudLensClient"
  launch_configuration = "${aws_launch_configuration.cloudlensclient.id}"
  availability_zones = ["${data.aws_availability_zones.available.names}"]

  min_size = 1
  max_size = 1

  tag {
    key                 = "Name"
    value               = "ASG_CloudLensClient"
    propagate_at_launch = true
  }

  tag {
    key                 = "CloudLens"
    value               = "Client"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "asg_tool" {
  name = "ASG_CloudLensTool"
  launch_configuration = "${aws_launch_configuration.cloudlenstool.id}"
  availability_zones = ["${data.aws_availability_zones.available.names}"]

  min_size = 1
  max_size = 1

  tag {
    key                 = "Name"
    value               = "ASG_CloudLensTool"
    propagate_at_launch = true
  }

  tag {
    key                 = "CloudLens"
    value               = "Tool"
    propagate_at_launch = true
  }
}