---
title: "Getting Started with OpenClaw (Clawdbot AI) | 3 Easy Steps in 10 Minutes"
subtitle: "Deploy OpenClaw on AWS without purchasing expensive hardware"
tags: aws, cloudformation, ai, devops
cover_image: null
canonical_url: null
published: false
---

## What This Article Solves

A guide for those who want to run OpenClaw (formerly Clawdbot AI) in the cloud without purchasing an expensive Mac mini.

## Benefits of Cloud Deployment

- No Mac mini required
- Access from anywhere
- 24/7 availability
- Security isolation

## Setup Steps (3 Steps)

### Step 1: Deploy to AWS (~5 minutes)

Create a CloudFormation stack using the template. Resource creation completes in about 1-3 minutes.

### Step 2: Configuration

1. Connect to the EC2 instance
2. Run the command `openclaw_setup`
3. Select LLM model (using OpenRouter as an example)
4. Choose `gpt-oss-120b:free`

### Step 3: Start Using

Access the obtained URL and start chatting with OpenClaw.

## Cost Estimate

| Usage Pattern | Cost |
|--------------|------|
| 1 day (8 hours) | ~$0.07 |
| 1 month | ~$2 |

> **Note:** This article is for testing purposes. Production use requires additional security measures. LLM usage fees are charged separately.

## Reference

- [Original Article (note)](https://note.com/granizm/n/n83515660ed41)
