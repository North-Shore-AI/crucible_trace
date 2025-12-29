defmodule CrucibleTrace.Event do
  @moduledoc """
  Represents a single causal reasoning event in the decision chain.

  Events capture the decision-making process of LLMs during code generation,
  including what was chosen, what alternatives were considered, and why.
  """

  # Original reasoning event types
  @type event_type ::
          :hypothesis_formed
          | :alternative_rejected
          | :constraint_evaluated
          | :pattern_applied
          | :ambiguity_flagged
          | :confidence_updated
          # Training lifecycle events
          | :training_started
          | :training_completed
          | :epoch_started
          | :epoch_completed
          | :batch_processed
          # Metrics events
          | :loss_computed
          | :metric_recorded
          | :gradient_computed
          # Checkpoint events
          | :checkpoint_saved
          | :checkpoint_loaded
          | :early_stopped
          # Deployment events
          | :deployment_started
          | :model_loaded
          | :inference_completed
          | :deployment_completed
          # RL/Feedback events
          | :reward_received
          | :policy_updated
          | :experience_sampled
          # Stage events
          | :stage_started
          | :stage_completed

  @type t :: %__MODULE__{
          id: String.t(),
          timestamp: DateTime.t(),
          type: event_type(),
          decision: String.t(),
          alternatives: [String.t()],
          reasoning: String.t(),
          confidence: float(),
          code_section: String.t() | nil,
          spec_reference: String.t() | nil,
          metadata: map(),
          # Relationship fields
          parent_id: String.t() | nil,
          depends_on: [String.t()],
          stage_id: String.t() | nil,
          experiment_id: String.t() | nil
        }

  @enforce_keys [:id, :timestamp, :type, :decision, :reasoning]
  defstruct [
    :id,
    :timestamp,
    :type,
    :decision,
    :reasoning,
    alternatives: [],
    confidence: 1.0,
    code_section: nil,
    spec_reference: nil,
    metadata: %{},
    # Relationship fields
    parent_id: nil,
    depends_on: [],
    stage_id: nil,
    experiment_id: nil
  ]

  @doc """
  Creates a new event with the given attributes.

  ## Examples

      iex> CrucibleTrace.Event.new(:hypothesis_formed, "Use GenServer for state", "Need concurrent state management")
      %CrucibleTrace.Event{
        type: :hypothesis_formed,
        decision: "Use GenServer for state",
        reasoning: "Need concurrent state management"
      }
  """
  def new(type, decision, reasoning, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      timestamp: DateTime.utc_now(),
      type: type,
      decision: decision,
      reasoning: reasoning,
      alternatives: Keyword.get(opts, :alternatives, []),
      confidence: Keyword.get(opts, :confidence, 1.0),
      code_section: Keyword.get(opts, :code_section),
      spec_reference: Keyword.get(opts, :spec_reference),
      metadata: Keyword.get(opts, :metadata, %{}),
      # Relationship fields
      parent_id: Keyword.get(opts, :parent_id),
      depends_on: Keyword.get(opts, :depends_on, []),
      stage_id: Keyword.get(opts, :stage_id),
      experiment_id: Keyword.get(opts, :experiment_id)
    }
  end

  @doc """
  Validates an event struct.

  Returns `{:ok, event}` if valid, `{:error, reason}` otherwise.
  """
  def validate(%__MODULE__{} = event) do
    with :ok <- validate_type(event.type),
         :ok <- validate_confidence(event.confidence),
         :ok <- validate_required_fields(event) do
      {:ok, event}
    end
  end

  @valid_event_types [
    # Original reasoning event types
    :hypothesis_formed,
    :alternative_rejected,
    :constraint_evaluated,
    :pattern_applied,
    :ambiguity_flagged,
    :confidence_updated,
    # Training lifecycle events
    :training_started,
    :training_completed,
    :epoch_started,
    :epoch_completed,
    :batch_processed,
    # Metrics events
    :loss_computed,
    :metric_recorded,
    :gradient_computed,
    # Checkpoint events
    :checkpoint_saved,
    :checkpoint_loaded,
    :early_stopped,
    # Deployment events
    :deployment_started,
    :model_loaded,
    :inference_completed,
    :deployment_completed,
    # RL/Feedback events
    :reward_received,
    :policy_updated,
    :experience_sampled,
    # Stage events
    :stage_started,
    :stage_completed
  ]

  defp validate_type(type) when type in @valid_event_types do
    :ok
  end

  defp validate_type(type), do: {:error, "Invalid event type: #{inspect(type)}"}

  defp validate_confidence(confidence)
       when is_float(confidence) and confidence >= 0.0 and confidence <= 1.0 do
    :ok
  end

  defp validate_confidence(confidence),
    do: {:error, "Confidence must be between 0.0 and 1.0, got: #{inspect(confidence)}"}

  defp validate_required_fields(%__MODULE__{decision: decision, reasoning: reasoning})
       when is_binary(decision) and byte_size(decision) > 0 and
              is_binary(reasoning) and byte_size(reasoning) > 0 do
    :ok
  end

  defp validate_required_fields(_),
    do: {:error, "Decision and reasoning must be non-empty strings"}

  @doc """
  Converts an event to a map suitable for JSON encoding.
  """
  def to_map(%__MODULE__{} = event) do
    %{
      id: event.id,
      timestamp: DateTime.to_iso8601(event.timestamp),
      type: event.type,
      decision: event.decision,
      alternatives: event.alternatives,
      reasoning: event.reasoning,
      confidence: event.confidence,
      code_section: event.code_section,
      spec_reference: event.spec_reference,
      metadata: event.metadata,
      # Relationship fields
      parent_id: event.parent_id,
      depends_on: event.depends_on,
      stage_id: event.stage_id,
      experiment_id: event.experiment_id
    }
  end

  @doc """
  Creates an event from a map (e.g., from JSON parsing).
  """
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: get_field(map, "id", :id) || generate_id(),
      timestamp: parse_timestamp(get_field(map, "timestamp", :timestamp)),
      type: parse_type(get_field(map, "type", :type)),
      decision: get_field(map, "decision", :decision),
      alternatives: get_field(map, "alternatives", :alternatives, []),
      reasoning: get_field(map, "reasoning", :reasoning),
      confidence: parse_confidence(get_field(map, "confidence", :confidence, 1.0)),
      code_section: get_field(map, "code_section", :code_section),
      spec_reference: get_field(map, "spec_reference", :spec_reference),
      metadata: get_field(map, "metadata", :metadata, %{}),
      # Relationship fields
      parent_id: get_field(map, "parent_id", :parent_id),
      depends_on: get_field(map, "depends_on", :depends_on, []),
      stage_id: get_field(map, "stage_id", :stage_id),
      experiment_id: get_field(map, "experiment_id", :experiment_id)
    }
  end

  defp get_field(map, key_str, key_atom, default \\ nil) do
    Map.get(map, key_str) || Map.get(map, key_atom, default)
  end

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

  defp parse_type(type) when is_atom(type), do: type
  defp parse_type(type) when is_binary(type), do: String.to_existing_atom(type)
  defp parse_type(_), do: :hypothesis_formed

  defp parse_confidence(conf) when is_float(conf), do: conf
  defp parse_confidence(conf) when is_integer(conf), do: conf / 1.0

  defp parse_confidence(conf) when is_binary(conf) do
    case Float.parse(conf) do
      {num, _} -> num
      _ -> 1.0
    end
  end

  defp parse_confidence(_), do: 1.0
end
