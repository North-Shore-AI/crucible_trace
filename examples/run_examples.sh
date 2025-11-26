#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${EXAMPLES_OUTPUT_DIR:-example_traces}"

cd "$REPO_ROOT"

if ! command -v mix >/dev/null 2>&1; then
  echo "mix not found. Please install Elixir to run the examples." >&2
  exit 1
fi

scripts=(
  "examples/basic_usage.exs"
  "examples/advanced_analysis.exs"
  "examples/llm_integration.exs"
  "examples/storage_and_search.exs"
  "examples/chain_comparison.exs"
  "examples/mermaid_export.exs"
)

export EXAMPLES_OUTPUT_DIR="$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

if [[ "${CLEAN_EXAMPLES_OUTPUT:-0}" == "1" ]]; then
  echo "Cleaning example output directory: $OUTPUT_DIR"
  rm -rf "$OUTPUT_DIR"/*
fi

echo "Compiling project..."
mix compile --quiet

for script in "${scripts[@]}"; do
  printf "\n=== Running %s ===\n" "$script"
  mix run "$script"
done

printf "\nAll examples completed.\n"
