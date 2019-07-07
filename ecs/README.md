# ecs

An ECS cluster that can be used to run tasks.

- Installs Rex-RAY plugin on the nodes so that tasks can request EBS volumes
- Nodes are only in one AZ so the volumes are always available
- Creates an ALB terminating HTTPS requests and forwarding as HTTP to Traefik
  container which forwards to other services
