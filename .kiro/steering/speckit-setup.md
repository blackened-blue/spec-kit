---
inclusion: always
name: speckit-setup
description: Set up Spec Kit when .speckit is missing from this checkout
---

# Spec Kit setup

Spec Kit lives on branch `speckit`, not on the code branches, so a fresh clone has no `.speckit/` directory.

At the start of a session, if `.speckit/` does not exist in the project root, run `scripts/setup-speckit.sh` before doing anything else. It is safe to re-run. Skills it installs load from the next session, so tell the user to start a new session if a `speckit-*` skill is not yet available.
