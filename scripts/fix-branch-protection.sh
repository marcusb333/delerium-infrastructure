#!/bin/bash

# Fix Branch Protection Rules - Remove Deploy Check from PRs
# This script removes "deploy" from required status checks for pull requests
# The deploy check should only run on main branch, not on PRs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Install it from: https://cli.github.com/"
    echo ""
    echo "Or fix manually via GitHub UI:"
    echo "1. Go to Settings ? Branches ? Branch protection rules"
    echo "2. Edit the rule for 'main' branch"
    echo "3. Uncheck 'deploy' from required status checks"
    echo "4. Keep 'checks' checked"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}GitHub CLI is not authenticated. Please run: gh auth login${NC}"
    exit 1
fi

# Get repository info
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
if [ -z "$REPO" ]; then
    echo -e "${RED}Error: Could not determine repository. Are you in a git repository?${NC}"
    exit 1
fi

BRANCH="${1:-main}"

echo -e "${GREEN}Repository:${NC} $REPO"
echo -e "${GREEN}Branch:${NC} $BRANCH"
echo ""

# Get current branch protection rules
echo "Fetching current branch protection rules..."
CURRENT_PROTECTION=$(gh api repos/$REPO/branches/$BRANCH/protection 2>/dev/null || echo "")

if [ -z "$CURRENT_PROTECTION" ]; then
    echo -e "${YELLOW}Warning: No branch protection rules found for '$BRANCH' branch${NC}"
    echo "You may need to set up branch protection rules first."
    exit 1
fi

# Get current required status checks
REQUIRED_CHECKS=$(echo "$CURRENT_PROTECTION" | jq -r '.required_status_checks.contexts[]?' 2>/dev/null || echo "")

if [ -z "$REQUIRED_CHECKS" ]; then
    echo -e "${YELLOW}No required status checks found. Nothing to update.${NC}"
    exit 0
fi

echo "Current required status checks:"
echo "$REQUIRED_CHECKS" | while read -r check; do
    if [ "$check" = "deploy" ]; then
        echo -e "  ${RED}? $check${NC} (will be removed)"
    else
        echo -e "  ${GREEN}? $check${NC}"
    fi
done
echo ""

# Check if "deploy" is in the required checks
if echo "$REQUIRED_CHECKS" | grep -q "^deploy$"; then
    echo -e "${YELLOW}'deploy' check is currently required. This will be removed.${NC}"
    echo ""
    
    # Remove "deploy" from the list
    NEW_CHECKS=$(echo "$REQUIRED_CHECKS" | grep -v "^deploy$" | jq -R -s -c 'split("\n") | map(select(. != ""))')
    
    # Get strict status (require branches to be up to date)
    STRICT=$(echo "$CURRENT_PROTECTION" | jq -r '.required_status_checks.strict // false')
    
    echo "Updating branch protection rules..."
    
    # Update the required status checks using the contexts endpoint
    # GitHub API requires a JSON array as input, not form data
    echo "$NEW_CHECKS" | gh api repos/$REPO/branches/$BRANCH/protection/required_status_checks/contexts \
        -X PUT \
        --input - \
        2>&1 | grep -v "^\[" || {
        echo -e "${RED}Error: Failed to update branch protection rules via API${NC}"
        echo -e "${YELLOW}This might require admin permissions or manual update via GitHub UI${NC}"
        echo ""
        echo "Please update manually:"
        echo "1. Go to: https://github.com/$REPO/settings/branches"
        echo "2. Edit the rule for '$BRANCH' branch"
        echo "3. Uncheck 'deploy' from required status checks"
        echo "4. Keep 'Serial PR Checks' checked"
        exit 1
    }
    
    echo -e "${GREEN}? Successfully removed 'deploy' from required status checks!${NC}"
    echo ""
    echo "Updated required status checks:"
    echo "$NEW_CHECKS" | jq -r '.[]' | while read -r check; do
        echo -e "  ${GREEN}? $check${NC}"
    done
    echo ""
    echo -e "${GREEN}Your PRs should now be mergeable once the other checks pass!${NC}"
else
    echo -e "${GREEN}? 'deploy' is not in the required status checks. No changes needed.${NC}"
fi
