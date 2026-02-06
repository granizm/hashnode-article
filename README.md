# Hashnode Article Publisher

Automated publishing pipeline for Hashnode articles using GitHub Actions.

## Features

- **Draft Mode**: Automatically creates drafts when PRs are opened
- **Publish Mode**: Publishes articles when changes are merged to main
- **Update Support**: Updates existing posts when content changes
- **Discord Notifications**: Get notified on success/failure

## Setup

### 1. Get Hashnode API Token

1. Go to [Hashnode Settings](https://hashnode.com/settings/developer)
2. Generate a new Personal Access Token
3. Copy the token

### 2. Get Publication ID

1. Go to your Hashnode blog dashboard
2. Navigate to **Settings** > **General**
3. Find your Publication ID in the URL or settings

Alternatively, use the GraphQL API:

```graphql
query {
  me {
    publications(first: 10) {
      edges {
        node {
          id
          title
        }
      }
    }
  }
}
```

### 3. Configure GitHub Secrets

Add the following secrets in your repository settings (**Settings** > **Secrets and variables** > **Actions**):

| Secret | Description |
|--------|-------------|
| `HASHNODE_TOKEN` | Your Hashnode Personal Access Token |
| `HASHNODE_PUBLICATION_ID` | Your Hashnode Publication ID |
| `DISCORD_WEBHOOK_URL` | (Optional) Discord webhook for notifications |

### 4. Discord Webhook (Optional)

1. In your Discord server, go to **Server Settings** > **Integrations** > **Webhooks**
2. Create a new webhook and copy the URL
3. Add it as `DISCORD_WEBHOOK_URL` secret

## Usage

### Article Format

Create markdown files in the `posts/` directory with frontmatter:

```markdown
---
title: "Your Article Title"
subtitle: "Optional subtitle"
tags: "javascript, web development, tutorial"
cover_image: "https://example.com/image.jpg"
slug: "your-article-slug"
canonical_url: "https://yourblog.com/original-post"
---

Your article content here...
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `title` | Yes | Article title |
| `subtitle` | No | Article subtitle |
| `tags` | No | Comma-separated tags |
| `cover_image` | No | URL to cover image |
| `slug` | No | Custom URL slug |
| `canonical_url` | No | Original article URL (for cross-posting) |

### Workflow

1. Create a new branch
2. Add/edit markdown files in `posts/`
3. Open a Pull Request - drafts are created automatically
4. Merge to main - articles are published

### Manual Publishing

You can also run the publish script locally:

```bash
# Set environment variables
export HASHNODE_TOKEN="your-token"
export HASHNODE_PUBLICATION_ID="your-publication-id"
export DISCORD_WEBHOOK_URL="your-webhook-url"  # Optional

# Create draft
./scripts/publish.sh draft posts/my-article.md

# Publish
./scripts/publish.sh publish posts/my-article.md
```

## File Structure

```
hashnode-article/
├── .github/
│   └── workflows/
│       ├── publish-draft.yml      # PR trigger -> create draft
│       └── publish-production.yml # Push to main -> publish
├── posts/
│   └── .gitkeep
├── scripts/
│   └── publish.sh                 # Main publishing script
├── .gitignore
└── README.md
```

## Article ID Tracking

The `hashnode_article_ids.json` file stores mappings between local files and Hashnode IDs:

```json
{
  "my-article": {
    "draftId": "draft-id-here",
    "postId": "post-id-here"
  }
}
```

This enables:
- Updating existing drafts instead of creating duplicates
- Updating published posts when content changes

## Troubleshooting

### Draft not created

- Check that `HASHNODE_TOKEN` and `HASHNODE_PUBLICATION_ID` are set correctly
- Verify the markdown file has valid frontmatter
- Check the workflow logs for error messages

### Article not updating

- Ensure the `hashnode_article_ids.json` artifact is preserved between runs
- Check if the article key matches the filename

### Discord notifications not working

- Verify the webhook URL is correct
- Check if the webhook is still active in Discord

## License

MIT
