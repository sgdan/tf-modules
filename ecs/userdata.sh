#!/bin/bash

set -ex

# Support Session Manager
yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Install Rex-RAY plugin
docker plugin install rexray/ebs REXRAY_PREEMPT=true EBS_REGION=${region} --grant-all-permissions

echo ECS_CLUSTER=${name} >> /etc/ecs/ecs.config
