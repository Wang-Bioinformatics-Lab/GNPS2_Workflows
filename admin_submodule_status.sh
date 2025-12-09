#find . -maxdepth 1 -type d -exec sh -c 'cd "$0" && [ -d .git ] && git pull origin master' {} \;

#!/bin/bash

# Define the main project's root directory
MAIN_ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -z "$MAIN_ROOT_DIR" ]; then
    echo "Error: Not in a Git repository."
    exit 1
fi

echo "Scanning for Git submodules in: $MAIN_ROOT_DIR"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------"
printf "%-30s | %-15s | %-10s | %-25s | %-20s | %s\n" "Submodule Path" "Branch/Commit" "Hash (Short)" "Last Commit Timestamp" "Update Status" "Recommended Command"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------"

# Use git submodule status to get a list of all submodules and their current hashes
git submodule status | while read -r line; do
    HASH=$(echo "$line" | awk '{print $1}')
    PATH_DIR=$(echo "$line" | awk '{print $2}')
    
    # Change directory into the submodule to run git commands
    (cd "$PATH_DIR" 2>/dev/null && {
        # --- Git Info Extraction ---
        BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [ "$BRANCH_NAME" == "HEAD" ] || [ -z "$BRANCH_NAME" ]; then
            BRANCH_INFO="Detached"
        else
            BRANCH_INFO="$BRANCH_NAME"
        fi
        
        SHORT_HASH=$(echo "$HASH" | cut -c1-10)
        COMMIT_TIMESTAMP=$(git log -1 --format=%ci "$HASH" 2>/dev/null)
        
        # --- Update Check ---
        
        # 1. Fetch the latest remote changes silently
        git fetch --quiet 2>/dev/null
        
        # 2. Determine the default remote branch (main or master)
        # We try main first, then master, as these are the common defaults.
        DEFAULT_REMOTE_BRANCH=""
        
        # Try finding a remote branch named 'main' or 'master'
        if git show-ref --quiet --verify refs/remotes/origin/main; then
            DEFAULT_REMOTE_BRANCH="origin/main"
        elif git show-ref --quiet --verify refs/remotes/origin/master; then
            DEFAULT_REMOTE_BRANCH="origin/master"
        fi
        
        UPDATE_STATUS="Not Checked"
        UPDATE_COMMAND="N/A"

        if [ -n "$DEFAULT_REMOTE_BRANCH" ]; then
            # 3. Compare current HEAD to the default remote branch
            
            # Count the number of commits the current HEAD is BEHIND the remote branch
            COMMITS_BEHIND=$(git rev-list --count HEAD.."$DEFAULT_REMOTE_BRANCH" 2>/dev/null)
            
            # Count the number of commits the current HEAD is AHEAD of the remote branch
            COMMITS_AHEAD=$(git rev-list --count "$DEFAULT_REMOTE_BRANCH"..HEAD 2>/dev/null)
            
            if [ "$COMMITS_BEHIND" -gt 0 ] && [ "$COMMITS_AHEAD" -eq 0 ]; then
                UPDATE_STATUS="${COMMITS_BEHIND} Behind"
                UPDATE_COMMAND="git pull ${DEFAULT_REMOTE_BRANCH}"
            elif [ "$COMMITS_BEHIND" -gt 0 ] && [ "$COMMITS_AHEAD" -gt 0 ]; then
                UPDATE_STATUS="${COMMITS_BEHIND} Behind, ${COMMITS_AHEAD} Ahead (Conflict Likely)"
                UPDATE_COMMAND="git pull ${DEFAULT_REMOTE_BRANCH}"
            elif [ "$COMMITS_BEHIND" -eq 0 ] && [ "$COMMITS_AHEAD" -gt 0 ]; then
                UPDATE_STATUS="${COMMITS_AHEAD} Ahead"
                UPDATE_COMMAND="git push origin ${BRANCH_NAME}"
            else
                UPDATE_STATUS="Up-to-date"
                UPDATE_COMMAND="No update needed"
            fi
        else
            UPDATE_STATUS="No Default Remote Branch (origin/main or origin/master)"
            UPDATE_COMMAND="Check remote tracking"
        fi

        # Print the results
        printf "%-30s | %-15s | %-10s | %-25s | %-20s | %s\n" \
            "$PATH_DIR" \
            "$BRANCH_INFO" \
            "$SHORT_HASH" \
            "$COMMIT_TIMESTAMP" \
            "$UPDATE_STATUS" \
            "$UPDATE_COMMAND"
    })
done

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------"
