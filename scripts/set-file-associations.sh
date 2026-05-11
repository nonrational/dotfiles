#!/usr/bin/env bash

# Set default applications for file types using duti
# Run: make set-file-associations

set -euo pipefail

SUBLIME_BUNDLE_ID="com.sublimetext.4"

# Verify duti is installed
if ! command -v duti &> /dev/null; then
  echo "Error: duti is not installed. Run 'brew install duti' first."
  exit 1
fi

# Verify Sublime Text is installed
if ! mdfind "kMDItemCFBundleIdentifier == '$SUBLIME_BUNDLE_ID'" | head -1 | grep -q .; then
  echo "Error: Sublime Text 4 not found."
  exit 1
fi

echo "Setting file associations for Sublime Text..."

# Plain text files (.txt)
duti -s "$SUBLIME_BUNDLE_ID" public.plain-text all

# Markdown files (.md)
duti -s "$SUBLIME_BUNDLE_ID" .md all

echo "Done."
