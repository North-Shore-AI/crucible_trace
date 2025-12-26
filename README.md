<p align="center">
  <img src="assets/crucible_trace.svg" alt="Trace" width="150"/>
</p>

# CrucibleTrace

[![Elixir](https://img.shields.io/badge/elixir-1.14+-purple.svg)](https://elixir-lang.org)
[![Hex.pm](https://img.shields.io/hexpm/v/crucible_trace.svg)](https://hex.pm/packages/crucible_trace)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/crucible_trace)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/North-Shore-AI/crucible_trace/blob/main/LICENSE)

**Structured causal reasoning chain logging for LLM code generation**

CausalTrace enables transparency and debugging in LLM-based code generation by capturing the decision-making process. It logs causal reasoning chains with events, alternatives considered, confidence levels, and supporting rationale.

## Features

- **Event Tracking**: Capture decision points with alternatives and reasoning
- **Chain Management**: Organize events into coherent reasoning chains
- **LLM Integration**: Parse events directly from LLM output with XML tags
- **Persistent Storage**: Save chains to disk in JSON format with search capabilities
- **Interactive Visualization**: Generate beautiful HTML views with filtering and statistics
- **Analysis Tools**: Query events, calculate statistics, find decision points
- **Multiple Export Formats**: JSON, Markdown, CSV, and Mermaid diagrams
- **Chain Comparison**: Diff two chains to identify changes, track confidence evolution (v0.2.0)
- **Mermaid Diagrams**: Export to flowchart, sequence, timeline, or graph formats for documentation (v0.2.0)

## Installation

Add `causal_trace` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:crucible_trace, "~> 0.2.0"}
  ]
end
```

Or install from GitHub:

```elixir
def deps do
  [
  ]
end
```

## Quick Start

### Creating Events Manually

```elixir
# Create a new chain
chain = CrucibleTrace.new_chain("API Implementation")

# Create an event
event = CrucibleTrace.create_event(
  :hypothesis_formed,
  "Use Phoenix framework",
  "Well-established with great documentation and active community",
  alternatives: ["Plug alone", "Custom HTTP server"],
  confidence: 0.9
)

# Add event to chain
chain = CrucibleTrace.add_event(chain, event)

# View statistics
stats = CrucibleTrace.statistics(chain)
# => %{total_events: 1, avg_confidence: 0.9, ...}
```

### Parsing LLM Output

```elixir
llm_output = """
<event type="hypothesis_formed">
  <decision>Use GenServer for state management</decision>
  <alternatives>Agent, ETS table, Database</alternatives>
  <reasoning>GenServer provides good balance of simplicity and features</reasoning>
  <confidence>0.85</confidence>
  <code_section>StateManager</code_section>
</event>

<code>
defmodule StateManager do
  use GenServer
  # ... implementation
end
</code>
"""

# Parse into a chain
{:ok, chain} = CrucibleTrace.parse_llm_output(llm_output, "State Manager Implementation")

# Extract just the code
code = CrucibleTrace.extract_code(llm_output)
```

### Building Prompts for LLMs

```elixir
base_spec = """
Implement a caching layer for database queries with:
- TTL support for cache entries
- Cache invalidation on writes
- Thread-safe operations
"""

# Generate a prompt that instructs the LLM to emit causal trace events
prompt = CrucibleTrace.build_causal_prompt(base_spec)

# Send prompt to your LLM, it will include event tags in its response
```

### Visualization

```elixir
# Generate interactive HTML visualization
html = CrucibleTrace.visualize(chain, style: :light)

# Save to file
{:ok, path} = CrucibleTrace.save_visualization(chain, "trace.html")

# Or open directly in browser
{:ok, _path} = CrucibleTrace.open_visualization(chain)
```

### Storage and Retrieval

```elixir
# Save chain to disk
{:ok, path} = CrucibleTrace.save(chain)

# Load by ID
{:ok, loaded_chain} = CrucibleTrace.load(chain.id)

# List all chains
{:ok, chains} = CrucibleTrace.list_chains()

# Search with criteria
{:ok, results} = CrucibleTrace.search(
  name_contains: "API",
  min_events: 5,
  created_after: ~U[2024-01-01 00:00:00Z]
)

# Export to different formats
{:ok, markdown} = CrucibleTrace.export(chain, :markdown)
{:ok, csv} = CrucibleTrace.export(chain, :csv)
```

### Analysis

```elixir
# Find decision points with alternatives
decisions = CrucibleTrace.find_decision_points(chain)

# Find low confidence events
uncertain = CrucibleTrace.find_low_confidence(chain, 0.7)

# Filter by event type
hypotheses = CrucibleTrace.get_events_by_type(chain, :hypothesis_formed)

# Custom filtering
high_conf = CrucibleTrace.filter_events(chain, fn e ->
  e.confidence >= 0.9
end)

# Chain statistics
stats = CrucibleTrace.statistics(chain)
# => %{
#   total_events: 10,
#   event_type_counts: %{hypothesis_formed: 3, pattern_applied: 2, ...},
#   avg_confidence: 0.87,
#   duration_seconds: 45
# }
```

### Chain Comparison (v0.2.0)

Compare two reasoning chains to analyze differences:

```elixir
# Compare chains from different LLM runs
{:ok, diff} = CrucibleTrace.diff_chains(chain1, chain2)

# View summary
IO.puts(diff.summary)
# => "2 added, 1 removed, 3 modified"

# Check similarity
IO.puts("Similarity: #{diff.similarity_score * 100}%")

# Export diff reports
text_diff = CrucibleTrace.diff_to_text(diff)
html_diff = CrucibleTrace.diff_to_html(diff, chain1, chain2)

# Track confidence changes
diff.confidence_deltas
# => %{"event_id" => 0.15, ...}
```

Use cases:
- **A/B Testing**: Compare reasoning from different models or prompts
- **Regression Detection**: Ensure prompt changes don't degrade reasoning quality
- **Confidence Evolution**: Track how confidence changes between iterations

### Mermaid Diagram Export (v0.2.0)

Export chains as Mermaid diagrams for documentation:

```elixir
# Export as flowchart
mermaid = CrucibleTrace.export_mermaid(chain, :flowchart,
  color_by_type: true,
  include_confidence: true
)

# Embed in markdown
File.write!("decisions.md", """
# Decision Log

```mermaid
#{mermaid}
```
""")

# Other formats
CrucibleTrace.export_mermaid(chain, :sequence)  # Sequence diagram
CrucibleTrace.export_mermaid(chain, :timeline)  # Timeline view
CrucibleTrace.export_mermaid(chain, :graph)     # Graph with relationships

# Via unified export API
{:ok, mermaid} = CrucibleTrace.export(chain, :mermaid_flowchart)
```

Generated Mermaid diagrams are compatible with:
- GitHub (renders in README.md, issues, PRs)
- GitLab (renders in merge requests, wikis)
- Obsidian, Notion, VS Code
- Any tool supporting Mermaid.js

## Event Types

CausalTrace supports six event types:

- **`:hypothesis_formed`** - Initial approach or solution hypothesis
- **`:alternative_rejected`** - Explicit rejection of an alternative approach
- **`:constraint_evaluated`** - Evaluation of a constraint or requirement
- **`:pattern_applied`** - Application of a specific design pattern
- **`:ambiguity_flagged`** - Ambiguity encountered in specification
- **`:confidence_updated`** - Change in confidence for a decision

## Event Schema

Each event contains:

```elixir
%CrucibleTrace.Event{
  id: "unique_event_id",
  timestamp: ~U[2024-01-15 10:30:00Z],
  type: :hypothesis_formed,
  decision: "What was decided",
  alternatives: ["Alternative 1", "Alternative 2"],
  reasoning: "Why this decision was made",
  confidence: 0.85,  # 0.0 to 1.0
  code_section: "ModuleName",  # optional
  spec_reference: "Section 3.2",  # optional
  metadata: %{}  # optional
}
```

## LLM Integration

When using CausalTrace with LLMs, instruct them to emit events in this XML format:

```xml
<event type="hypothesis_formed">
  <decision>Your decision</decision>
  <alternatives>Alt1, Alt2, Alt3</alternatives>
  <reasoning>Your reasoning</reasoning>
  <confidence>0.85</confidence>
  <code_section>ModuleName</code_section>
  <spec_reference>Spec Section</spec_reference>
</event>
```

Use `CrucibleTrace.build_causal_prompt/1` to automatically generate prompts with these instructions.

## Architecture

CausalTrace is organized into six main modules:

- **`CausalTrace`** - Main API and convenience functions
- **`CrucibleTrace.Event`** - Event struct and operations
- **`CrucibleTrace.Chain`** - Chain struct and collection management
- **`CrucibleTrace.Parser`** - LLM output parsing and prompt building
- **`CrucibleTrace.Storage`** - Persistence and retrieval
- **`CrucibleTrace.Viewer`** - HTML visualization generation

## Examples

The library includes comprehensive example files demonstrating various use cases:

### Basic Usage (`examples/basic_usage.exs`)
- Creating events manually
- Parsing LLM output
- Analyzing chains
- Building prompts
- Storage operations
- HTML visualization
- Chain merging

### Advanced Analysis (`examples/advanced_analysis.exs`)
- Complex reasoning chains
- Comprehensive statistics
- Issue identification (low confidence, ambiguities, rejections)
- Decision point analysis
- Confidence trend analysis
- Export for documentation
- Custom filtering and analysis
- Alternative comparison

### LLM Integration (`examples/llm_integration.exs`)
- Parsing realistic LLM-generated output
- Building causal trace prompts
- Validating LLM responses
- Multi-round conversation tracking
- Quality assurance checks for LLM outputs

### Storage and Search (`examples/storage_and_search.exs`)
- Creating and saving multiple chains
- Listing all saved chains
- Loading specific chains
- Advanced searching with filters
- Exporting chains in multiple formats (JSON, Markdown, CSV)
- Chain deletion and archiving
- Batch operations and storage statistics

### Chain Comparison (`examples/chain_comparison.exs`)
- Compare reasoning chains from different runs
- Track added/removed/modified events
- Analyze confidence deltas
- Generate HTML diff reports for side-by-side review

### Mermaid Export (`examples/mermaid_export.exs`)
- Export flowchart, sequence, timeline, and graph diagrams
- Embed diagrams in Markdown/README files
- Demonstrate GitHub/GitLab/Obsidian compatibility
- Show unified export API via `CrucibleTrace.export/3`

Run any example with:

```bash
mix run examples/basic_usage.exs
mix run examples/advanced_analysis.exs
mix run examples/llm_integration.exs
mix run examples/storage_and_search.exs
mix run examples/chain_comparison.exs
mix run examples/mermaid_export.exs
```

Run them all at once:

```bash
./examples/run_examples.sh
```

Example outputs (JSON/Markdown/HTML) are written to `example_traces/` by default (gitignored). Override with `EXAMPLES_OUTPUT_DIR=/your/path ./examples/run_examples.sh`.

## Testing

The library has comprehensive test coverage across all modules:

- **Event tests**: 11 tests covering event creation, validation, and serialization
- **Chain tests**: 18 tests covering chain operations, statistics, and filtering
- **Parser tests**: 21 tests covering LLM output parsing and validation
- **Storage tests**: 21 tests covering persistence, search, and export
- **Viewer tests**: 30 tests covering HTML generation and visualization
- **Integration tests**: 2 tests covering end-to-end functionality

Total: 103+ tests with 100% pass rate

Run the test suite:

```bash
mix test
```

Run with coverage:

```bash
mix test --cover
```

Run with strict warnings:

```bash
mix test --warnings-as-errors
```

## Configuration

CausalTrace can be configured in your `config/config.exs`:

```elixir
config :causal_trace,
  storage_dir: "causal_traces",  # Default storage directory
  default_format: :json,          # Default storage format
  visualization_style: :light     # Default HTML theme (:light or :dark)
```

## Use Cases

### Debugging LLM Code Generation

Track why an LLM made specific implementation choices:

```elixir
# Parse LLM output with reasoning
{:ok, chain} = CrucibleTrace.parse_llm_output(llm_response, "Feature Implementation")

# Find low confidence decisions that need review
uncertain = CrucibleTrace.find_low_confidence(chain, 0.7)

# Visualize to understand the reasoning flow
CrucibleTrace.open_visualization(chain)
```

### Comparing Alternative Approaches

Analyze which alternatives were considered:

```elixir
decisions = CrucibleTrace.find_decision_points(chain)

Enum.each(decisions, fn d ->
  IO.puts("Chose: #{d.decision}")
  IO.puts("Over: #{Enum.join(d.alternatives, ", ")}")
  IO.puts("Because: #{d.reasoning}\n")
end)
```

### Building Training Data

Export reasoning chains for fine-tuning:

```elixir
{:ok, chains} = CrucibleTrace.list_chains()

training_data =
  chains
  |> Enum.filter(&(&1.event_count > 5))
  |> Enum.map(fn metadata ->
    {:ok, chain} = CrucibleTrace.load(metadata.id)
    CrucibleTrace.export(chain, :json)
  end)
```

### Auditing AI Decisions

Maintain transparent records of AI reasoning:

```elixir
# Save all chains with metadata
CrucibleTrace.save(chain,
  metadata: %{
    model: "gpt-4",
    user: "john@example.com",
    project: "payment-system"
  }
)

# Search audit logs
{:ok, results} = CrucibleTrace.search(
  created_after: ~U[2024-01-01 00:00:00Z],
  name_contains: "payment"
)
```

## Performance

- Event creation: < 1ms
- Parsing: ~10ms per event
- Storage: ~50ms per chain (depends on event count)
- Visualization: ~100ms for typical chains (20-50 events)

## Limitations

- XML parsing is regex-based (simple but not fully robust)
- Storage is file-based (no database backend yet)
- HTML visualization uses inline CSS (no external assets)
- No real-time collaboration features

## ML Training Integration (v0.3.0)

CrucibleTrace now provides first-class support for ML training workflows:

### Training Events

```elixir
# Start training
event = CrucibleTrace.training_started(
  "Begin ResNet training",
  "Transfer learning from ImageNet",
  model_name: "resnet50",
  experiment_id: "exp-001"
)

# Record epoch completion
event = CrucibleTrace.epoch_completed(5, %{
  train_loss: 0.234,
  val_loss: 0.289,
  accuracy: 0.876
})

# Record checkpoint
event = CrucibleTrace.checkpoint_saved(
  "/models/checkpoint_epoch_5.pt",
  metrics: %{val_accuracy: 0.876}
)

# Wrap training function with automatic events
{chain, result} = CrucibleTrace.trace_training(chain, fn ->
  train_model(data)
end)
```

### Event Relationships

Events can now reference parent events and dependencies:

```elixir
parent = CrucibleTrace.create_event(:training_started, "Start", "Reason")
child = CrucibleTrace.create_event(:epoch_completed, "Epoch 1", "Done",
  parent_id: parent.id,
  experiment_id: "exp-001"
)

# Query relationships
{:ok, children} = CrucibleTrace.get_children(chain, parent.id)
roots = CrucibleTrace.get_root_events(chain)
leaves = CrucibleTrace.get_leaf_events(chain)

# Validate no circular dependencies
{:ok, _} = CrucibleTrace.validate_relationships(chain)
```

### Telemetry Integration

Automatically trace pipeline events:

```elixir
# Attach handlers to capture crucible_framework events
CrucibleTrace.attach_telemetry()

# Events are automatically created for pipeline stage execution

# Detach when done
CrucibleTrace.detach_telemetry()
```

### Advanced Querying

```elixir
# Content search
events = CrucibleTrace.search_events(chain, "GenServer",
  type: [:hypothesis_formed, :pattern_applied],
  min_confidence: 0.8
)

# Regex search
events = CrucibleTrace.search_regex(chain, ~r/epoch \d+/i)

# Advanced boolean queries
events = CrucibleTrace.query_events(chain, %{
  or: [
    %{type: :training_started},
    %{confidence: {:gte, 0.9}}
  ],
  and: [
    %{stage_id: "training"}
  ]
})

# Aggregate by field
counts = CrucibleTrace.aggregate_by(chain, :type, &length/1)
```

### Stage Tracing

Wrap pipeline stages with automatic tracing:

```elixir
{chain, result} = CrucibleTrace.trace_stage(chain, "preprocessing", fn ->
  preprocess_data(data)
end, experiment_id: "exp-001")
```

## Roadmap

### Completed
- [x] Diff visualization between chains (v0.2.0)
- [x] Export to Mermaid diagrams (v0.2.0)
- [x] ML training event types (v0.3.0)
- [x] Event relationships (v0.3.0)
- [x] Telemetry integration (v0.3.0)
- [x] Advanced querying (v0.3.0)
- [x] Stage tracing (v0.3.0)

### Planned
- [ ] More robust XML/JSON parsing
- [ ] Database storage backend option
- [ ] Real-time chain updates via Phoenix LiveView
- [ ] Cryptographic verification
- [ ] Distributed training support

## Contributing

This is part of the Elixir AI Research project. Contributions welcome!

## License

MIT License - see [LICENSE](https://github.com/North-Shore-AI/crucible_trace/blob/main/LICENSE) file for details

## Documentation

Full documentation can be generated with ExDoc:

```bash
mix docs
```

Then open `doc/index.html` in your browser.

## Support

For questions or issues, please open an issue on the GitHub repository.
