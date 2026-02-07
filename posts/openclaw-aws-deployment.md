---
title: "Deploying OpenClaw AI Agent on AWS with Amazon Bedrock: A Complete Infrastructure Guide"
subtitle: "Run AI agents in the cloud using AWS-native services - no API key management required"
tags: aws, bedrock, cloudformation, ai, devops
cover_image: null
canonical_url: null
published: false
---

## Introduction

Running AI agents locally often requires dedicated hardware like a Mac mini, constant power consumption, and complex API key management for multiple LLM providers. This guide demonstrates how to deploy OpenClaw (formerly Clawdbot AI) on AWS using **Amazon Bedrock**, eliminating these barriers while providing enterprise-grade security.

This article is based on the official AWS sample repository: [aws-samples/sample-OpenClaw-on-AWS-with-Bedrock](https://github.com/aws-samples/sample-OpenClaw-on-AWS-with-Bedrock).

## Why Amazon Bedrock?

The traditional approach to running OpenClaw requires managing API keys from external LLM providers like OpenRouter. The AWS Bedrock solution offers significant advantages:

| Aspect | Traditional Setup | Bedrock Setup |
|--------|-------------------|---------------|
| Authentication | Multiple API keys | IAM role-based |
| Security | Depends on provider | VPC Endpoints, CloudTrail |
| Model Options | Provider-specific | 8 models (Nova, Claude, Llama, etc.) |
| Key Management | Manual rotation | Automatic with IAM |

## Architecture Overview

The deployment creates a complete infrastructure using CloudFormation:

```
User → WhatsApp/Telegram/Discord → EC2 (OpenClaw Gateway) → Amazon Bedrock
                                           ↓
                                    VPC Endpoints (Private Access)
                                           ↓
                                    CloudTrail (Audit Logging)
```

### Provisioned Resources

| Service | Purpose |
|---------|---------|
| EC2 (t4g.medium) | OpenClaw execution environment (Graviton ARM) |
| Amazon Bedrock | Foundation model API |
| IAM Role | Bedrock authentication with least-privilege access |
| VPC Endpoints | Private network communication to Bedrock |
| CloudTrail | API call auditing |
| SSM Session Manager | Secure access without SSH exposure |

## Prerequisites

Before deploying, ensure you have:

1. **AWS Account** with administrative or appropriate IAM permissions
2. **Bedrock Model Access** enabled in your AWS Console (navigate to Bedrock → Model access)
3. **EC2 Key Pair** created (optional if using SSM Session Manager exclusively)
4. **AWS CLI** configured locally for SSM access

## Deployment Steps

### Step 1: One-Click CloudFormation Deployment

Navigate to the [official repository](https://github.com/aws-samples/sample-OpenClaw-on-AWS-with-Bedrock) and click the "Launch Stack" button.

**Deployment time: approximately 8 minutes**

For CLI-based deployment:

```bash
aws cloudformation create-stack \
  --stack-name openclaw-bedrock-production \
  --template-url https://[S3-BUCKET]/template.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters \
    ParameterKey=InstanceType,ParameterValue=t4g.medium \
    ParameterKey=KeyName,ParameterValue=your-keypair
```

Monitor deployment progress:

```bash
aws cloudformation describe-stacks \
  --stack-name openclaw-bedrock-production \
  --query 'Stacks[0].StackStatus'
```

### Step 2: Retrieve Access Credentials

After stack creation completes, retrieve the outputs:

```bash
# Get access URL and token
aws cloudformation describe-stacks \
  --stack-name openclaw-bedrock-production \
  --query 'Stacks[0].Outputs' \
  --output table
```

Key outputs include:
- **Access URL** - The endpoint for OpenClaw UI
- **Authentication Token** - Required for initial access

### Step 3: Connect via SSM Session Manager

SSM Session Manager provides secure access without exposing SSH ports:

```bash
# Get instance ID
INSTANCE_ID=$(aws cloudformation describe-stacks \
  --stack-name openclaw-bedrock-production \
  --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
  --output text)

# Start port forwarding session
aws ssm start-session \
  --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["18789"],"localPortNumber":["18789"]}'
```

Access the UI at `http://localhost:18789`.

## Available AI Models

Amazon Bedrock provides access to multiple foundation models:

| Model | Input Cost (per 1M tokens) | Output Cost (per 1M tokens) | Notes |
|-------|---------------------------|----------------------------|-------|
| Nova 2 Lite | $0.30 | $2.50 | Recommended for cost optimization |
| Nova Pro | $0.80 | $3.20 | Balanced performance |
| Claude Sonnet | $3.00 | $15.00 | Advanced reasoning |
| DeepSeek | Varies | Varies | Specialized tasks |
| Llama | Varies | Varies | Open-source foundation |

Total: **8 models** available through a single integration.

## Cost Analysis

> **Important Correction:** Initial estimates of ~$2/month were inaccurate. The actual infrastructure costs are significantly higher due to VPC Endpoints and other resources.

### Infrastructure Costs (Monthly, 24/7 Operation)

| Component | Monthly Cost (USD) |
|-----------|-------------------|
| EC2 (t4g.medium, On-Demand) | $24.19 |
| EBS (gp3, 30GB) | $2.40 |
| VPC Endpoints (3 endpoints) | $21.60 |
| Data Transfer | $5-10 |
| **Subtotal** | **$53-58** |

### Bedrock Usage Costs

Model costs are based on token consumption. For light usage (e.g., personal assistant):

**Estimated Total Monthly Cost: $58-66**

### Instance Type Options

#### Linux (Recommended)

| Instance Type | vCPU | RAM | Monthly Cost |
|--------------|------|-----|-------------|
| t4g.small | 2 | 2GB | $12 |
| t4g.medium (default) | 2 | 4GB | $24 |
| t4g.large | 2 | 8GB | $48 |
| c7g.xlarge | 4 | 8GB | $108 |

#### macOS (For iOS/macOS Development)

| Instance Type | Chip | RAM | Monthly Cost |
|--------------|------|-----|-------------|
| mac2.metal | M1 | 16GB | $468 |
| mac2-m2.metal | M2 | 24GB | $632 |

## Supported Messaging Platforms

OpenClaw integrates with multiple messaging services:

- **WhatsApp** (recommended for mobile access)
- **Telegram**
- **Discord**
- **Slack**
- **Microsoft Teams**

## Security Architecture

The solution implements multiple security layers:

### Network Security
- **VPC Endpoints** provide private connectivity to Bedrock (no internet exposure)
- **Security Groups** restrict ingress to necessary ports only
- **SSM Session Manager** eliminates SSH exposure

### Identity and Access Management
- **IAM Roles** with least-privilege Bedrock access
- **No hardcoded credentials** - uses instance profile

### Audit and Compliance
- **CloudTrail** logs all Bedrock API calls
- **VPC Flow Logs** available for network traffic analysis

## Infrastructure Optimization

### Cost Reduction Strategies

1. **Stop instances when not in use** - EC2 charges stop, but note that VPC Endpoints continue billing
2. **Use smaller instances** - t4g.small ($12/month) works for light usage
3. **Choose cost-effective models** - Nova 2 Lite offers the lowest per-token pricing
4. **Consider Reserved Instances** - Save up to 72% with 1-year commitment

### Removing VPC Endpoints (Trade-off)

If your security requirements allow public Bedrock access:

- Remove VPC Endpoints to save ~$22/month
- Trade-off: API calls traverse public internet instead of private network

## Troubleshooting

### Stack Creation Failures

- **IAM Permission Errors**: Ensure deploying user has `cloudformation:*`, `ec2:*`, `iam:*` permissions
- **Missing CAPABILITY_IAM**: Add `--capabilities CAPABILITY_IAM` to CLI commands
- **Bedrock Not Enabled**: Navigate to Bedrock → Model access and enable required models

### Connectivity Issues

- **SSM Session Manager fails**: Verify instance has SSM agent and proper IAM role
- **Cannot reach Bedrock**: Confirm VPC Endpoint configuration and security group rules

### Model Access Errors

- **Model not available**: Check Bedrock model access in console
- **Region mismatch**: Ensure deployment region supports Bedrock (us-east-1, us-west-2, etc.)

## Conclusion

Deploying OpenClaw on AWS with Amazon Bedrock provides a production-ready AI agent environment with:

- **Simplified Authentication**: IAM-based access eliminates API key management
- **Enterprise Security**: VPC Endpoints, CloudTrail, and IAM roles
- **Flexibility**: 8 AI models through a single integration
- **Scalability**: CloudFormation enables consistent deployments

Key considerations:
- **Cost**: Expect ~$53-58/month minimum for infrastructure
- **Deployment Time**: ~8 minutes with one-click setup
- **Prerequisites**: Bedrock model access must be enabled

## Resources

- [OpenClaw on AWS with Bedrock (Official AWS Sample)](https://github.com/aws-samples/sample-OpenClaw-on-AWS-with-Bedrock)
- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [AWS CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [SSM Session Manager Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
