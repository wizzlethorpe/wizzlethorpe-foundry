#!/bin/bash

# Wizzlethorpe Labs Foundry Module Release Script
# Creates a GitHub release and publishes to FoundryVTT package registry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables from .env if it exists
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Read current version from module.json
CURRENT_VERSION=$(jq -r '.version' module.json)
MODULE_ID=$(jq -r '.id' module.json)

echo -e "${GREEN}Wizzlethorpe Labs Foundry Module Release Script${NC}"
echo "========================================"
echo "Current version: $CURRENT_VERSION"
echo ""

# Check for required tools
command -v jq >/dev/null 2>&1 || { echo -e "${RED}Error: jq is required but not installed.${NC}" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo -e "${RED}Error: GitHub CLI (gh) is required but not installed.${NC}" >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { echo -e "${RED}Error: zip is required but not installed.${NC}" >&2; exit 1; }

# Check if gh is authenticated
gh auth status >/dev/null 2>&1 || { echo -e "${RED}Error: GitHub CLI not authenticated. Run 'gh auth login' first.${NC}" >&2; exit 1; }

# Get version argument or prompt
if [ -n "$1" ]; then
    NEW_VERSION="$1"
else
    echo -e "${YELLOW}Enter new version (or press Enter to keep $CURRENT_VERSION):${NC}"
    read -r NEW_VERSION
    if [ -z "$NEW_VERSION" ]; then
        NEW_VERSION="$CURRENT_VERSION"
    fi
fi

# Validate version format (semver)
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Version must be in semver format (e.g., 2.3.1)${NC}"
    exit 1
fi

echo ""
echo "Release version: $NEW_VERSION"
echo ""

# Update module.json version if changed
if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
    echo -e "${YELLOW}Updating module.json version to $NEW_VERSION...${NC}"
    jq --arg v "$NEW_VERSION" '.version = $v' module.json > module.json.tmp && mv module.json.tmp module.json
fi

# Update download URL to use specific version tag
echo -e "${YELLOW}Updating download URL for version $NEW_VERSION...${NC}"
jq --arg v "$NEW_VERSION" '.download = "https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/download/v" + $v + "/module.zip"' module.json > module.json.tmp && mv module.json.tmp module.json

# Create build directory
BUILD_DIR=$(mktemp -d)
MODULE_DIR="$BUILD_DIR/$MODULE_ID"
mkdir -p "$MODULE_DIR"

echo -e "${YELLOW}Building release package...${NC}"

# Copy module files
cp module.json "$MODULE_DIR/"
cp -r scripts "$MODULE_DIR/"
cp -r styles "$MODULE_DIR/"
cp -r templates "$MODULE_DIR/"
cp -r lang "$MODULE_DIR/"
cp -r images "$MODULE_DIR/"

# Copy optional files if they exist
[ -f LICENSE ] && cp LICENSE "$MODULE_DIR/"
[ -f README.md ] && cp README.md "$MODULE_DIR/"

# Create zip file
cd "$BUILD_DIR"
zip -r module.zip "$MODULE_ID"
cd "$SCRIPT_DIR"

# Copy zip to script directory for release
cp "$BUILD_DIR/module.zip" ./module.zip

echo -e "${GREEN}Created module.zip${NC}"

# Create GitHub release
TAG="v$NEW_VERSION"
RELEASE_NOTES="## Wizzlethorpe Labs v$NEW_VERSION

### Changes
- See commit history for details

### Installation
- **Manifest URL:** \`https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/latest/download/module.json\`
- **Direct Download:** \`https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/download/$TAG/module.zip\`

### Compatibility
- Foundry VTT v13+"

echo ""
echo -e "${YELLOW}Creating GitHub release $TAG...${NC}"

# Check if release already exists
if gh release view "$TAG" >/dev/null 2>&1; then
    echo -e "${YELLOW}Release $TAG already exists. Deleting and recreating...${NC}"
    gh release delete "$TAG" --yes
    git push origin --delete "$TAG" 2>/dev/null || true
fi

# Create the release with assets
gh release create "$TAG" \
    --title "Wizzlethorpe Labs $NEW_VERSION" \
    --notes "$RELEASE_NOTES" \
    module.zip \
    module.json

echo -e "${GREEN}GitHub release created successfully!${NC}"
echo ""

# Publish to FoundryVTT Package Registry
echo -e "${YELLOW}Do you want to publish to FoundryVTT Package Registry? (y/n)${NC}"
read -r PUBLISH_FOUNDRY

if [ "$PUBLISH_FOUNDRY" = "y" ] || [ "$PUBLISH_FOUNDRY" = "Y" ]; then
    # Check for FoundryVTT API token (prefer FOUNDRY_RELEASE_TOKEN from .env)
    FOUNDRY_TOKEN="${FOUNDRY_RELEASE_TOKEN:-$FOUNDRY_API_TOKEN}"
    if [ -z "$FOUNDRY_TOKEN" ]; then
        echo -e "${YELLOW}Enter your FoundryVTT API token (or add FOUNDRY_RELEASE_TOKEN to .env):${NC}"
        read -rs FOUNDRY_TOKEN
        echo ""
    fi

    if [ -z "$FOUNDRY_TOKEN" ]; then
        echo -e "${RED}Error: FoundryVTT API token is required for publishing.${NC}"
        echo "Get your token at: https://foundryvtt.com/me/api-tokens"
    else
        echo -e "${YELLOW}Publishing to FoundryVTT...${NC}"

        # FoundryVTT Package Release API
        MANIFEST_URL="https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/download/$TAG/module.json"

        RESPONSE=$(curl -s -X POST \
            "https://api.foundryvtt.com/_api/packages/release_version/" \
            -H "Content-Type: application/json" \
            -H "Authorization: $FOUNDRY_TOKEN" \
            -d "{
                \"id\": \"$MODULE_ID\",
                \"dry-run\": false,
                \"release\": {
                    \"version\": \"$NEW_VERSION\",
                    \"manifest\": \"$MANIFEST_URL\",
                    \"notes\": \"https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/tag/$TAG\",
                    \"compatibility\": {
                        \"minimum\": \"13\",
                        \"verified\": \"13\"
                    }
                }
            }")

        if echo "$RESPONSE" | grep -q '"status":\s*"success"'; then
            echo -e "${GREEN}Successfully published to FoundryVTT Package Registry!${NC}"
        else
            echo -e "${RED}FoundryVTT publish response:${NC}"
            echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
        fi
    fi
fi

# Cleanup
rm -rf "$BUILD_DIR"

# Reset download URL back to latest for development
jq '.download = "https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/latest/download/module.zip"' module.json > module.json.tmp && mv module.json.tmp module.json

echo ""
echo -e "${GREEN}Release complete!${NC}"
echo ""
echo "Release URL: https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/tag/$TAG"
echo "Manifest URL: https://github.com/wizzlethorpe/wizzlethorpe-foundry/releases/download/$TAG/module.json"
