#!/bin/bash
# Install Gitea server in Docker
#

# Install docker and directly start & enable the service in the VM.
sudo yum update -y
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker

# Create specific directory for gitea installation.
mkdir /home/ec2-user/gitea

# Download and configure docker-compose binary file.
sudo curl -L https://github.com/docker/compose/releases/download/v2.6.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Create docker compose file.
cat << 'EOF' > /home/ec2-user/gitea/docker-compose.yml
version: "3"

networks:
  gitea:
    external: false

services:
  server:
    image: gitea/gitea:1.16.8
    container_name: gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: always
    networks:
      - gitea
    volumes:
      - /home/ec2-user/gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3000:3000"
      - "222:22"
EOF

# Deploy gitea server in docker using docker compose.
sudo docker-compose -f /home/ec2-user/gitea/docker-compose.yml up -d