# ecs-mysql

Deploys a MySQL database container to an ECS cluster. An EBS data volume
is requested for persistent data so that if the task switches to another
node it will retain the database state.
