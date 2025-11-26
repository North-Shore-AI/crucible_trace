# Examples
Output files (markdown, JSON, HTML) are written to `example_traces/` by default (gitignored). Override with `EXAMPLES_OUTPUT_DIR=/path/to/dir`.

Run everything at once:

```bash
./examples/run_examples.sh
```

Individual scripts:
- `examples/basic_usage.exs` — create events, parse LLM output, analyze, visualize, and store.
- `examples/advanced_analysis.exs` — deeper statistics, issue identification, and exports.
- `examples/llm_integration.exs` — prompt building, parsing realistic LLM output, and validation.
- `examples/storage_and_search.exs` — saving, listing, loading, searching, and exporting chains.
- `examples/chain_comparison.exs` — diff two chains, track confidence deltas, and generate HTML diff reports.
- `examples/mermaid_export.exs` — export flowchart/sequence/timeline/graph Mermaid diagrams and embed in docs.
