#!/bin/bash

# Function to increment version numbers
increment_version() {
    local version=$1
    local part=$2

    IFS='.' read -r -a version_parts <<< "$version"
    major=${version_parts[0]}
    minor=${version_parts[1]}
    patch=${version_parts[2]}

    case $part in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo "Unknown part: $part. Must be one of: major, minor, patch."
            exit 1
            ;;
    esac

    echo "$major.$minor.$patch"
}

# Check for jq
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install jq to use this script."
    exit 1
fi

# Get the current version from package.json
current_version=$(jq -r '.version' package.json)

# Check if the current version is valid
if ! [[ $current_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Current version ($current_version) is not valid."
    exit 1
fi

# Check if an argument is provided
if [ $# -eq 0 ]; then
    echo "No version part supplied. Usage: $0 {major|minor|patch}"
    exit 1
fi

# Get the new version based on the input argument
new_version=$(increment_version "$current_version" "$1")

# Create a new git branch for the release
branch_name="release/$new_version"
git checkout -b "$branch_name"

# Update package.json with the new version
jq --arg version "$new_version" '.version = $version' package.json > package.tmp && mv package.tmp package.json

# Commit the changes
git add package.json
git commit -m "Bump version to $new_version"

# Merge the release branch into main
git checkout main
git merge --no-ff "$branch_name" -m "Merge release $new_version into main"

# Tag the new version on main
git tag "v$new_version"

# Merge the main branch into develop
git checkout develop
git merge --no-ff main -m "Merge main into develop after release $new_version"

echo "Version updated to $new_version, merged into main and develop branches, and tagged as v$new_version."
