#!/usr/bin/env elixir

# Advanced analysis examples for CrucibleTrace
# Run with: mix run examples/advanced_analysis.exs

IO.puts("\n=== CrucibleTrace Advanced Analysis Examples ===\n")

# Example 1: Complex chain with multiple decision types
IO.puts("Example 1: Building a complex reasoning chain")
IO.puts("-----------------------------------------------")

chain =
  CrucibleTrace.new_chain("E-Commerce Checkout System",
    description: "Designing a fault-tolerant checkout process"
  )

events = [
  CrucibleTrace.create_event(
    :hypothesis_formed,
    "Use Phoenix LiveView for real-time cart updates",
    "Provides reactive UI without complex JavaScript, reduces cognitive load",
    alternatives: ["React SPA", "Traditional forms with AJAX"],
    confidence: 0.85,
    code_section: "CheckoutLive",
    spec_reference: "UI Requirements Section 2.1"
  ),
  CrucibleTrace.create_event(
    :constraint_evaluated,
    "Must support payment processing within 30 seconds",
    "Stripe API has 30s timeout, need to handle async operations properly",
    alternatives: ["Synchronous processing", "Fire and forget"],
    confidence: 0.95,
    spec_reference: "Performance Requirements Section 3.4"
  ),
  CrucibleTrace.create_event(
    :pattern_applied,
    "Implement Saga pattern for distributed transactions",
    "Checkout involves multiple services (inventory, payment, shipping) - need compensation",
    alternatives: ["Two-phase commit", "Manual rollback"],
    confidence: 0.80,
    code_section: "CheckoutSaga"
  ),
  CrucibleTrace.create_event(
    :ambiguity_flagged,
    "Unclear behavior when payment succeeds but inventory reservation fails",
    "Spec doesn't specify if we should refund immediately or retry inventory",
    alternatives: ["Immediate refund", "Retry with exponential backoff", "Manual intervention"],
    confidence: 0.60,
    spec_reference: "Error Handling Section 5.2"
  ),
  CrucibleTrace.create_event(
    :alternative_rejected,
    "Rejected synchronous inventory checks during checkout",
    "Could cause race conditions and overselling, async reservation is safer",
    alternatives: ["Check inventory at cart add time only"],
    confidence: 0.90,
    code_section: "InventoryService"
  ),
  CrucibleTrace.create_event(
    :confidence_updated,
    "Increased confidence in LiveView approach after prototype",
    "Prototype showed 50% reduction in cart abandonment, users like real-time updates",
    confidence: 0.95,
    code_section: "CheckoutLive"
  ),
  CrucibleTrace.create_event(
    :pattern_applied,
    "Use GenStage for order processing pipeline",
    "Need backpressure handling for payment processing during peak loads",
    alternatives: ["Simple Task.async", "Queue with Oban"],
    confidence: 0.75,
    code_section: "OrderPipeline"
  )
]

chain = CrucibleTrace.add_events(chain, events)

IO.puts("Created complex chain: #{chain.name}")
IO.puts("Total events: #{length(chain.events)}")

# Example 2: Comprehensive analysis
IO.puts("\n\nExample 2: Comprehensive chain analysis")
IO.puts("-----------------------------------------------")

stats = CrucibleTrace.statistics(chain)
IO.puts("\nOverall Statistics:")
IO.puts("  Total Events: #{stats.total_events}")
IO.puts("  Average Confidence: #{Float.round(stats.avg_confidence, 3)}")
IO.puts("  Duration: #{stats.duration_seconds} seconds")

IO.puts("\nEvent Type Distribution:")

Enum.each(stats.event_type_counts, fn {type, count} ->
  percentage = Float.round(count / stats.total_events * 100, 1)
  IO.puts("  #{type}: #{count} (#{percentage}%)")
end)

# Example 3: Finding issues and concerns
IO.puts("\n\nExample 3: Identifying potential issues")
IO.puts("-----------------------------------------------")

IO.puts("\n1. Low confidence decisions (< 0.8):")
low_conf = CrucibleTrace.find_low_confidence(chain, 0.8)

if length(low_conf) > 0 do
  Enum.each(low_conf, fn event ->
    IO.puts("   ⚠ #{event.decision}")
    IO.puts("     Confidence: #{event.confidence}")
    IO.puts("     Reasoning: #{event.reasoning}")

    if length(event.alternatives) > 0 do
      IO.puts("     Alternatives: #{Enum.join(event.alternatives, ", ")}")
    end

    IO.puts("")
  end)
else
  IO.puts("   ✓ No low confidence decisions found")
end

IO.puts("\n2. Ambiguities flagged:")
ambiguities = CrucibleTrace.get_events_by_type(chain, :ambiguity_flagged)

if length(ambiguities) > 0 do
  Enum.each(ambiguities, fn event ->
    IO.puts("   🚩 #{event.decision}")
    IO.puts("     Reasoning: #{event.reasoning}")

    if event.spec_reference do
      IO.puts("     Spec Reference: #{event.spec_reference}")
    end

    IO.puts("")
  end)
else
  IO.puts("   ✓ No ambiguities flagged")
end

IO.puts("\n3. Rejected alternatives:")
rejections = CrucibleTrace.get_events_by_type(chain, :alternative_rejected)

if length(rejections) > 0 do
  Enum.each(rejections, fn event ->
    IO.puts("   ❌ #{event.decision}")
    IO.puts("     Reasoning: #{event.reasoning}")
    IO.puts("")
  end)
else
  IO.puts("   No explicit rejections")
end

# Example 4: Decision point analysis
IO.puts("\n\nExample 4: Critical decision points")
IO.puts("-----------------------------------------------")

decision_points = CrucibleTrace.find_decision_points(chain)
IO.puts("\nFound #{length(decision_points)} major decision points:\n")

Enum.with_index(decision_points, 1)
|> Enum.each(fn {decision, idx} ->
  IO.puts("#{idx}. #{decision.decision}")
  IO.puts("   Confidence: #{Float.round(decision.confidence, 2)}")

  if length(decision.alternatives) > 0 do
    IO.puts("   Alternatives considered:")

    Enum.each(decision.alternatives, fn alt ->
      IO.puts("     • #{alt}")
    end)
  end

  IO.puts("   Reasoning: #{decision.reasoning}")
  IO.puts("")
end)

# Example 5: Confidence trend analysis
IO.puts("\n\nExample 5: Confidence trend analysis")
IO.puts("-----------------------------------------------")

sorted_chain = CrucibleTrace.sort_by_timestamp(chain, :asc)

IO.puts("\nConfidence levels over time:")

Enum.with_index(sorted_chain.events, 1)
|> Enum.each(fn {event, idx} ->
  confidence_bar = String.duplicate("█", trunc(event.confidence * 20))

  IO.puts(
    "#{idx}. [#{confidence_bar}] #{Float.round(event.confidence, 2)} - #{String.slice(event.decision, 0, 50)}"
  )
end)

# Calculate confidence trend
first_half = Enum.take(sorted_chain.events, div(length(sorted_chain.events), 2))
second_half = Enum.drop(sorted_chain.events, div(length(sorted_chain.events), 2))

avg_first = Enum.map(first_half, & &1.confidence) |> Enum.sum() |> Kernel./(length(first_half))
avg_second = Enum.map(second_half, & &1.confidence) |> Enum.sum() |> Kernel./(length(second_half))

IO.puts("\nTrend Analysis:")
IO.puts("  Early decisions average: #{Float.round(avg_first, 3)}")
IO.puts("  Later decisions average: #{Float.round(avg_second, 3)}")

if avg_second > avg_first do
  IO.puts("  ↗ Confidence increased over time (good sign)")
else
  IO.puts("  ↘ Confidence decreased over time (may need review)")
end

# Example 6: Export for documentation
IO.puts("\n\nExample 6: Exporting for documentation")
IO.puts("-----------------------------------------------")

# Save chain
case CrucibleTrace.save(chain, storage_dir: "example_traces") do
  {:ok, path} ->
    IO.puts("✓ Saved chain to: #{path}")

  {:error, reason} ->
    IO.puts("✗ Failed to save: #{inspect(reason)}")
end

# Export to markdown for documentation
case CrucibleTrace.export(chain, :markdown) do
  {:ok, markdown} ->
    markdown_file = "example_traces/checkout_analysis.md"
    File.write!(markdown_file, markdown)
    IO.puts("✓ Exported markdown to: #{markdown_file}")

  {:error, reason} ->
    IO.puts("✗ Failed to export markdown: #{reason}")
end

# Export to CSV for spreadsheet analysis
case CrucibleTrace.export(chain, :csv) do
  {:ok, csv} ->
    csv_file = "example_traces/checkout_analysis.csv"
    File.write!(csv_file, csv)
    IO.puts("✓ Exported CSV to: #{csv_file}")

  {:error, reason} ->
    IO.puts("✗ Failed to export CSV: #{reason}")
end

# Example 7: Filtering and custom analysis
IO.puts("\n\nExample 7: Custom filtering and analysis")
IO.puts("-----------------------------------------------")

# Find all high-confidence architectural decisions
architectural_decisions =
  CrucibleTrace.filter_events(chain, fn event ->
    event.confidence >= 0.85 and event.type in [:hypothesis_formed, :pattern_applied]
  end)

IO.puts("\nHigh-confidence architectural decisions:")

Enum.each(architectural_decisions.events, fn event ->
  IO.puts("  • #{event.decision} (#{event.confidence})")
  IO.puts("    Type: #{event.type}")

  if event.code_section do
    IO.puts("    Code: #{event.code_section}")
  end

  IO.puts("")
end)

# Find decisions that need stakeholder review
needs_review =
  CrucibleTrace.filter_events(chain, fn event ->
    event.confidence < 0.75 or event.type == :ambiguity_flagged
  end)

IO.puts("\nDecisions requiring stakeholder review:")

if length(needs_review.events) > 0 do
  Enum.each(needs_review.events, fn event ->
    IO.puts("  ⚠ #{event.decision}")

    IO.puts(
      "    Reason: #{if event.type == :ambiguity_flagged, do: "Ambiguity in spec", else: "Low confidence"}"
    )

    if event.spec_reference do
      IO.puts("    See: #{event.spec_reference}")
    end

    IO.puts("")
  end)
else
  IO.puts("  ✓ No decisions need review")
end

# Example 8: Generate visualization
IO.puts("\n\nExample 8: Creating visualization")
IO.puts("-----------------------------------------------")

html_file = "example_traces/checkout_visualization.html"

case CrucibleTrace.save_visualization(chain, html_file, style: :light) do
  {:ok, path} ->
    IO.puts("✓ Saved interactive visualization to: #{path}")
    IO.puts("  Open this file in a browser to explore the reasoning chain interactively")

  {:error, reason} ->
    IO.puts("✗ Failed to save visualization: #{inspect(reason)}")
end

# Example 9: Comparing alternatives across the chain
IO.puts("\n\nExample 9: Alternative analysis")
IO.puts("-----------------------------------------------")

all_alternatives =
  chain.events
  |> Enum.flat_map(fn event ->
    Enum.map(event.alternatives, fn alt ->
      %{alternative: alt, decision: event.decision, confidence: event.confidence}
    end)
  end)

IO.puts("\nAll alternatives considered (#{length(all_alternatives)} total):")

all_alternatives
|> Enum.group_by(& &1.alternative)
|> Enum.sort_by(fn {_alt, occurrences} -> length(occurrences) end, :desc)
|> Enum.take(5)
|> Enum.each(fn {alternative, occurrences} ->
  IO.puts("  #{alternative}: rejected #{length(occurrences)} time(s)")

  Enum.each(occurrences, fn occ ->
    IO.puts(
      "    - In favor of: #{String.slice(occ.decision, 0, 60)}#{if String.length(occ.decision) > 60, do: "...", else: ""}"
    )
  end)
end)

IO.puts("\n=== Advanced analysis completed ===\n")
