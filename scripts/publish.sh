#!/bin/bash

# Hashnode Article Publisher
# Usage: ./publish.sh <draft|publish> <markdown_file>

set -e

MODE="${1:-draft}"
MARKDOWN_FILE="$2"
IDS_FILE="hashnode_article_ids.json"

# Validate environment variables
if [[ -z "$HASHNODE_TOKEN" ]]; then
    echo "Error: HASHNODE_TOKEN is not set"
    exit 1
fi

if [[ -z "$HASHNODE_PUBLICATION_ID" ]]; then
    echo "Error: HASHNODE_PUBLICATION_ID is not set"
    exit 1
fi

if [[ -z "$MARKDOWN_FILE" ]]; then
    echo "Error: Markdown file path is required"
    echo "Usage: $0 <draft|publish> <markdown_file>"
    exit 1
fi

if [[ ! -f "$MARKDOWN_FILE" ]]; then
    echo "Error: File not found: $MARKDOWN_FILE"
    exit 1
fi

# Initialize IDs file if it doesn't exist
if [[ ! -f "$IDS_FILE" ]]; then
    echo "{}" > "$IDS_FILE"
fi

# Extract frontmatter and content
extract_frontmatter() {
    local file="$1"
    local key="$2"

    # Extract value between --- markers
    sed -n '/^---$/,/^---$/p' "$file" | grep "^${key}:" | sed "s/^${key}:[[:space:]]*//" | sed 's/^["'"'"']//' | sed 's/["'"'"']$//'
}

# Get content after frontmatter
get_content() {
    local file="$1"
    # Skip frontmatter (between --- markers) and get the rest
    awk 'BEGIN{found=0} /^---$/{found++; next} found>=2{print}' "$file"
}

# Parse frontmatter
TITLE=$(extract_frontmatter "$MARKDOWN_FILE" "title")
SUBTITLE=$(extract_frontmatter "$MARKDOWN_FILE" "subtitle")
TAGS=$(extract_frontmatter "$MARKDOWN_FILE" "tags")
COVER_IMAGE=$(extract_frontmatter "$MARKDOWN_FILE" "cover_image")
SLUG=$(extract_frontmatter "$MARKDOWN_FILE" "slug")
CANONICAL_URL=$(extract_frontmatter "$MARKDOWN_FILE" "canonical_url")

# Get article content
CONTENT=$(get_content "$MARKDOWN_FILE")

# Generate a unique key for this article based on filename
ARTICLE_KEY=$(basename "$MARKDOWN_FILE" .md)

# Get existing IDs
DRAFT_ID=$(jq -r ".\"${ARTICLE_KEY}\".draftId // empty" "$IDS_FILE" 2>/dev/null || echo "")
POST_ID=$(jq -r ".\"${ARTICLE_KEY}\".postId // empty" "$IDS_FILE" 2>/dev/null || echo "")

# Escape content for JSON
escape_json() {
    python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$1"
}

ESCAPED_CONTENT=$(escape_json "$CONTENT")
ESCAPED_TITLE=$(escape_json "$TITLE")
ESCAPED_SUBTITLE=$(escape_json "$SUBTITLE")

# Build tags array
build_tags_array() {
    local tags_str="$1"
    if [[ -z "$tags_str" ]]; then
        echo "[]"
        return
    fi

    # Convert comma-separated tags to JSON array
    echo "$tags_str" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | \
        jq -R -s 'split("\n") | map(select(length > 0)) | map({slug: (. | gsub(" "; "-") | ascii_downcase), name: .})'
}

TAGS_JSON=$(build_tags_array "$TAGS")

# GraphQL API endpoint
API_URL="https://gql.hashnode.com"

# Function to send Discord notification
send_discord_notification() {
    local status="$1"
    local message="$2"

    if [[ -z "$DISCORD_WEBHOOK_URL" ]]; then
        echo "Discord webhook URL not set, skipping notification"
        return 0
    fi

    local color
    if [[ "$status" == "success" ]]; then
        color=3066993  # Green
    else
        color=15158332  # Red
    fi

    local payload=$(cat <<EOF
{
    "embeds": [{
        "title": "Hashnode Article ${status^}",
        "description": "$message",
        "color": $color,
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }]
}
EOF
)

    curl -s -H "Content-Type: application/json" -d "$payload" "$DISCORD_WEBHOOK_URL" > /dev/null
}

# Create Draft
create_draft() {
    echo "Creating draft for: $TITLE"

    local mutation
    read -r -d '' mutation << 'EOF' || true
mutation CreateDraft($input: CreateDraftInput!) {
    createDraft(input: $input) {
        draft {
            id
            title
            slug
        }
    }
}
EOF

    # Build coverImageOptions only if COVER_IMAGE is set
    local cover_image_options=""
    if [[ -n "$COVER_IMAGE" ]]; then
        cover_image_options="\"coverImageOptions\": {\"coverImageURL\": \"$COVER_IMAGE\"},"
    fi

    # Build slug option only if SLUG is set
    local slug_option=""
    if [[ -n "$SLUG" ]]; then
        slug_option="\"slug\": \"$SLUG\","
    fi

    local variables=$(cat <<EOF
{
    "input": {
        "publicationId": "$HASHNODE_PUBLICATION_ID",
        "title": $ESCAPED_TITLE,
        "contentMarkdown": $ESCAPED_CONTENT,
        "tags": $TAGS_JSON
    }
}
EOF
)

    # Add optional fields using jq
    if [[ -n "$SUBTITLE" ]]; then
        variables=$(echo "$variables" | jq --argjson subtitle "$ESCAPED_SUBTITLE" '.input.subtitle = $subtitle')
    fi
    if [[ -n "$COVER_IMAGE" ]]; then
        variables=$(echo "$variables" | jq --arg url "$COVER_IMAGE" '.input.coverImageOptions = {coverImageURL: $url}')
    fi
    if [[ -n "$SLUG" ]]; then
        variables=$(echo "$variables" | jq --arg slug "$SLUG" '.input.slug = $slug')
    fi

    local response=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $HASHNODE_TOKEN" \
        -d "$(jq -n --arg query "$mutation" --argjson variables "$variables" '{query: $query, variables: $variables}')")

    echo "Response: $response"

    local new_draft_id=$(echo "$response" | jq -r '.data.createDraft.draft.id // empty')

    if [[ -n "$new_draft_id" ]]; then
        echo "Draft created with ID: $new_draft_id"

        # Save draft ID
        jq ".\"${ARTICLE_KEY}\".draftId = \"$new_draft_id\"" "$IDS_FILE" > "${IDS_FILE}.tmp" && mv "${IDS_FILE}.tmp" "$IDS_FILE"

        send_discord_notification "success" "Draft created: $TITLE (ID: $new_draft_id)"
        return 0
    else
        local error=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"')
        echo "Error creating draft: $error"
        send_discord_notification "failure" "Failed to create draft: $TITLE - $error"
        return 1
    fi
}

# Update Draft
update_draft() {
    local draft_id="$1"
    echo "Updating draft: $draft_id"

    local mutation
    read -r -d '' mutation << 'EOF' || true
mutation UpdateDraft($input: UpdateDraftInput!) {
    updateDraft(input: $input) {
        draft {
            id
            title
            slug
        }
    }
}
EOF

    local variables=$(cat <<EOF
{
    "input": {
        "id": "$draft_id",
        "title": $ESCAPED_TITLE,
        "contentMarkdown": $ESCAPED_CONTENT,
        "tags": $TAGS_JSON
    }
}
EOF
)

    # Add optional fields using jq
    if [[ -n "$SUBTITLE" ]]; then
        variables=$(echo "$variables" | jq --argjson subtitle "$ESCAPED_SUBTITLE" '.input.subtitle = $subtitle')
    fi
    if [[ -n "$COVER_IMAGE" ]]; then
        variables=$(echo "$variables" | jq --arg url "$COVER_IMAGE" '.input.coverImageOptions = {coverImageURL: $url}')
    fi
    if [[ -n "$SLUG" ]]; then
        variables=$(echo "$variables" | jq --arg slug "$SLUG" '.input.slug = $slug')
    fi

    local response=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $HASHNODE_TOKEN" \
        -d "$(jq -n --arg query "$mutation" --argjson variables "$variables" '{query: $query, variables: $variables}')")

    echo "Response: $response"

    local updated_id=$(echo "$response" | jq -r '.data.updateDraft.draft.id // empty')

    if [[ -n "$updated_id" ]]; then
        echo "Draft updated: $updated_id"
        send_discord_notification "success" "Draft updated: $TITLE"
        return 0
    else
        local error=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"')
        echo "Error updating draft: $error"
        send_discord_notification "failure" "Failed to update draft: $TITLE - $error"
        return 1
    fi
}

# Publish Draft
publish_draft() {
    local draft_id="$1"
    echo "Publishing draft: $draft_id"

    local mutation
    read -r -d '' mutation << 'EOF' || true
mutation PublishDraft($input: PublishDraftInput!) {
    publishDraft(input: $input) {
        post {
            id
            title
            slug
            url
        }
    }
}
EOF

    local variables=$(cat <<EOF
{
    "input": {
        "draftId": "$draft_id"
    }
}
EOF
)

    local response=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $HASHNODE_TOKEN" \
        -d "$(jq -n --arg query "$mutation" --argjson variables "$variables" '{query: $query, variables: $variables}')")

    echo "Response: $response"

    local new_post_id=$(echo "$response" | jq -r '.data.publishDraft.post.id // empty')
    local post_url=$(echo "$response" | jq -r '.data.publishDraft.post.url // empty')

    if [[ -n "$new_post_id" ]]; then
        echo "Post published with ID: $new_post_id"
        echo "URL: $post_url"

        # Save post ID and remove draft ID
        jq ".\"${ARTICLE_KEY}\".postId = \"$new_post_id\" | del(.\"${ARTICLE_KEY}\".draftId)" "$IDS_FILE" > "${IDS_FILE}.tmp" && mv "${IDS_FILE}.tmp" "$IDS_FILE"

        send_discord_notification "success" "Article published: $TITLE\nURL: $post_url"
        return 0
    else
        local error=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"')
        echo "Error publishing draft: $error"
        send_discord_notification "failure" "Failed to publish: $TITLE - $error"
        return 1
    fi
}

# Update Published Post
update_post() {
    local post_id="$1"
    echo "Updating published post: $post_id"

    local mutation
    read -r -d '' mutation << 'EOF' || true
mutation UpdatePost($input: UpdatePostInput!) {
    updatePost(input: $input) {
        post {
            id
            title
            slug
            url
        }
    }
}
EOF

    local variables=$(cat <<EOF
{
    "input": {
        "id": "$post_id",
        "title": $ESCAPED_TITLE,
        "contentMarkdown": $ESCAPED_CONTENT,
        "tags": $TAGS_JSON
    }
}
EOF
)

    # Add optional fields using jq
    if [[ -n "$SUBTITLE" ]]; then
        variables=$(echo "$variables" | jq --argjson subtitle "$ESCAPED_SUBTITLE" '.input.subtitle = $subtitle')
    fi
    if [[ -n "$COVER_IMAGE" ]]; then
        variables=$(echo "$variables" | jq --arg url "$COVER_IMAGE" '.input.coverImageOptions = {coverImageURL: $url}')
    fi
    if [[ -n "$SLUG" ]]; then
        variables=$(echo "$variables" | jq --arg slug "$SLUG" '.input.slug = $slug')
    fi

    local response=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $HASHNODE_TOKEN" \
        -d "$(jq -n --arg query "$mutation" --argjson variables "$variables" '{query: $query, variables: $variables}')")

    echo "Response: $response"

    local updated_id=$(echo "$response" | jq -r '.data.updatePost.post.id // empty')
    local post_url=$(echo "$response" | jq -r '.data.updatePost.post.url // empty')

    if [[ -n "$updated_id" ]]; then
        echo "Post updated: $updated_id"
        echo "URL: $post_url"
        send_discord_notification "success" "Article updated: $TITLE\nURL: $post_url"
        return 0
    else
        local error=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"')
        echo "Error updating post: $error"
        send_discord_notification "failure" "Failed to update: $TITLE - $error"
        return 1
    fi
}

# Main logic
case "$MODE" in
    draft)
        if [[ -n "$DRAFT_ID" ]]; then
            update_draft "$DRAFT_ID"
        else
            create_draft
        fi
        ;;
    publish)
        if [[ -n "$POST_ID" ]]; then
            # Post already exists, update it
            update_post "$POST_ID"
        elif [[ -n "$DRAFT_ID" ]]; then
            # Draft exists, publish it
            publish_draft "$DRAFT_ID"
        else
            # No draft or post exists, create draft first then publish
            create_draft
            # Re-read the draft ID
            DRAFT_ID=$(jq -r ".\"${ARTICLE_KEY}\".draftId // empty" "$IDS_FILE")
            if [[ -n "$DRAFT_ID" ]]; then
                publish_draft "$DRAFT_ID"
            else
                echo "Error: Failed to create draft before publishing"
                send_discord_notification "failure" "Failed to publish: Could not create draft first"
                exit 1
            fi
        fi
        ;;
    *)
        echo "Error: Invalid mode. Use 'draft' or 'publish'"
        echo "Usage: $0 <draft|publish> <markdown_file>"
        exit 1
        ;;
esac
