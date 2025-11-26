#!/usr/bin/env elixir

# Mermaid diagram export examples
# Run with: mix run examples/mermaid_export.exs

IO.puts("\n=== CrucibleTrace Mermaid Export Examples ===\n")

output_dir = System.get_env("EXAMPLES_OUTPUT_DIR", "example_traces")
File.mkdir_p!(output_dir)
out = fn name -> Path.join(output_dir, name) end

# Create a sample chain with representative events
chain = CrucibleTrace.new_chain("API Gateway Implementation")

chain =
  chain
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :hypothesis_formed,
      "Use Phoenix for API gateway",
      "Phoenix provides excellent performance and WebSocket support",
      alternatives: ["Plug alone", "Custom Cowboy"],
      confidence: 0.9
    )
  )
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :pattern_applied,
      "Apply circuit breaker pattern",
      "Prevents cascading failures when downstream services are unavailable",
      confidence: 0.95,
      code_section: "Gateway.CircuitBreaker"
    )
  )
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :constraint_evaluated,
      "Implement rate limiting per API key",
      "Required for fair usage and preventing abuse",
      alternatives: ["IP-based limiting", "No limits"],
      confidence: 0.85,
      spec_reference: "Security Requirements v2.1"
    )
  )
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :pattern_applied,
      "Use JWT for authentication",
      "Stateless authentication scales better than sessions",
      confidence: 0.9
    )
  )
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :ambiguity_flagged,
      "Unclear timeout requirements for external APIs",
      "Spec doesn't specify timeout values, assuming 30 seconds",
      confidence: 0.6
    )
  )
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :confidence_updated,
      "Revised timeout to 10 seconds based on performance testing",
      "Load tests showed 30s is too long, causes request queuing",
      confidence: 0.8
    )
  )

# Example 1: Flowchart Export
IO.puts("Example 1: Flowchart Diagram")
IO.puts("------------------------------")

flowchart = CrucibleTrace.export_mermaid(chain, :flowchart, color_by_type: true)
IO.puts("\nGenerated Mermaid Flowchart:")
IO.puts("```mermaid")
IO.puts(flowchart)
IO.puts("```\n")

# Save to file
File.write!(out.("chain_flowchart.md"), """
# API Gateway Reasoning Chain

```mermaid
#{flowchart}
```
""")

IO.puts("Saved to #{out.("chain_flowchart.md")}")

# Example 2: Flowchart with Confidence
IO.puts("\n\nExample 2: Flowchart with Confidence Levels")
IO.puts("---------------------------------------------")

flowchart_conf =
  CrucibleTrace.export_mermaid(chain, :flowchart,
    include_confidence: true,
    color_by_type: true
  )

IO.puts("\nWith confidence scores:")
IO.puts("```mermaid")
IO.puts(String.slice(flowchart_conf, 0, 400))
IO.puts("...")
IO.puts("```\n")

# Example 3: Sequence Diagram
IO.puts("\n\nExample 3: Sequence Diagram")
IO.puts("-----------------------------")

sequence = CrucibleTrace.export_mermaid(chain, :sequence, show_alternatives: true)
IO.puts("\nSequence diagram showing progression:")
IO.puts("```mermaid")
IO.puts(sequence)
IO.puts("```\n")

File.write!(out.("chain_sequence.md"), """
# API Gateway Decision Sequence

```mermaid
#{sequence}
```
""")

IO.puts("Saved to #{out.("chain_sequence.md")}")

# Example 4: Timeline
IO.puts("\n\nExample 4: Timeline View")
IO.puts("-------------------------")

timeline = CrucibleTrace.export_mermaid(chain, :timeline, title: chain.name)
IO.puts("\nTimeline of decisions:")
IO.puts("```mermaid")
IO.puts(timeline)
IO.puts("```\n")

File.write!(out.("chain_timeline.md"), """
# API Gateway Decision Timeline

```mermaid
#{timeline}
```
""")

IO.puts("Saved to #{out.("chain_timeline.md")}")

# Example 5: Graph (for relationships)
IO.puts("\n\nExample 5: Graph Visualization")
IO.puts("--------------------------------")

graph = CrucibleTrace.export_mermaid(chain, :graph, color_by_type: true)
IO.puts("\nGraph representation:")
IO.puts("```mermaid")
IO.puts(String.slice(graph, 0, 400))
IO.puts("...")
IO.puts("```\n")

# Example 6: Export via Storage module
IO.puts("\n\nExample 6: Using Storage Export")
IO.puts("---------------------------------")

{:ok, mermaid_flow} = CrucibleTrace.export(chain, :mermaid_flowchart, max_label_length: 40)
{:ok, mermaid_seq} = CrucibleTrace.export(chain, :mermaid_sequence)
{:ok, mermaid_time} = CrucibleTrace.export(chain, :mermaid_timeline)

IO.puts("Exported to multiple Mermaid formats via Storage.export/3")
IO.puts("  - Flowchart: #{String.length(mermaid_flow)} characters")
IO.puts("  - Sequence:  #{String.length(mermaid_seq)} characters")
IO.puts("  - Timeline:  #{String.length(mermaid_time)} characters")

# Example 7: Integration with Markdown Documentation
IO.puts("\n\nExample 7: Documentation Integration")
IO.puts("--------------------------------------")

doc_content = """
# API Gateway Implementation Decision Log

## Overview
This document tracks the key architectural decisions made during the API Gateway implementation.

## Decision Chain
The following diagram shows our reasoning process:

```mermaid
#{flowchart}
```

## Key Decisions

### 1. Framework Choice
We chose Phoenix for the API gateway based on its performance characteristics and WebSocket support.

### 2. Circuit Breaker Pattern
Implementing circuit breakers prevents cascading failures when downstream services become unavailable.

### 3. Authentication Strategy
JWT-based authentication provides stateless, scalable authentication without server-side session storage.

## Timeline

```mermaid
#{timeline}
```

## Statistics

#{inspect(CrucibleTrace.statistics(chain), pretty: true)}
"""

File.write!(out.("api_gateway_decisions.md"), doc_content)
IO.puts("\nCreated comprehensive documentation with embedded Mermaid diagrams")
IO.puts("Saved to #{out.("api_gateway_decisions.md")}")

# Example 8: GitHub/GitLab Compatible
IO.puts("\n\nExample 8: GitHub/GitLab Compatibility")
IO.puts("----------------------------------------")

IO.puts("\n✓ All generated Mermaid diagrams are compatible with:")
IO.puts("  - GitHub (renders in README.md and issues)")
IO.puts("  - GitLab (renders in merge requests and wikis)")
IO.puts("  - Obsidian (renders in notes)")
IO.puts("  - VS Code with Markdown Preview Enhanced")
IO.puts("  - Any tool supporting Mermaid.js")

IO.puts("\n=== Mermaid Export Examples Complete ===\n")
IO.puts("\nGenerated files:")
IO.puts("  - chain_flowchart.md")
IO.puts("  - chain_sequence.md")
IO.puts("  - chain_timeline.md")
IO.puts("  - api_gateway_decisions.md")
