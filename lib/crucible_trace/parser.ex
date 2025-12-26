defmodule CrucibleTrace.Parser do
  @moduledoc """
  Parses causal reasoning events from LLM output.

  Supports XML-style event tags and extracts structured event data from
  LLM-generated text containing decision traces.
  """

  alias CrucibleTrace.{Event, Chain}

  @doc """
  Parses events from LLM output text.

  Expects events in XML-style format:
  ```
  <event type="hypothesis_formed">
    <decision>What you chose</decision>
    <alternatives>Alt1, Alt2</alternatives>
    <reasoning>Why</reasoning>
    <confidence>0.9</confidence>
    <code_section>function_name</code_section>
    <spec_reference>Section 3.2</spec_reference>
  </event>
  ```

  Returns `{:ok, events}` if successful, `{:error, reason}` otherwise.
  """
  def parse(text) when is_binary(text) do
    try do
      events = extract_events(text)
      {:ok, events}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  @doc """
  Parses events and creates a chain with the given name.

  Returns `{:ok, chain}` if successful, `{:error, reason}` otherwise.
  """
  def parse_to_chain(text, chain_name, opts \\ []) do
    case parse(text) do
      {:ok, events} ->
        chain = Chain.new(chain_name, Keyword.put(opts, :events, events))
        {:ok, chain}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Extracts just the code sections from LLM output, removing event tags.

  Returns the cleaned code text.
  """
  def extract_code(text) when is_binary(text) do
    text
    |> String.replace(~r/<event[^>]*>.*?<\/event>/s, "")
    |> String.replace(~r/<code>(.*?)<\/code>/s, "\\1")
    |> String.trim()
  end

  @doc """
  Builds a causal trace prompt that instructs the LLM to emit events.

  Takes a base specification and wraps it with event emission instructions.
  """
  def build_causal_prompt(base_spec) when is_binary(base_spec) do
    """
    #{base_spec}

    IMPORTANT: For each significant decision you make during code generation, output an event tag with your reasoning.

    Use this format for decisions:
    <event type="decision_type">
      <decision>What you chose to implement</decision>
      <alternatives>Alternative 1, Alternative 2, Alternative 3</alternatives>
      <reasoning>Why you chose this approach over the alternatives</reasoning>
      <confidence>0.0-1.0</confidence>
      <code_section>relevant function/module name (optional)</code_section>
      <spec_reference>relevant spec section (optional)</spec_reference>
    </event>

    Event types you can use:
    - hypothesis_formed: When you form an initial approach or solution hypothesis
    - alternative_rejected: When you explicitly reject an alternative approach
    - constraint_evaluated: When you evaluate a constraint or requirement
    - pattern_applied: When you apply a specific design pattern
    - ambiguity_flagged: When you encounter ambiguity in the specification
    - confidence_updated: When your confidence in a decision changes

    After all events, provide your implementation in:
    <code>
    your code here
    </code>

    Ensure you emit events for:
    1. Major architectural decisions
    2. Choice of data structures or algorithms
    3. API design decisions
    4. Error handling strategies
    5. Performance vs. clarity tradeoffs
    """
  end

  # Private functions

  defp extract_events(text) do
    ~r/<event[^>]*type="([^"]+)"[^>]*>(.*?)<\/event>/s
    |> Regex.scan(text)
    |> Enum.map(fn [_full, type, content] ->
      parse_event(type, content)
    end)
  end

  defp parse_event(type_str, content) do
    type = parse_event_type(type_str)
    decision = extract_tag_content(content, "decision")
    alternatives = extract_alternatives(content)
    reasoning = extract_tag_content(content, "reasoning")
    confidence = extract_confidence(content)
    code_section = extract_tag_content(content, "code_section")
    spec_reference = extract_tag_content(content, "spec_reference")

    Event.new(type, decision, reasoning,
      alternatives: alternatives,
      confidence: confidence,
      code_section: code_section,
      spec_reference: spec_reference
    )
  end

  @event_type_map %{
    # Original reasoning event types
    "hypothesis_formed" => :hypothesis_formed,
    "alternative_rejected" => :alternative_rejected,
    "constraint_evaluated" => :constraint_evaluated,
    "pattern_applied" => :pattern_applied,
    "ambiguity_flagged" => :ambiguity_flagged,
    "confidence_updated" => :confidence_updated,
    # Training lifecycle events
    "training_started" => :training_started,
    "training_completed" => :training_completed,
    "epoch_started" => :epoch_started,
    "epoch_completed" => :epoch_completed,
    "batch_processed" => :batch_processed,
    # Metrics events
    "loss_computed" => :loss_computed,
    "metric_recorded" => :metric_recorded,
    "gradient_computed" => :gradient_computed,
    # Checkpoint events
    "checkpoint_saved" => :checkpoint_saved,
    "checkpoint_loaded" => :checkpoint_loaded,
    "early_stopped" => :early_stopped,
    # Deployment events
    "deployment_started" => :deployment_started,
    "model_loaded" => :model_loaded,
    "inference_completed" => :inference_completed,
    "deployment_completed" => :deployment_completed,
    # RL/Feedback events
    "reward_received" => :reward_received,
    "policy_updated" => :policy_updated,
    "experience_sampled" => :experience_sampled,
    # Stage events
    "stage_started" => :stage_started,
    "stage_completed" => :stage_completed
  }

  defp parse_event_type(type_str) do
    type_str
    |> String.trim()
    |> then(&Map.get(@event_type_map, &1, :hypothesis_formed))
  end

  defp extract_tag_content(content, tag) do
    case Regex.run(~r/<#{tag}>(.*?)<\/#{tag}>/s, content) do
      [_, value] -> String.trim(value)
      nil -> ""
    end
  end

  defp extract_alternatives(content) do
    case extract_tag_content(content, "alternatives") do
      "" ->
        []

      alternatives_str ->
        alternatives_str
        |> String.split(~r/,|;/)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  defp extract_confidence(content) do
    case extract_tag_content(content, "confidence") do
      "" ->
        1.0

      conf_str ->
        case Float.parse(conf_str) do
          {num, _} when num >= 0.0 and num <= 1.0 -> num
          {num, _} when num > 1.0 -> 1.0
          {num, _} when num < 0.0 -> 0.0
          _ -> 1.0
        end
    end
  end

  @doc """
  Validates that a text contains properly formatted event tags.

  Returns `{:ok, count}` with the number of valid events found,
  or `{:error, issues}` with a list of issues.
  """
  def validate_events(text) when is_binary(text) do
    issues = []

    # Check for unclosed event tags
    open_tags = Regex.scan(~r/<event[^>]*>/s, text) |> length()
    close_tags = Regex.scan(~r/<\/event>/s, text) |> length()

    issues =
      if open_tags != close_tags do
        ["Mismatched event tags: #{open_tags} open, #{close_tags} close" | issues]
      else
        issues
      end

    # Check each event for required fields
    event_issues =
      ~r/<event[^>]*type="([^"]+)"[^>]*>(.*?)<\/event>/s
      |> Regex.scan(text)
      |> Enum.with_index()
      |> Enum.flat_map(fn {[_full, _type, content], idx} ->
        validate_event_content(content, idx + 1)
      end)

    all_issues = issues ++ event_issues

    if all_issues == [] do
      {:ok, open_tags}
    else
      {:error, all_issues}
    end
  end

  defp validate_event_content(content, event_num) do
    issues = []

    issues =
      if extract_tag_content(content, "decision") == "" do
        ["Event #{event_num}: missing <decision> tag" | issues]
      else
        issues
      end

    issues =
      if extract_tag_content(content, "reasoning") == "" do
        ["Event #{event_num}: missing <reasoning> tag" | issues]
      else
        issues
      end

    issues
  end

  @doc """
  Extracts metadata from LLM output, such as model info or generation params.

  Looks for metadata in comments or special tags.
  """
  def extract_metadata(text) when is_binary(text) do
    metadata = %{}

    # Extract model info if present
    metadata =
      case Regex.run(~r/<!--\s*model:\s*(.+?)\s*-->/i, text) do
        [_, model] -> Map.put(metadata, :model, String.trim(model))
        nil -> metadata
      end

    # Extract timestamp if present
    metadata =
      case Regex.run(~r/<!--\s*timestamp:\s*(.+?)\s*-->/i, text) do
        [_, ts] -> Map.put(metadata, :timestamp, String.trim(ts))
        nil -> metadata
      end

    metadata
  end

  @doc """
  Splits LLM output into events section and code section.

  Returns `{events_text, code_text}`.
  """
  def split_events_and_code(text) when is_binary(text) do
    case Regex.run(~r/<code>(.*?)<\/code>/s, text) do
      [_, code] ->
        events_text = String.replace(text, ~r/<code>.*?<\/code>/s, "")
        {events_text, code}

      nil ->
        {text, ""}
    end
  end
end
