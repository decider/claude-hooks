#!/bin/bash

# Common validation loader
# Sources modular validation functions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source modular validation functions
source "$SCRIPT_DIR/typescript.sh"
source "$SCRIPT_DIR/linting.sh"

# Export common variables
export TS_OUTPUT=""
export LINT_OUTPUT=""