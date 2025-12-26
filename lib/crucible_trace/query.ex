defmodule CrucibleTrace.Query do
  @moduledoc """
  Advanced querying capabilities for trace chains.

  Supports full-text search, regex matching, and boolean queries.
  """

  alias CrucibleTrace.{Chain, Event}

  @doc """
  Searches events by content across decision and reasoning fields.

  ## Options
  - :type - Filter by event type(s) (atom or list of atoms)
  - :min_confidence - Minimum confidence threshold
  - :max_confidence - Maximum confidence threshold
  - :since - Only events after this datetime
  - :until - Only events before this datetime
  - :stage_id - Filter by stage ID
  - :experiment_id - Filter by experiment ID
  """
  @spec search_events(Chain.t(), String.t(), keyword()) :: [Event.t()]
  def search_events(%Chain{} = chain, content, opts \\ []) when is_binary(content) do
    chain.events
    |> filter_by_content(content)
    |> apply_filters(opts)
  end

  @doc """
  Searches with regex pattern.

  ## Options
  Same as `search_events/3`.
  """
  @spec search_regex(Chain.t(), Regex.t(), keyword()) :: [Event.t()]
  def search_regex(%Chain{} = chain, pattern, opts \\ []) do
    chain.events
    |> filter_by_regex(pattern)
    |> apply_filters(opts)
  end

  @doc """
  Advanced query with boolean logic.

  ## Query Format
  ```
  %{
    or: [
      %{content: ~r/pattern/i, confidence: {:gte, 0.8}},
      %{type: :ambiguity_flagged}
    ],
    and: [
      %{stage_id: "training"}
    ]
  }
  ```

  ## Supported conditions
  - :type - Event type atom
  - :content - String or Regex for decision/reasoning
  - :confidence - Tuple like {:gte, 0.8}, {:lt, 0.5}, {:eq, 1.0}
  - :stage_id - Stage ID string
  - :experiment_id - Experiment ID string
  """
  @spec query(Chain.t(), map()) :: [Event.t()]
  def query(%Chain{} = chain, query_map) when is_map(query_map) do
    chain.events
    |> Enum.filter(fn event -> matches_query?(event, query_map) end)
  end

  @doc """
  Aggregates events by a field.

  ## Examples

      # Count events by type
      Query.aggregate_by(chain, :type, &length/1)

      # Average confidence by stage
      Query.aggregate_by(chain, :stage_id, fn events ->
        Enum.reduce(events, 0, &(&1.confidence + &2)) / length(events)
      end)
  """
  @spec aggregate_by(Chain.t(), atom(), ([Event.t()] -> any())) :: map()
  def aggregate_by(%Chain{events: events}, field, aggregation_fn)
      when is_atom(field) and is_function(aggregation_fn, 1) do
    events
    |> Enum.group_by(&Map.get(&1, field))
    |> Enum.reject(fn {k, _v} -> is_nil(k) end)
    |> Enum.map(fn {key, group} -> {key, aggregation_fn.(group)} end)
    |> Map.new()
  end

  # Private functions

  defp filter_by_content(events, "") do
    events
  end

  defp filter_by_content(events, content) do
    content_downcase = String.downcase(content)

    Enum.filter(events, fn event ->
      decision_downcase = String.downcase(event.decision || "")
      reasoning_downcase = String.downcase(event.reasoning || "")

      String.contains?(decision_downcase, content_downcase) or
        String.contains?(reasoning_downcase, content_downcase)
    end)
  end

  defp filter_by_regex(events, pattern) do
    Enum.filter(events, fn event ->
      Regex.match?(pattern, event.decision || "") or
        Regex.match?(pattern, event.reasoning || "")
    end)
  end

  defp apply_filters(events, opts) do
    events
    |> filter_by_type(Keyword.get(opts, :type))
    |> filter_by_confidence(
      Keyword.get(opts, :min_confidence),
      Keyword.get(opts, :max_confidence)
    )
    |> filter_by_time(Keyword.get(opts, :since), Keyword.get(opts, :until))
    |> filter_by_stage(Keyword.get(opts, :stage_id))
    |> filter_by_experiment(Keyword.get(opts, :experiment_id))
  end

  defp filter_by_type(events, nil), do: events

  defp filter_by_type(events, types) when is_list(types) do
    Enum.filter(events, &(&1.type in types))
  end

  defp filter_by_type(events, type) when is_atom(type) do
    Enum.filter(events, &(&1.type == type))
  end

  defp filter_by_confidence(events, nil, nil), do: events

  defp filter_by_confidence(events, min, nil) do
    Enum.filter(events, &(&1.confidence >= min))
  end

  defp filter_by_confidence(events, nil, max) do
    Enum.filter(events, &(&1.confidence <= max))
  end

  defp filter_by_confidence(events, min, max) do
    Enum.filter(events, &(&1.confidence >= min and &1.confidence <= max))
  end

  defp filter_by_time(events, nil, nil), do: events

  defp filter_by_time(events, since, nil) do
    Enum.filter(events, fn event ->
      DateTime.compare(event.timestamp, since) in [:gt, :eq]
    end)
  end

  defp filter_by_time(events, nil, until_time) do
    Enum.filter(events, fn event ->
      DateTime.compare(event.timestamp, until_time) in [:lt, :eq]
    end)
  end

  defp filter_by_time(events, since, until_time) do
    Enum.filter(events, fn event ->
      DateTime.compare(event.timestamp, since) in [:gt, :eq] and
        DateTime.compare(event.timestamp, until_time) in [:lt, :eq]
    end)
  end

  defp filter_by_stage(events, nil), do: events

  defp filter_by_stage(events, stage_id) do
    Enum.filter(events, &(&1.stage_id == stage_id))
  end

  defp filter_by_experiment(events, nil), do: events

  defp filter_by_experiment(events, experiment_id) do
    Enum.filter(events, &(&1.experiment_id == experiment_id))
  end

  # Query matching logic

  defp matches_query?(event, query_map) do
    and_conditions = Map.get(query_map, :and, [])
    or_conditions = Map.get(query_map, :or, [])

    # Direct conditions in the map (not under :and or :or)
    direct_conditions =
      query_map
      |> Map.drop([:and, :or])

    direct_match =
      if map_size(direct_conditions) == 0 do
        true
      else
        matches_condition?(event, direct_conditions)
      end

    and_match =
      if Enum.empty?(and_conditions) do
        true
      else
        Enum.all?(and_conditions, &matches_condition?(event, &1))
      end

    or_match =
      if Enum.empty?(or_conditions) do
        true
      else
        Enum.any?(or_conditions, &matches_condition?(event, &1))
      end

    direct_match and and_match and or_match
  end

  defp matches_condition?(event, condition) when is_map(condition) do
    Enum.all?(condition, fn {key, value} ->
      matches_field?(event, key, value)
    end)
  end

  defp matches_field?(event, :type, type) when is_atom(type) do
    event.type == type
  end

  defp matches_field?(event, :content, %Regex{} = pattern) do
    Regex.match?(pattern, event.decision || "") or
      Regex.match?(pattern, event.reasoning || "")
  end

  defp matches_field?(event, :content, content) when is_binary(content) do
    content_downcase = String.downcase(content)

    String.contains?(String.downcase(event.decision || ""), content_downcase) or
      String.contains?(String.downcase(event.reasoning || ""), content_downcase)
  end

  defp matches_field?(event, :confidence, {:gte, value}) do
    event.confidence >= value
  end

  defp matches_field?(event, :confidence, {:gt, value}) do
    event.confidence > value
  end

  defp matches_field?(event, :confidence, {:lte, value}) do
    event.confidence <= value
  end

  defp matches_field?(event, :confidence, {:lt, value}) do
    event.confidence < value
  end

  defp matches_field?(event, :confidence, {:eq, value}) do
    event.confidence == value
  end

  defp matches_field?(event, :stage_id, stage_id) do
    event.stage_id == stage_id
  end

  defp matches_field?(event, :experiment_id, experiment_id) do
    event.experiment_id == experiment_id
  end

  defp matches_field?(_event, _key, _value) do
    # Unknown field, ignore
    true
  end
end
