#!/usr/bin/env elixir

# Basic usage examples for CausalTrace library
# Run with: elixir -r lib/causal_trace.ex examples/basic_usage.exs

IO.puts("\n=== CausalTrace Basic Usage Examples ===\n")

output_dir = System.get_env("EXAMPLES_OUTPUT_DIR", "example_traces")
File.mkdir_p!(output_dir)
storage_opts = [storage_dir: output_dir]
out = fn name -> Path.join(output_dir, name) end

# Example 1: Creating events manually
IO.puts("Example 1: Creating events manually")
IO.puts("-------------------------------------")

chain = CrucibleTrace.new_chain("REST API Implementation")

event1 =
  CrucibleTrace.create_event(
    :hypothesis_formed,
    "Use Phoenix framework",
    "Well-established, great documentation, active community",
    alternatives: ["Plug alone", "Custom HTTP server"],
    confidence: 0.9
  )

event2 =
  CrucibleTrace.create_event(
    :pattern_applied,
    "Apply MVC pattern with contexts",
    "Phoenix best practice, separates business logic from web layer",
    confidence: 0.95,
    code_section: "MyAppWeb"
  )

event3 =
  CrucibleTrace.create_event(
    :constraint_evaluated,
    "Use JSON API format",
    "Client needs standardized REST responses, JSON:API provides conventions",
    alternatives: ["Custom JSON structure", "HAL"],
    confidence: 0.85,
    spec_reference: "Client API Requirements v2.1"
  )

chain =
  chain
  |> CrucibleTrace.add_event(event1)
  |> CrucibleTrace.add_event(event2)
  |> CrucibleTrace.add_event(event3)

IO.puts("Created chain: #{chain.name}")
IO.puts("Events: #{length(chain.events)}")
IO.inspect(CrucibleTrace.statistics(chain), label: "Statistics")

# Example 2: Parsing LLM output
IO.puts("\n\nExample 2: Parsing LLM output")
IO.puts("-------------------------------------")

llm_output = """
<event type="hypothesis_formed">
  <decision>Use GenServer for rate limiter state</decision>
  <alternatives>ETS table, Agent, Database</alternatives>
  <reasoning>GenServer provides good balance of simplicity and features. State is ephemeral and doesn't need persistence. Agent is too simple for our needs. ETS would work but GenServer is more idiomatic for this use case.</reasoning>
  <confidence>0.85</confidence>
  <code_section>RateLimiter.Server</code_section>
</event>

<event type="pattern_applied">
  <decision>Apply token bucket algorithm</decision>
  <reasoning>Token bucket allows burst traffic while maintaining average rate limit. Simpler than leaky bucket for our use case.</reasoning>
  <confidence>0.9</confidence>
</event>

<event type="constraint_evaluated">
  <decision>Set default limit to 100 requests per minute</decision>
  <reasoning>Based on expected load and API provider limits. Configurable per client.</reasoning>
  <confidence>0.75</confidence>
  <spec_reference>Performance Requirements Section 4.2</spec_reference>
</event>

<code>
defmodule RateLimiter.Server do
  use GenServer

  defstruct tokens: 100, max_tokens: 100, refill_rate: 100

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def check_rate(client_id) do
    GenServer.call(__MODULE__, {:check_rate, client_id})
  end

  def init(opts) do
    schedule_refill()
    {:ok, %__MODULE__{}}
  end

  defp schedule_refill do
    Process.send_after(self(), :refill, 60_000)
  end
end
</code>
"""

case CrucibleTrace.parse_llm_output(llm_output, "Rate Limiter Implementation") do
  {:ok, parsed_chain} ->
    IO.puts("Parsed chain: #{parsed_chain.name}")
    IO.puts("Found #{length(parsed_chain.events)} events")

    # Extract and display code
    code = CrucibleTrace.extract_code(llm_output)
    IO.puts("\nExtracted code:")
    IO.puts(String.slice(code, 0, 200) <> "...")

    # Analyze decision points
    decisions = CrucibleTrace.find_decision_points(parsed_chain)
    IO.puts("\nDecision points: #{length(decisions)}")

    Enum.each(decisions, fn decision ->
      IO.puts("  - #{decision.decision}")
      IO.puts("    Alternatives: #{Enum.join(decision.alternatives, ", ")}")
      IO.puts("    Confidence: #{decision.confidence}")
    end)

  {:error, reason} ->
    IO.puts("Failed to parse: #{reason}")
end

# Example 3: Analyzing chains
IO.puts("\n\nExample 3: Analyzing chains")
IO.puts("-------------------------------------")

# Find low confidence decisions
low_confidence = CrucibleTrace.find_low_confidence(chain, 0.9)
IO.puts("Low confidence events (< 0.9): #{length(low_confidence)}")

Enum.each(low_confidence, fn event ->
  IO.puts("  - #{event.decision} (#{event.confidence})")
end)

# Filter events by type
hypotheses = CrucibleTrace.get_events_by_type(chain, :hypothesis_formed)
IO.puts("\nHypothesis events: #{length(hypotheses)}")

# Custom filtering
high_confidence_chain =
  CrucibleTrace.filter_events(chain, fn e ->
    e.confidence >= 0.9
  end)

IO.puts("High confidence events (>= 0.9): #{length(high_confidence_chain.events)}")

# Example 4: Building prompts for LLMs
IO.puts("\n\nExample 4: Building causal prompts")
IO.puts("-------------------------------------")

base_spec = """
Implement a caching layer for our database queries with the following requirements:
- Support TTL (time-to-live) for cache entries
- Handle cache invalidation on writes
- Thread-safe operations
- Configurable storage backend (memory, Redis, etc.)
"""

prompt = CrucibleTrace.build_causal_prompt(base_spec)
IO.puts("Generated prompt length: #{String.length(prompt)} characters")
IO.puts("\nPrompt preview:")
IO.puts(String.slice(prompt, 0, 300) <> "...")

# Example 5: Saving and loading chains
IO.puts("\n\nExample 5: Storage operations")
IO.puts("-------------------------------------")

# Save chain
case CrucibleTrace.save(chain, storage_opts) do
  {:ok, path} ->
    IO.puts("Saved chain to: #{path}")

    # Load it back
    case CrucibleTrace.load(chain.id, storage_opts) do
      {:ok, loaded_chain} ->
        IO.puts("Loaded chain: #{loaded_chain.name}")
        IO.puts("Events preserved: #{length(loaded_chain.events)}")

      {:error, reason} ->
        IO.puts("Failed to load: #{inspect(reason)}")
    end

    # Export to different formats
    case CrucibleTrace.export(chain, :markdown) do
      {:ok, markdown} ->
        IO.puts("\nMarkdown export preview:")
        IO.puts(String.slice(markdown, 0, 300) <> "...")

      {:error, reason} ->
        IO.puts("Export failed: #{reason}")
    end

  {:error, reason} ->
    IO.puts("Failed to save: #{inspect(reason)}")
end

# Example 6: Visualization
IO.puts("\n\nExample 6: HTML visualization")
IO.puts("-------------------------------------")

html = CrucibleTrace.visualize(chain, style: :light)
IO.puts("Generated HTML visualization")
IO.puts("HTML length: #{String.length(html)} characters")

# Save to file
html_file = out.("visualization.html")

case CrucibleTrace.save_visualization(chain, html_file) do
  {:ok, path} ->
    IO.puts("Saved visualization to: #{path}")
    IO.puts("Open this file in a browser to view the interactive visualization")

  {:error, reason} ->
    IO.puts("Failed to save visualization: #{inspect(reason)}")
end

# Example 7: Merging chains
IO.puts("\n\nExample 7: Merging chains")
IO.puts("-------------------------------------")

chain2 =
  CrucibleTrace.new_chain("Database Layer")
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :hypothesis_formed,
      "Use Ecto for database access",
      "Standard choice for Elixir, well-maintained",
      confidence: 0.95
    )
  )

merged = CrucibleTrace.merge_chains(chain, chain2)
IO.puts("Merged chains: #{merged.name}")
IO.puts("Total events: #{length(merged.events)}")

IO.puts("\n=== Examples completed ===\n")
