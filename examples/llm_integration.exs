#!/usr/bin/env elixir

# LLM Integration examples for CrucibleTrace
# Run with: mix run examples/llm_integration.exs

IO.puts("\n=== CrucibleTrace LLM Integration Examples ===\n")

# Example 1: Parsing realistic LLM output
IO.puts("Example 1: Parsing LLM-generated reasoning")
IO.puts("-----------------------------------------------")

llm_response = """
I'll design a distributed caching system for your API. Here's my reasoning:

<event type="hypothesis_formed">
  <decision>Use Redis as the distributed cache backend</decision>
  <alternatives>Memcached, Hazelcast, In-memory ETS</alternatives>
  <reasoning>Redis provides persistence, pub/sub for cache invalidation, and rich data structures. Memcached is simpler but lacks persistence. Hazelcast has JVM overhead. ETS is local-only.</reasoning>
  <confidence>0.88</confidence>
  <code_section>CacheBackend</code_section>
  <spec_reference>Section 4.1: Cache Requirements</spec_reference>
</event>

<event type="pattern_applied">
  <decision>Implement Cache-Aside pattern with TTL</decision>
  <reasoning>Cache-Aside gives application control over what to cache and when. TTL prevents stale data. Write-through would add latency to writes.</reasoning>
  <confidence>0.92</confidence>
  <code_section>CacheStrategy</code_section>
</event>

<event type="constraint_evaluated">
  <decision>Set default TTL to 5 minutes for user data</decision>
  <alternatives>1 minute, 15 minutes, No expiration</alternatives>
  <reasoning>Balance between freshness and cache hit rate. User data changes moderately. 5 minutes gives good hit rate without significant staleness.</reasoning>
  <confidence>0.75</confidence>
  <spec_reference>Section 4.3: Data Freshness</spec_reference>
</event>

<event type="ambiguity_flagged">
  <decision>Unclear cache invalidation strategy for related entities</decision>
  <alternatives>Tag-based invalidation, Invalidate by pattern, Manual invalidation</alternatives>
  <reasoning>Spec doesn't specify if updating a user should invalidate their posts cache. Need clarification on cache dependency graph.</reasoning>
  <confidence>0.60</confidence>
  <spec_reference>Section 4.4: Cache Invalidation</spec_reference>
</event>

<event type="pattern_applied">
  <decision>Use connection pooling with Redix library</decision>
  <reasoning>Redix is maintained, supports pipelining, and integrates well with Elixir's supervision tree. Connection pool prevents connection exhaustion.</reasoning>
  <confidence>0.90</confidence>
  <code_section>RedixPool</code_section>
</event>

<code>
defmodule MyApp.Cache do
  @moduledoc \"\"\"
  Distributed caching layer using Redis with Cache-Aside pattern.
  \"\"\"

  alias MyApp.RedixPool

  @default_ttl 300 # 5 minutes

  @doc \"\"\"
  Fetches a value from cache or computes it using the provided function.
  \"\"\"
  def fetch(key, opts \\\\ [], compute_fn) when is_function(compute_fn, 0) do
    case get(key) do
      {:ok, value} ->
        {:ok, value}

      {:error, :not_found} ->
        value = compute_fn.()
        ttl = Keyword.get(opts, :ttl, @default_ttl)
        put(key, value, ttl)
        {:ok, value}
    end
  end

  @doc \"\"\"
  Gets a value from the cache.
  \"\"\"
  def get(key) do
    case Redix.command(RedixPool, ["GET", key]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, value} -> {:ok, deserialize(value)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc \"\"\"
  Puts a value in the cache with TTL.
  \"\"\"
  def put(key, value, ttl) do
    serialized = serialize(value)
    Redix.command(RedixPool, ["SETEX", key, ttl, serialized])
  end

  @doc \"\"\"
  Invalidates a cache entry.
  \"\"\"
  def invalidate(key) do
    Redix.command(RedixPool, ["DEL", key])
  end

  defp serialize(value), do: :erlang.term_to_binary(value)
  defp deserialize(binary), do: :erlang.binary_to_term(binary)
end
</code>

Based on this implementation, the system provides:
- Fast distributed caching with Redis
- Automatic cache population on miss
- Configurable TTLs per cache entry
- Safe serialization of Elixir terms
"""

case CrucibleTrace.parse_llm_output(llm_response, "Distributed Cache Design") do
  {:ok, chain} ->
    IO.puts("✓ Successfully parsed LLM output")
    IO.puts("  Chain: #{chain.name}")
    IO.puts("  Events found: #{length(chain.events)}")

    # Show statistics
    stats = CrucibleTrace.statistics(chain)
    IO.puts("\n  Statistics:")
    IO.puts("    Average confidence: #{Float.round(stats.avg_confidence, 2)}")
    IO.puts("    Event types: #{map_size(stats.event_type_counts)}")

    # Save the chain
    case CrucibleTrace.save(chain, storage_dir: "example_traces") do
      {:ok, path} ->
        IO.puts("\n✓ Saved chain to: #{path}")

      {:error, reason} ->
        IO.puts("\n✗ Failed to save: #{inspect(reason)}")
    end

    # Extract clean code
    code = CrucibleTrace.extract_code(llm_response)
    IO.puts("\n✓ Extracted clean code (#{String.length(code)} characters)")
    IO.puts("  Code preview:")
    IO.puts("  " <> (String.split(code, "\n") |> Enum.take(5) |> Enum.join("\n  ")))
    IO.puts("  ...")

  {:error, reason} ->
    IO.puts("✗ Failed to parse: #{reason}")
end

# Example 2: Building prompts for LLMs
IO.puts("\n\nExample 2: Building causal trace prompts")
IO.puts("-----------------------------------------------")

base_specification = """
Design and implement a WebSocket-based notification system with the following requirements:

Functional Requirements:
- Real-time notifications for users
- Support for multiple notification types (info, warning, error)
- Notifications should be persisted
- Users can mark notifications as read
- Support for notification preferences (opt-in/opt-out by type)

Non-Functional Requirements:
- Must scale to 100,000 concurrent connections
- Maximum latency of 100ms for notification delivery
- 99.9% uptime SLA
- Notifications must not be lost even if user is offline

Technical Constraints:
- Must use Elixir/Phoenix
- Database: PostgreSQL
- Deploy on Kubernetes cluster
"""

enhanced_prompt = CrucibleTrace.build_causal_prompt(base_specification)

IO.puts("✓ Generated enhanced prompt with causal trace instructions")
IO.puts("  Original spec: #{String.length(base_specification)} characters")
IO.puts("  Enhanced prompt: #{String.length(enhanced_prompt)} characters")

IO.puts(
  "  Added: #{String.length(enhanced_prompt) - String.length(base_specification)} characters of guidance"
)

IO.puts("\n  Prompt structure preview:")
IO.puts("  - Original specification")
IO.puts("  - Event emission instructions")
IO.puts("  - Event type descriptions")
IO.puts("  - Best practices guidance")

# Save the prompt for use with LLM
prompt_file = "example_traces/notification_system_prompt.txt"
File.write!(prompt_file, enhanced_prompt)
IO.puts("\n✓ Saved prompt to: #{prompt_file}")
IO.puts("  Ready to use with your LLM API")

# Example 3: Validating LLM output
IO.puts("\n\nExample 3: Validating LLM responses")
IO.puts("-----------------------------------------------")

# Valid output
valid_output = """
<event type="hypothesis_formed">
  <decision>Use Phoenix PubSub for notification distribution</decision>
  <alternatives>Redis Streams, RabbitMQ</alternatives>
  <reasoning>Phoenix PubSub is built-in, handles clustering well, and integrates seamlessly</reasoning>
  <confidence>0.9</confidence>
</event>
"""

# Invalid output - missing required fields
invalid_output = """
<event type="hypothesis_formed">
  <decision>Use Phoenix PubSub</decision>
  <confidence>0.9</confidence>
</event>
"""

IO.puts("Validating correct LLM output...")

case CrucibleTrace.validate_events(valid_output) do
  {:ok, count} ->
    IO.puts("  ✓ Valid! Found #{count} properly formatted event(s)")

  {:error, issues} ->
    IO.puts("  ✗ Issues found:")
    Enum.each(issues, fn issue -> IO.puts("    - #{issue}") end)
end

IO.puts("\nValidating incomplete LLM output...")

case CrucibleTrace.validate_events(invalid_output) do
  {:ok, count} ->
    IO.puts("  ✓ Valid! Found #{count} event(s)")

  {:error, issues} ->
    IO.puts("  ✗ Issues found:")
    Enum.each(issues, fn issue -> IO.puts("    - #{issue}") end)
end

# Example 4: Multi-round conversation tracking
IO.puts("\n\nExample 4: Multi-round conversation tracking")
IO.puts("-----------------------------------------------")

# First LLM response
first_response = """
<event type="hypothesis_formed">
  <decision>Implement notification system with Phoenix Channels</decision>
  <alternatives>WebSockets directly, Server-Sent Events</alternatives>
  <reasoning>Phoenix Channels provide high-level abstraction over WebSockets with presence tracking</reasoning>
  <confidence>0.85</confidence>
  <code_section>NotificationChannel</code_section>
</event>
"""

{:ok, chain1} = CrucibleTrace.parse_llm_output(first_response, "Notification System - Round 1")
IO.puts("Round 1: #{length(chain1.events)} event(s) captured")

# Second LLM response (refinement)
second_response = """
<event type="confidence_updated">
  <decision>Increased confidence in Phoenix Channels after prototype testing</decision>
  <reasoning>Prototype handled 50K concurrent connections with 40ms average latency, well within requirements</reasoning>
  <confidence>0.95</confidence>
  <code_section>NotificationChannel</code_section>
</event>

<event type="pattern_applied">
  <decision>Use GenStage for notification pipeline with backpressure</decision>
  <alternatives>Simple Task.async, Broadway</alternatives>
  <reasoning>GenStage provides backpressure to prevent overwhelming the database during spikes. Broadway would be overkill.</reasoning>
  <confidence>0.88</confidence>
  <code_section>NotificationPipeline</code_section>
</event>
"""

{:ok, chain2} = CrucibleTrace.parse_llm_output(second_response, "Notification System - Round 2")
IO.puts("Round 2: #{length(chain2.events)} event(s) captured")

# Merge the chains to track the complete conversation
merged_chain = CrucibleTrace.merge_chains(chain1, chain2)
IO.puts("\nMerged chain: #{length(merged_chain.events)} total event(s)")

# Analyze the evolution
sorted = CrucibleTrace.sort_by_timestamp(merged_chain, :asc)
IO.puts("\nDecision evolution:")

Enum.with_index(sorted.events, 1)
|> Enum.each(fn {event, idx} ->
  IO.puts("  #{idx}. [#{event.type}] #{event.decision}")
  IO.puts("     Confidence: #{event.confidence}")
end)

# Save merged conversation
case CrucibleTrace.save(merged_chain, storage_dir: "example_traces") do
  {:ok, path} ->
    IO.puts("\n✓ Saved complete conversation chain to: #{path}")

  {:error, reason} ->
    IO.puts("\n✗ Failed to save: #{inspect(reason)}")
end

# Example 5: Quality assurance for LLM outputs
IO.puts("\n\nExample 5: Quality assurance checks")
IO.puts("-----------------------------------------------")

defmodule QualityCheck do
  def check_chain(chain) do
    checks = [
      check_minimum_events(chain),
      check_average_confidence(chain),
      check_required_sections(chain),
      check_ambiguities(chain)
    ]

    passed = Enum.count(checks, fn {status, _} -> status == :ok end)
    total = length(checks)

    IO.puts("\nQuality Check Results: #{passed}/#{total} passed\n")

    Enum.each(checks, fn {status, message} ->
      icon = if status == :ok, do: "✓", else: "✗"
      IO.puts("  #{icon} #{message}")
    end)

    if passed == total, do: :ok, else: :warning
  end

  defp check_minimum_events(chain) do
    if length(chain.events) >= 3 do
      {:ok, "Has sufficient reasoning events (#{length(chain.events)})"}
    else
      {:warning, "Insufficient reasoning events (#{length(chain.events)} < 3)"}
    end
  end

  defp check_average_confidence(chain) do
    stats = CrucibleTrace.statistics(chain)
    avg_conf = stats[:avg_confidence] || 0.0

    if avg_conf >= 0.8 do
      {:ok, "Average confidence is good (#{Float.round(avg_conf, 2)})"}
    else
      {:warning, "Average confidence is low (#{Float.round(avg_conf, 2)})"}
    end
  end

  defp check_required_sections(chain) do
    has_hypothesis = Enum.any?(chain.events, &(&1.type == :hypothesis_formed))

    if has_hypothesis do
      {:ok, "Contains hypothesis formation"}
    else
      {:warning, "Missing hypothesis formation"}
    end
  end

  defp check_ambiguities(chain) do
    ambiguities = Enum.count(chain.events, &(&1.type == :ambiguity_flagged))

    cond do
      ambiguities == 0 ->
        {:ok, "No unresolved ambiguities"}

      ambiguities <= 2 ->
        {:warning, "#{ambiguities} ambiguity(ies) flagged - needs review"}

      true ->
        {:error, "Too many ambiguities (#{ambiguities}) - major issues"}
    end
  end
end

IO.puts("Running quality checks on merged chain...")
QualityCheck.check_chain(merged_chain)

IO.puts("\n=== LLM integration examples completed ===\n")
