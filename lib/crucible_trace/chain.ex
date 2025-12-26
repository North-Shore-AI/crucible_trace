defmodule CrucibleTrace.Chain do
  @moduledoc """
  Manages a collection of causal reasoning events forming a decision chain.

  A chain represents the complete reasoning trace for a single code generation task,
  containing all decisions, alternatives, and reasoning steps taken by the LLM.
  """

  alias CrucibleTrace.Event

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          events: [Event.t()],
          metadata: map(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @enforce_keys [:id, :name]
  defstruct [
    :id,
    :name,
    description: nil,
    events: [],
    metadata: %{},
    created_at: nil,
    updated_at: nil
  ]

  @doc """
  Creates a new chain with the given name and options.

  ## Examples

      iex> CrucibleTrace.Chain.new("API Endpoint Implementation")
      %CrucibleTrace.Chain{name: "API Endpoint Implementation"}
  """
  def new(name, opts \\ []) do
    now = DateTime.utc_now()

    %__MODULE__{
      id: generate_id(),
      name: name,
      description: Keyword.get(opts, :description),
      events: Keyword.get(opts, :events, []),
      metadata: Keyword.get(opts, :metadata, %{}),
      created_at: now,
      updated_at: now
    }
  end

  @doc """
  Adds an event to the chain.

  Returns the updated chain with the event appended.
  """
  def add_event(%__MODULE__{} = chain, %Event{} = event) do
    %{chain | events: chain.events ++ [event], updated_at: DateTime.utc_now()}
  end

  @doc """
  Adds multiple events to the chain.
  """
  def add_events(%__MODULE__{} = chain, events) when is_list(events) do
    Enum.reduce(events, chain, fn event, acc -> add_event(acc, event) end)
  end

  @doc """
  Gets an event by ID from the chain.

  Returns `{:ok, event}` if found, `:error` otherwise.
  """
  def get_event(%__MODULE__{} = chain, event_id) do
    case Enum.find(chain.events, &(&1.id == event_id)) do
      nil -> :error
      event -> {:ok, event}
    end
  end

  @doc """
  Gets all events of a specific type from the chain.
  """
  def get_events_by_type(%__MODULE__{} = chain, type) do
    Enum.filter(chain.events, &(&1.type == type))
  end

  @doc """
  Gets events within a time range.
  """
  def get_events_in_range(%__MODULE__{} = chain, start_time, end_time) do
    Enum.filter(chain.events, fn event ->
      DateTime.compare(event.timestamp, start_time) in [:gt, :eq] and
        DateTime.compare(event.timestamp, end_time) in [:lt, :eq]
    end)
  end

  @doc """
  Calculates statistics about the chain.

  Returns a map with:
  - total_events: total number of events
  - event_type_counts: count per event type
  - avg_confidence: average confidence across all events
  - duration_seconds: time from first to last event
  """
  def statistics(%__MODULE__{events: []}), do: %{total_events: 0}

  def statistics(%__MODULE__{events: events}) do
    event_type_counts =
      events
      |> Enum.group_by(& &1.type)
      |> Enum.map(fn {type, events} -> {type, length(events)} end)
      |> Map.new()

    avg_confidence =
      events
      |> Enum.map(& &1.confidence)
      |> average()

    duration_seconds =
      if length(events) > 1 do
        first = List.first(events)
        last = List.last(events)
        DateTime.diff(last.timestamp, first.timestamp, :second)
      else
        0
      end

    %{
      total_events: length(events),
      event_type_counts: event_type_counts,
      avg_confidence: avg_confidence,
      duration_seconds: duration_seconds
    }
  end

  @doc """
  Finds decision points where alternatives were rejected.

  Returns events of type :alternative_rejected with their associated decisions.
  """
  def find_decision_points(%__MODULE__{} = chain) do
    chain.events
    |> Enum.filter(&(&1.type in [:alternative_rejected, :hypothesis_formed]))
    |> Enum.map(fn event ->
      %{
        decision: event.decision,
        alternatives: event.alternatives,
        reasoning: event.reasoning,
        confidence: event.confidence,
        timestamp: event.timestamp
      }
    end)
  end

  @doc """
  Finds low confidence decisions (below threshold).
  """
  def find_low_confidence(%__MODULE__{} = chain, threshold \\ 0.7) do
    Enum.filter(chain.events, &(&1.confidence < threshold))
  end

  @doc """
  Converts the chain to a map suitable for JSON encoding.
  """
  def to_map(%__MODULE__{} = chain) do
    %{
      id: chain.id,
      name: chain.name,
      description: chain.description,
      events: Enum.map(chain.events, &Event.to_map/1),
      metadata: chain.metadata,
      created_at: DateTime.to_iso8601(chain.created_at),
      updated_at: DateTime.to_iso8601(chain.updated_at),
      statistics: statistics(chain)
    }
  end

  @doc """
  Creates a chain from a map (e.g., from JSON parsing).
  """
  def from_map(map) when is_map(map) do
    events =
      (Map.get(map, "events") || Map.get(map, :events, []))
      |> Enum.map(&Event.from_map/1)

    %__MODULE__{
      id: Map.get(map, "id") || Map.get(map, :id) || generate_id(),
      name: Map.get(map, "name") || Map.get(map, :name),
      description: Map.get(map, "description") || Map.get(map, :description),
      events: events,
      metadata: Map.get(map, "metadata") || Map.get(map, :metadata, %{}),
      created_at: parse_timestamp(Map.get(map, "created_at") || Map.get(map, :created_at)),
      updated_at: parse_timestamp(Map.get(map, "updated_at") || Map.get(map, :updated_at))
    }
  end

  @doc """
  Merges two chains together, combining their events.
  """
  def merge(%__MODULE__{} = chain1, %__MODULE__{} = chain2) do
    %{
      chain1
      | events: chain1.events ++ chain2.events,
        updated_at: DateTime.utc_now(),
        metadata: Map.merge(chain1.metadata, chain2.metadata)
    }
  end

  @doc """
  Filters events in a chain based on a predicate function.
  """
  def filter_events(%__MODULE__{} = chain, predicate_fn) when is_function(predicate_fn, 1) do
    %{chain | events: Enum.filter(chain.events, predicate_fn)}
  end

  @doc """
  Sorts events in a chain by timestamp.
  """
  def sort_by_timestamp(%__MODULE__{} = chain, order \\ :asc) do
    sorted_events =
      case order do
        :asc -> Enum.sort_by(chain.events, & &1.timestamp, DateTime)
        :desc -> Enum.sort_by(chain.events, & &1.timestamp, {:desc, DateTime})
      end

    %{chain | events: sorted_events}
  end

  # Private helpers

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp parse_timestamp(nil), do: DateTime.utc_now()
  defp parse_timestamp(%DateTime{} = dt), do: dt

  defp parse_timestamp(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp average([]), do: 0.0

  defp average(list) do
    sum = Enum.sum(list)
    sum / length(list)
  end

  # Relationship Functions

  @doc """
  Gets child events of a given event.

  Returns `{:ok, children}` with the list of child events,
  or `{:error, reason}` if the parent event is not found.
  """
  @spec get_children(t(), String.t()) :: {:ok, [Event.t()]} | {:error, String.t()}
  def get_children(%__MODULE__{} = chain, event_id) do
    case get_event(chain, event_id) do
      {:ok, _event} ->
        children = Enum.filter(chain.events, &(&1.parent_id == event_id))
        {:ok, children}

      :error ->
        {:error, "Event not found: #{event_id}"}
    end
  end

  @doc """
  Gets the parent event of a given event.

  Returns `{:ok, parent}` where parent is the parent event or nil if no parent,
  or `{:error, reason}` if the event is not found.
  """
  @spec get_parent(t(), String.t()) :: {:ok, Event.t() | nil} | {:error, String.t()}
  def get_parent(%__MODULE__{} = chain, event_id) do
    case get_event(chain, event_id) do
      {:ok, event} -> find_parent_event(chain, event.parent_id)
      :error -> {:error, "Event not found: #{event_id}"}
    end
  end

  defp find_parent_event(_chain, nil), do: {:ok, nil}

  defp find_parent_event(chain, parent_id) do
    case get_event(chain, parent_id) do
      {:ok, parent} -> {:ok, parent}
      :error -> {:ok, nil}
    end
  end

  @doc """
  Gets root events (events with no parent).
  """
  @spec get_root_events(t()) :: [Event.t()]
  def get_root_events(%__MODULE__{} = chain) do
    Enum.filter(chain.events, &is_nil(&1.parent_id))
  end

  @doc """
  Gets leaf events (events with no children).
  """
  @spec get_leaf_events(t()) :: [Event.t()]
  def get_leaf_events(%__MODULE__{} = chain) do
    parent_ids =
      chain.events |> Enum.map(& &1.parent_id) |> Enum.reject(&is_nil/1) |> MapSet.new()

    Enum.reject(chain.events, &MapSet.member?(parent_ids, &1.id))
  end

  @doc """
  Validates that no circular dependencies exist in the chain.

  Returns `{:ok, chain}` if valid, `{:error, reason}` otherwise.
  """
  @spec validate_relationships(t()) :: {:ok, t()} | {:error, String.t()}
  def validate_relationships(%__MODULE__{events: []} = chain), do: {:ok, chain}

  def validate_relationships(%__MODULE__{} = chain) do
    event_ids = chain.events |> Enum.map(& &1.id) |> MapSet.new()

    # Check for missing references
    with :ok <- validate_parent_references(chain, event_ids),
         :ok <- validate_depends_on_references(chain, event_ids),
         :ok <- validate_no_cycles(chain) do
      {:ok, chain}
    end
  end

  defp validate_parent_references(chain, event_ids) do
    invalid =
      Enum.find(chain.events, fn event ->
        event.parent_id != nil and not MapSet.member?(event_ids, event.parent_id)
      end)

    if invalid do
      {:error, "Parent event not found: #{invalid.parent_id}"}
    else
      :ok
    end
  end

  defp validate_depends_on_references(chain, event_ids) do
    invalid =
      Enum.find(chain.events, fn event ->
        Enum.any?(event.depends_on, fn dep_id ->
          not MapSet.member?(event_ids, dep_id)
        end)
      end)

    if invalid do
      {:error, "Dependency event not found in depends_on list"}
    else
      :ok
    end
  end

  defp validate_no_cycles(%__MODULE__{} = chain) do
    # Build adjacency list from parent_id and depends_on
    adjacency =
      Enum.reduce(chain.events, %{}, fn event, acc ->
        deps =
          if event.parent_id do
            [event.parent_id | event.depends_on]
          else
            event.depends_on
          end

        Map.put(acc, event.id, deps)
      end)

    # Check for cycles using DFS
    event_ids = Map.keys(adjacency)

    result =
      Enum.reduce_while(event_ids, %{}, fn id, visited ->
        case detect_cycle(id, adjacency, visited, %{}) do
          {:cycle, _} -> {:halt, {:error, "Circular dependency detected"}}
          {:ok, new_visited} -> {:cont, new_visited}
        end
      end)

    case result do
      {:error, _} = error -> error
      _ -> :ok
    end
  end

  @spec detect_cycle(any(), map(), map(), map()) ::
          {:cycle, any()} | {:ok, map()}
  defp detect_cycle(node, adjacency, visited, current_path) do
    cond do
      Map.has_key?(current_path, node) ->
        {:cycle, node}

      Map.get(visited, node) == :done ->
        {:ok, visited}

      true ->
        traverse_dependencies(node, adjacency, visited, current_path)
    end
  end

  defp traverse_dependencies(node, adjacency, visited, current_path) do
    new_path = Map.put(current_path, node, true)
    deps = Map.get(adjacency, node, [])

    result =
      Enum.reduce_while(deps, visited, fn dep, acc ->
        case detect_cycle(dep, adjacency, acc, new_path) do
          {:cycle, _} = cycle -> {:halt, cycle}
          {:ok, new_visited} -> {:cont, new_visited}
        end
      end)

    case result do
      {:cycle, _} = cycle -> cycle
      visited_after -> {:ok, Map.put(visited_after, node, :done)}
    end
  end

  @doc """
  Gets all events for a given stage_id.
  """
  @spec get_events_by_stage(t(), String.t()) :: [Event.t()]
  def get_events_by_stage(%__MODULE__{} = chain, stage_id) do
    Enum.filter(chain.events, &(&1.stage_id == stage_id))
  end

  @doc """
  Gets all events for a given experiment_id.
  """
  @spec get_events_by_experiment(t(), String.t()) :: [Event.t()]
  def get_events_by_experiment(%__MODULE__{} = chain, experiment_id) do
    Enum.filter(chain.events, &(&1.experiment_id == experiment_id))
  end
end
