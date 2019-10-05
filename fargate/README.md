# fargate terraform module

A minimal container job using fargate. 

- uses SSM parameters for configuration
- uses alpine container from docker hub and just runs "env" to print environment vars
- sends logs to CloudWatch, result of "env" will show in "fargate-test" log group
- no service defined
- task definition created by module but not executed... use run-task command e.g.
  
  ```
  aws ecs run-task \
    --task-definition test-task \
    --cluster test-cluster \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[<SUBNET>],securityGroups=[<GROUP>]}"
  ```
  
