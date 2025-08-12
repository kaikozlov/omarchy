#!/bin/bash

# 1. Ask for full name (used for git user.name)
export OMARCHY_USER_NAME=$(gum input --placeholder "Enter full name" --prompt "Name> ")

# 2. Ask for primary email (used for XCompose and git unless overridden)
export OMARCHY_USER_EMAIL=$(gum input --placeholder "Enter primary email address" --prompt "Email> ")

# 3. Optionally set a different email for git user.email
if gum confirm "Use a DIFFERENT email address for git commits?"; then
	export OMARCHY_GIT_EMAIL=$(gum input --placeholder "Enter git email address" --prompt "Git Email> ")
fi
