---
title: "Deploying OpenClaw AI Agent on AWS: A Complete Infrastructure Guide"
subtitle: "Run AI agents in the cloud with CloudFormation - no dedicated hardware required"
tags: aws, cloudformation, ai, devops, infrastructure
cover_image: null
canonical_url: null
published: false
---

## Introduction

Running AI agents locally often requires dedicated hardware like a Mac mini, constant power consumption, and raises security concerns about running experimental software on personal machines. This guide demonstrates how to deploy OpenClaw (formerly Clawdbot AI) on AWS, eliminating these barriers while maintaining cost-effectiveness.

We'll use Infrastructure as Code (IaC) with CloudFormation to ensure reproducible, auditable deployments.

## Architecture Overview

The deployment architecture consists of:

```
User → CloudFront/ALB → EC2 Instance → LLM Provider (OpenRouter)
```

CloudFormation provisions the following resources:

- **Compute**: EC2 instance (t3.micro for cost optimization)
- **Networking**: VPC, Subnet, Security Groups
- **Security**: IAM roles with least-privilege access
- **Storage**: EBS volume for persistence

## Prerequisites

- AWS account with administrative access
- AWS CLI configured locally
- LLM provider API key (OpenRouter recommended for free tier access)
- Basic familiarity with CloudFormation

## Deployment Steps

### Step 1: Deploy the CloudFormation Stack

Create the infrastructure with a single command:

```bash
aws cloudformation create-stack \
  --stack-name openclaw-production \
  --template-body file://openclaw-template.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters \
    ParameterKey=InstanceType,ParameterValue=t3.micro \
    ParameterKey=KeyName,ParameterValue=your-keypair
```

The stack creation takes approximately 5 minutes. Monitor progress:

```bash
aws cloudformation describe-stacks \
  --stack-name openclaw-production \
  --query 'Stacks[0].StackStatus'
```

### Step 2: Configure the Agent

SSH into the provisioned instance and configure OpenClaw:

```bash
# Get instance IP from CloudFormation outputs
INSTANCE_IP=$(aws cloudformation describe-stacks \
  --stack-name openclaw-production \
  --query 'Stacks[0].Outputs[?OutputKey==`InstanceIP`].OutputValue' \
  --output text)

ssh -i your-key.pem ec2-user@$INSTANCE_IP
```

Configure the following:

| Setting | Recommended Value |
|---------|-------------------|
| Operation Mode | Local |
| LLM Provider | OpenRouter |
| Model | gpt-oss-120b:free |

### Step 3: Access the Agent

Once configured, access the agent via the output URL:

```bash
aws cloudformation describe-stacks \
  --stack-name openclaw-production \
  --query 'Stacks[0].Outputs[?OutputKey==`AgentURL`].OutputValue' \
  --output text
```

## Cost Analysis

### EC2 Costs

| Usage Pattern | Monthly Cost (USD) |
|--------------|-------------------|
| 8 hours/day | ~$2 |
| 24/7 | ~$6 |
| Spot Instance (24/7) | ~$0.60 |

### LLM Costs

Using OpenRouter's free tier eliminates additional LLM costs. For production workloads, budget based on token consumption.

## Infrastructure Optimization

### Cost Reduction with Spot Instances

Modify the CloudFormation template to use Spot Instances:

```yaml
SpotFleetRequestConfigData:
  IamFleetRole: !GetAtt SpotFleetRole.Arn
  TargetCapacity: 1
  LaunchSpecifications:
    - InstanceType: t3.micro
      SpotPrice: "0.005"
```

### Scheduled Scaling

Implement time-based scaling to reduce costs during off-hours:

```yaml
ScheduledScaleDown:
  Type: AWS::AutoScaling::ScheduledAction
  Properties:
    AutoScalingGroupName: !Ref AutoScalingGroup
    DesiredCapacity: 0
    Recurrence: "0 22 * * *"  # 10 PM UTC

ScheduledScaleUp:
  Type: AWS::AutoScaling::ScheduledAction
  Properties:
    AutoScalingGroupName: !Ref AutoScalingGroup
    DesiredCapacity: 1
    Recurrence: "0 8 * * *"   # 8 AM UTC
```

## Security Best Practices

### Network Security

- Restrict Security Group ingress to known IP ranges
- Use VPC endpoints for AWS service access
- Deploy in private subnet with NAT Gateway for outbound access

### Secrets Management

Store API keys in AWS Secrets Manager:

```yaml
OpenClawApiSecret:
  Type: AWS::SecretsManager::Secret
  Properties:
    Name: openclaw/api-keys
    SecretString: !Sub |
      {
        "OPENROUTER_API_KEY": "${OpenRouterApiKey}"
      }
```

### IAM Best Practices

Apply least-privilege principles to the instance role:

```yaml
InstanceRole:
  Type: AWS::IAM::Role
  Properties:
    AssumeRolePolicyDocument:
      Statement:
        - Effect: Allow
          Principal:
            Service: ec2.amazonaws.com
          Action: sts:AssumeRole
    Policies:
      - PolicyName: SecretsAccess
        PolicyDocument:
          Statement:
            - Effect: Allow
              Action:
                - secretsmanager:GetSecretValue
              Resource: !Ref OpenClawApiSecret
```

## Monitoring and Observability

Implement CloudWatch monitoring for operational visibility:

```yaml
CPUAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: OpenClaw-High-CPU
    MetricName: CPUUtilization
    Namespace: AWS/EC2
    Statistic: Average
    Period: 300
    EvaluationPeriods: 2
    Threshold: 80
    AlarmActions:
      - !Ref AlertTopic
```

## Troubleshooting

### Stack Creation Failures

- Verify IAM permissions include `cloudformation:*` and `ec2:*`
- Ensure `CAPABILITY_IAM` flag is included
- Check CloudFormation events for specific error messages

### Connectivity Issues

- Verify Security Group rules for ports 22 (SSH) and 80/443 (HTTP/S)
- Confirm instance is in `running` state
- Check VPC route table configuration

## Conclusion

Deploying OpenClaw on AWS provides a cost-effective, secure, and scalable approach to running AI agents. The CloudFormation-based deployment ensures infrastructure reproducibility and enables integration with CI/CD pipelines for automated updates.

Key benefits:

- **Cost-effective**: ~$2/month for moderate usage
- **Scalable**: Easily adjust instance types based on workload
- **Secure**: Isolated environment with proper IAM controls
- **Reproducible**: IaC approach for consistent deployments

## Resources

- [OpenClaw GitHub Repository](https://github.com/openclaw)
- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [OpenRouter API](https://openrouter.ai/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
