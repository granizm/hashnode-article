---
title: "Building an Automated Blog Publishing System with GitHub Actions"
subtitle: "How I streamlined my multi-platform publishing workflow"
tags: github, automation, blogging, devops
slug: automated-blog-publishing-github-actions
---

## Introduction

When publishing articles to multiple blog platforms, logging into each site and copy-pasting content is tedious and time-consuming.

In this article, I'll share how I built a system to automatically publish articles to multiple blog platforms using GitHub Actions.

## System Overview

### Supported Platforms

- **Zenn**: Direct markdown sync via GitHub integration
- **Qiita**: Using Qiita CLI
- **DEV.to**: Using Forem API
- **Hashnode**: Using GraphQL API
- **note**: Using unofficial REST API

### Workflow

1. Write articles in the `granizm-blog` repository
2. Create a PR → Post as draft to each platform
3. Merge PR → Publish articles on all platforms

## Technical Details

### GitHub Actions Configuration

```yaml
name: Publish Draft
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Publish to Platform
        run: ./scripts/publish.sh draft
```

### Security

API keys for each platform are managed via GitHub Secrets.

## Conclusion

With this system, I can now publish articles to multiple platforms with a single workflow.

---

*This is a test post.*
# テスト更新 Fri Feb  6 07:48:21 UTC 2026


# PR Draft Workflow Test 2026-02-06 08:10:37 UTC
