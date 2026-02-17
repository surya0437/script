#!/bin/bash

read -p "Enter START date (YYYY-MM-DD): " START_DATE
read -p "Enter END date (YYYY-MM-DD, leave empty = today): " END_DATE

ROOT_DIR="$(pwd)"

if [ -z "$END_DATE" ]; then
    END_DATE="$(date +%Y-%m-%d)"
fi

echo ""
echo "📊 Commit Report ($START_DATE → $END_DATE)"
echo "===================================================================================================================="

GRAND_TOTAL=0
declare -A PROJECT_SUMMARY


detect_commit_type() {

    TYPE="chore"

    git add .

    STATUS=$(git diff --cached --name-status)

    if echo "$STATUS" | grep -q '^A'; then
        TYPE="feat"
    fi

    if echo "$STATUS" | grep -Ei 'fix|bug|error|issue|crash' >/dev/null; then
        TYPE="fix"
    fi

    if echo "$STATUS" | grep -Ei '\.md$|\.env|package\.json|composer\.json|yml$|yaml$' >/dev/null; then
        TYPE="chore"
    fi

    echo "$TYPE"
}


for dir in */; do
    if [ -d "$dir/.git" ]; then

        PROJECT_NAME="${dir%/}"

        echo ""
        echo "📁 Project: $PROJECT_NAME"
        echo "------------------------------------------------------------------------------------------------------------------------"

        cd "$dir" || continue


        CURRENT_BRANCH=$(git branch --show-current)

        echo "➡️  Current branch: $CURRENT_BRANCH"


        # Check dirty
        if ! git diff --quiet || ! git diff --cached --quiet; then

            # Skip auto commit on main/master
            if [[ "$CURRENT_BRANCH" != "main" && "$CURRENT_BRANCH" != "master" ]]; then

                echo "⚠️  Uncommitted changes found on feature branch"

                COMMIT_TYPE=$(detect_commit_type)

                COMMIT_MSG="${COMMIT_TYPE}(${CURRENT_BRANCH}): auto commit before report"

                echo "💾 Auto committing: $COMMIT_MSG"

                git commit -m "$COMMIT_MSG" --quiet

            else
                echo "⚠️  Uncommitted changes on $CURRENT_BRANCH (auto-commit skipped)"
            fi

        else
            echo "✅ Working tree clean"
        fi


        # Fetch
        git fetch origin --quiet


        # Detect target branch
        if git show-ref --verify --quiet refs/heads/master; then
            TARGET_BRANCH="master"
        elif git show-ref --verify --quiet refs/heads/main; then
            TARGET_BRANCH="main"
        else
            echo "⚠️  No master/main branch found. Skipping."
            cd "$ROOT_DIR"
            continue
        fi


        echo "➡️  Switching to: $TARGET_BRANCH"

        git checkout "$TARGET_BRANCH" --quiet
        git pull origin "$TARGET_BRANCH" --quiet


        # Log
        git log "$TARGET_BRANCH" \
            --since="$START_DATE" \
            --until="$END_DATE" \
            --pretty="%an" |
            sort |
            uniq -c |
            sort -nr > /tmp/git_authors.txt


        PROJECT_TOTAL=0

        printf "%-25s %s\n" "Author" "Commits"
        printf "%-25s %s\n" "------" "-------"

        while read -r count name; do
            printf "%-25s %d\n" "$name" "$count"
            PROJECT_TOTAL=$((PROJECT_TOTAL + count))
        done < /tmp/git_authors.txt


        echo "------------------------------------------------------------------------------------------------------------------------"
        echo "Total commits ($TARGET_BRANCH): $PROJECT_TOTAL"


        PROJECT_SUMMARY["$PROJECT_NAME"]=$PROJECT_TOTAL
        GRAND_TOTAL=$((GRAND_TOTAL + PROJECT_TOTAL))


        # Return
        echo "↩️  Returning to: $CURRENT_BRANCH"
        git checkout "$CURRENT_BRANCH" --quiet


        cd "$ROOT_DIR" || exit
    fi
done


# Summary
echo ""
echo "===================================================================================================================="
echo "📌 GRAND TOTAL (All Projects): $GRAND_TOTAL"
echo ""

echo "📂 Project-wise Summary"
echo "-----------------------"

for project in "${!PROJECT_SUMMARY[@]}"; do

    COUNT="${PROJECT_SUMMARY[$project]}"

    if [ "$COUNT" -gt 0 ]; then
        printf "%-25s : %d\n" "$project" "$COUNT"
    fi

done

echo "===================================================================================================================="
