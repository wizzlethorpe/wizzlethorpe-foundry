#!/bin/bash

# Wizzlethorpe Labs Module Release Script
# Creates a GitHub release and publishes to FoundryVTT package registry

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

CURRENT_VERSION=$(jq -r '.version' module.json)
MODULE_ID=$(jq -r '.id' module.json)
GITHUB_REPO="wizzlethorpe/wizzlethorpe-foundry"

echo -e "${GREEN}Wizzlethorpe Labs Release Script${NC}"
echo "========================================"
echo "Current version: $CURRENT_VERSION"
echo ""

command -v jq >/dev/null 2>&1 || { echo -e "${RED}Error: jq is required${NC}" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo -e "${RED}Error: GitHub CLI (gh) is required${NC}" >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { echo -e "${RED}Error: zip is required${NC}" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo -e "${RED}Error: GitHub CLI not authenticated${NC}" >&2; exit 1; }

if [ -n "$1" ]; then
    NEW_VERSION="$1"
else
    echo -e "${YELLOW}Enter new version (or press Enter to keep $CURRENT_VERSION):${NC}"
    read -r NEW_VERSION
    if [ -z "$NEW_VERSION" ]; then
        NEW_VERSION="$CURRENT_VERSION"
    fi
fi

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Version must be in semver format (e.g., 5.0.1)${NC}"
    exit 1
fi

echo "Release version: $NEW_VERSION"
echo ""

# Update module.json
if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
    echo -e "${YELLOW}Updating module.json version to $NEW_VERSION...${NC}"
    jq --arg v "$NEW_VERSION" '.version = $v' module.json > module.json.tmp && mv module.json.tmp module.json
fi

jq --arg v "$NEW_VERSION" \
   --arg repo "$GITHUB_REPO" \
   '.download = "https://github.com/" + $repo + "/releases/download/v" + $v + "/module.zip" |
    .manifest = "https://github.com/" + $repo + "/releases/download/v" + $v + "/module.json"' \
   module.json > module.json.tmp && mv module.json.tmp module.json

# Build zip
BUILD_DIR=$(mktemp -d)
MODULE_DIR="$BUILD_DIR/$MODULE_ID"
mkdir -p "$MODULE_DIR"

echo -e "${YELLOW}Building release package...${NC}"
cp module.json "$MODULE_DIR/"
cp -r scripts "$MODULE_DIR/"
[ -f LICENSE ] && cp LICENSE "$MODULE_DIR/"
[ -f README.md ] && cp README.md "$MODULE_DIR/"

cd "$BUILD_DIR"
zip -r module.zip "$MODULE_ID"
cd "$SCRIPT_DIR"
cp module.json "$BUILD_DIR/module.json"

echo -e "${GREEN}Created module.zip${NC}"

# GitHub release
TAG="v$NEW_VERSION"
RELEASE_NOTES="## Wizzlethorpe Labs v$NEW_VERSION

### Installation
- **Manifest URL:** \`https://github.com/$GITHUB_REPO/releases/latest/download/module.json\`

### Compatibility
- Foundry VTT v14+"

echo -e "${YELLOW}Creating GitHub release $TAG...${NC}"

if gh release view "$TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
    echo -e "${YELLOW}Release $TAG already exists. Deleting and recreating...${NC}"
    gh release delete "$TAG" --repo "$GITHUB_REPO" --yes
    git push origin --delete "$TAG" 2>/dev/null || true
fi

gh release create "$TAG" \
    --repo "$GITHUB_REPO" \
    --title "Wizzlethorpe Labs $NEW_VERSION" \
    --notes "$RELEASE_NOTES" \
    "$BUILD_DIR/module.zip" \
    "$BUILD_DIR/module.json"

echo -e "${GREEN}GitHub release created!${NC}"

# Publish to FoundryVTT Package Registry
FOUNDRY_TOKEN="${FOUNDRY_RELEASE_TOKEN:-$FOUNDRY_API_TOKEN}"
COMPAT_MIN=$(jq -r '.compatibility.minimum' module.json)
COMPAT_VERIFIED=$(jq -r '.compatibility.verified' module.json)

if [ -z "$FOUNDRY_TOKEN" ]; then
    echo -e "${YELLOW}Skipping FoundryVTT publish (no FOUNDRY_RELEASE_TOKEN in .env)${NC}"
    echo "To enable, add: FOUNDRY_RELEASE_TOKEN=fvttp_..."
else
    echo -e "${YELLOW}Publishing to FoundryVTT Package Registry...${NC}"

    MANIFEST_URL="https://github.com/$GITHUB_REPO/releases/download/$TAG/module.json"

    RESPONSE=$(curl -s -X POST \
        "https://foundryvtt.com/_api/packages/release_version/" \
        -H "Content-Type: application/json" \
        -H "Authorization: $FOUNDRY_TOKEN" \
        -d "{
            \"id\": \"$MODULE_ID\",
            \"dry-run\": false,
            \"release\": {
                \"version\": \"$NEW_VERSION\",
                \"manifest\": \"$MANIFEST_URL\",
                \"notes\": \"https://github.com/$GITHUB_REPO/releases/tag/$TAG\",
                \"compatibility\": {
                    \"minimum\": \"$COMPAT_MIN\",
                    \"verified\": \"$COMPAT_VERIFIED\"
                }
            }
        }")

    STATUS=$(echo "$RESPONSE" | jq -r '.status' 2>/dev/null)
    if [ "$STATUS" = "success" ]; then
        echo -e "${GREEN}Published to FoundryVTT Package Registry!${NC}"
    else
        echo -e "${RED}FoundryVTT publish failed:${NC}"
        echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    fi
fi

# Cleanup
rm -rf "$BUILD_DIR"

# Reset URLs to latest for development
jq --arg repo "$GITHUB_REPO" \
   '.download = "https://github.com/" + $repo + "/releases/latest/download/module.zip" |
    .manifest = "https://github.com/" + $repo + "/releases/latest/download/module.json"' \
   module.json > module.json.tmp && mv module.json.tmp module.json

echo ""
echo -e "${GREEN}Release complete!${NC}"
echo "Release: https://github.com/$GITHUB_REPO/releases/tag/$TAG"
