#!/bin/bash

# Define the main project's root directory
MAIN_ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -z "$MAIN_ROOT_DIR" ]; then
    echo "Error: Not in a Git repository."
    exit 1
fi

# Initialize a temporary file to store manual commands
TEMP_FILE="/tmp/submodule_manual_commands.tmp"
> "$TEMP_FILE" # Clear the file if it exists

echo "Scanning and updating Git submodules in: $MAIN_ROOT_DIR"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------"
printf "%-30s | %-15s | %-10s | %-25s | %-20s | %s\n" "Submodule Path" "Branch/Commit" "Hash (Short)" "Last Commit Timestamp" "Update Status" "Action Taken"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------"

# Use git submodule status to get a list of all submodules and their current hashes
git submodule status | while read -r line; do
    HASH=$(echo "$line" | awk '{print $1}')
    PATH_DIR=$(echo "$line" | awk '{print $2}')
    
    ACTION_TAKEN="Skipped" # Default action status
    UPDATE_STATUS="N/A"
    MANUAL_CMD=""
    
    # Change directory into the submodule to run git commands
    (cd "$PATH_DIR" 2>/dev/null && {
        # --- Git Info & Branch Determination ---
        
        # 1. Determine the currently checked out branch name
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        
        # 2. Determine the branch we should be pulling from (the default remote branch)
        PULL_BRANCH=""
        BRANCH_INFO=""
        
        # Try to use the current branch if it's not detached
        if [ "$CURRENT_BRANCH" != "HEAD" ] && [ -n "$CURRENT_BRANCH" ]; then
            PULL_BRANCH="$CURRENT_BRANCH"
            BRANCH_INFO="$CURRENT_BRANCH"
        else
            # If detached, try to determine the default branch (main/master)
            if git show-ref --quiet --verify refs/remotes/origin/main; then
                PULL_BRANCH="main"
            elif git show-ref --quiet --verify refs/remotes/origin/master; then
                PULL_BRANCH="master"
            fi
            BRANCH_INFO="Detached (Pulling $PULL_BRANCH)"
        fi
        
        SHORT_HASH=$(git rev-parse --short "$HASH" 2>/dev/null)
        COMMIT_TIMESTAMP=$(git log -1 --format=%ci "$HASH" 2>/dev/null)
        
        # --- Update Check & Execution ---
        
        # 1. Check for local changes (Safety First)
        if [ -n "$(git status --porcelain)" ]; then
            UPDATE_STATUS="Local changes exist"
            ACTION_TAKEN="Manual commit/stash needed"
            MANUAL_CMD="cd \"$PATH_DIR\" && git status"
        elif [ -z "$PULL_BRANCH" ]; then
            # Cannot determine what to pull
            UPDATE_STATUS="No branch/remote found"
            ACTION_TAKEN="Manual check needed"
            MANUAL_CMD="cd \"$PATH_DIR\" && git remote show origin"
        else
            # 2. Fetch the latest remote changes silently
            git fetch --quiet 2>/dev/null
            
            # CRITICAL: Checkout the determined branch before pulling
            # This ensures we are not pulling into a detached HEAD state if a local branch exists
            if [ "$CURRENT_BRANCH" != "$PULL_BRANCH" ]; then
                git checkout --quiet "$PULL_BRANCH" 2>/dev/null
            fi

            # 3. Count the difference to update the status column
            COMMITS_BEHIND=$(git rev-list --count HEAD..origin/"$PULL_BRANCH" 2>/dev/null)
            COMMITS_AHEAD=$(git rev-list --count origin/"$PULL_BRANCH"..HEAD 2>/dev/null)

            if [ "$COMMITS_BEHIND" -gt 0 ] && [ "$COMMITS_AHEAD" -gt 0 ]; then
                UPDATE_STATUS="${COMMITS_BEHIND} Behind, ${COMMITS_AHEAD} Ahead"
                ACTION_TAKEN="Manual merge required"
                MANUAL_CMD="cd \"$PATH_DIR\" && git pull origin \"$PULL_BRANCH\""
            elif [ "$COMMITS_BEHIND" -gt 0 ]; then
                # Only Behind: Attempt to pull
                UPDATE_STATUS="${COMMITS_BEHIND} Behind"
                
                # Perform the pull! Using --ff-only for safety
                git pull --ff-only origin "$PULL_BRANCH" 2>&1 >/dev/null
                PULL_EXIT_CODE=$?

                if [ $PULL_EXIT_CODE -eq 0 ]; then
                    ACTION_TAKEN="✅ Auto-Pulled (origin/$PULL_BRANCH)"
                    # Update status variables for the print line
                    SHORT_HASH=$(git rev-parse --short HEAD 2>/dev/null)
                    COMMIT_TIMESTAMP=$(git log -1 --format=%ci 2>/dev/null)
                else
                    ACTION_TAKEN="❌ Pull Failed (non-FF)"
                    MANUAL_CMD="cd \"$PATH_DIR\" && git pull origin \"$PULL_BRANCH\""
                fi

            elif [ "$COMMITS_AHEAD" -gt 0 ]; then
                UPDATE_STATUS="${COMMITS_AHEAD} Ahead"
                ACTION_TAKEN="Manual push needed"
                MANUAL_CMD="cd \"$PATH_DIR\" && git push origin \"$PULL_BRANCH\""
            else
                UPDATE_STATUS="Up-to-date"
                ACTION_TAKEN="No action taken"
            fi
        fi
        
        # If a manual command was generated, add it to the temporary file.
        if [ -n "$MANUAL_CMD" ]; then
            echo "$MANUAL_CMD" >> "$TEMP_FILE"
        fi
        
        # Print the results
        printf "%-30s | %-15s | %-10s | %-25s | %-20s | %s\n" \
            "$PATH_DIR" \
            "$BRANCH_INFO" \
            "$SHORT_HASH" \
            "$COMMIT_TIMESTAMP" \
            "$UPDATE_STATUS" \
            "$ACTION_TAKEN"
    })
done

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------"

## 📋 Manual Commands Required

echo -e "\n## 📋 Manual Commands Required"
if [ -f "$TEMP_FILE" ]; then
    MANUAL_COMMANDS=$(cat "$TEMP_FILE")
    
    if [ -n "$MANUAL_COMMANDS" ]; then
        echo "The following submodules require manual intervention (push, merge, or fix local changes):"
        echo "```bash"
        echo "$MANUAL_COMMANDS"
        echo "```"
    else
        echo "No submodules require manual commands."
    fi
    # Clean up the temporary file
    rm "$TEMP_FILE"
fi