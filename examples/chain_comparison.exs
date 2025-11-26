#!/usr/bin/env elixir

# Chain comparison and diffing examples
# Run with: mix run examples/chain_comparison.exs

IO.puts("\n=== CrucibleTrace Chain Comparison Examples ===\n")

# Example 1: Comparing two versions of a reasoning chain
IO.puts("Example 1: Comparing Prompt Variations")
IO.puts("------------------------------------------")

# First version: Conservative approach
chain1 = CrucibleTrace.new_chain("Rate Limiter v1")

chain1 =
  chain1
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :hypothesis_formed,
      "Use ETS table for rate limit storage",
      "ETS provides fast in-memory lookup with minimal overhead",
      alternatives: ["GenServer", "Database"],
      confidence: 0.75
    )
  )
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :pattern_applied,
      "Apply fixed window algorithm",
      "Simplest implementation, easy to reason about",
      confidence: 0.8
    )
  )
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :constraint_evaluated,
      "Set limit to 60 requests per minute",
      "Conservative limit to prevent overload",
      confidence: 0.7
    )
  )

# Second version: More sophisticated approach
chain2 = CrucibleTrace.new_chain("Rate Limiter v2")

chain2 =
  chain2
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :hypothesis_formed,
      "Use GenServer for rate limit state",
      "GenServer provides better state management and supervision",
      alternatives: ["ETS table", "Database"],
      confidence: 0.85
    )
  )
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :pattern_applied,
      "Apply token bucket algorithm",
      "Allows burst traffic while maintaining average rate, more flexible",
      confidence: 0.9
    )
  )
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :constraint_evaluated,
      "Set limit to 100 requests per minute with burst of 120",
      "More realistic limit based on load testing",
      confidence: 0.85
    )
  )
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :pattern_applied,
      "Add per-client limits with override mechanism",
      "Allows premium clients higher limits",
      confidence: 0.8
    )
  )

# Compare the chains
{:ok, diff} = CrucibleTrace.diff_chains(chain1, chain2)

IO.puts("\n#{diff.summary}")
IO.puts("Similarity Score: #{Float.round(diff.similarity_score * 100, 1)}%\n")

IO.puts("Added Events: #{length(diff.added_events)}")
IO.puts("Removed Events: #{length(diff.removed_events)}")
IO.puts("Modified Events: #{length(diff.modified_events)}")

# Show detailed text diff
IO.puts("\n--- Detailed Diff ---")
text_diff = CrucibleTrace.diff_to_text(diff)
IO.puts(text_diff)

# Generate HTML diff report
IO.puts("\nGenerating HTML diff report...")
temp_file = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
html_path = Path.join(System.tmp_dir!(), "chain_diff_#{temp_file}.html")
html = CrucibleTrace.diff_to_html(diff, chain1, chain2)
File.write!(html_path, html)
IO.puts("HTML diff saved to: #{html_path}")

# Example 2: Confidence evolution
IO.puts("\n\nExample 2: Tracking Confidence Changes")
IO.puts("------------------------------------------")

if map_size(diff.confidence_deltas) > 0 do
  IO.puts("\nConfidence Changes:")

  Enum.each(diff.confidence_deltas, fn {event_id, delta} ->
    sign = if delta >= 0, do: "+", else: ""
    IO.puts("  Event #{String.slice(event_id, 0..7)}: #{sign}#{Float.round(delta, 3)}")
  end)
else
  IO.puts("No confidence changes detected in modified events")
end

# Example 3: Finding major decision changes
IO.puts("\n\nExample 3: Analyzing Decision Changes")
IO.puts("------------------------------------------")

Enum.each(diff.modified_events, fn {_event_id, changes} ->
  case changes do
    %{decision: {:changed, old, new}} ->
      IO.puts("\nDecision changed:")
      IO.puts("  From: #{old}")
      IO.puts("  To:   #{new}")

    _ ->
      :ok
  end
end)

# Example 4: A/B Testing Analysis
IO.puts("\n\nExample 4: A/B Testing Scenarios")
IO.puts("------------------------------------------")

_scenarios = [
  {"Model A (GPT-4)", chain1},
  {"Model B (Claude)", chain2}
]

IO.puts("\nComparing reasoning approaches between models:")

IO.puts(
  "Model A: #{length(chain1.events)} events, avg confidence: #{Float.round(CrucibleTrace.statistics(chain1).avg_confidence, 2)}"
)

IO.puts(
  "Model B: #{length(chain2.events)} events, avg confidence: #{Float.round(CrucibleTrace.statistics(chain2).avg_confidence, 2)}"
)

cond do
  diff.similarity_score > 0.8 ->
    IO.puts("\n✓ High similarity - models reached similar conclusions")

  diff.similarity_score > 0.5 ->
    IO.puts("\n⚠ Moderate similarity - models took different paths to similar goals")

  true ->
    IO.puts("\n✗ Low similarity - models approached problem very differently")
end

IO.puts("\n=== Chain Comparison Examples Complete ===\n")
