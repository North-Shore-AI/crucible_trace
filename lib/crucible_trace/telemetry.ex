defmodule CrucibleTrace.Telemetry do
  @moduledoc """
  Telemetry integration for CrucibleTrace.

  Emits telemetry events for trace operations and can subscribe
  to pipeline telemetry to automatically create trace events.
  """

  alias CrucibleTrace.Event

  @handler_id_prefix "crucible_trace_"

  @doc """
  Attaches telemetry handlers for automatic trace collection.

  ## Options
  - :prefix - Event prefix to listen for (default: [:crucible])
  """
  @spec attach_handlers(keyword()) :: :ok
  def attach_handlers(opts \\ []) do
    prefix = Keyword.get(opts, :prefix, [:crucible])

    # Attach handler for pipeline events
    :telemetry.attach(
      @handler_id_prefix <> "pipeline_start",
      prefix ++ [:pipeline, :stage, :start],
      &handle_pipeline_event/4,
      %{}
    )

    :telemetry.attach(
      @handler_id_prefix <> "pipeline_stop",
      prefix ++ [:pipeline, :stage, :stop],
      &handle_pipeline_event/4,
      %{}
    )

    :ok
  rescue
    _ -> :ok
  end

  @doc """
  Detaches telemetry handlers.
  """
  @spec detach_handlers() :: :ok
  def detach_handlers do
    :telemetry.detach(@handler_id_prefix <> "pipeline_start")
    :telemetry.detach(@handler_id_prefix <> "pipeline_stop")
    :ok
  rescue
    _ -> :ok
  end

  @doc """
  Emits a telemetry event for a trace event creation.

  Telemetry event: [:crucible_trace, :event, :created]
  """
  @spec emit_event_created(Event.t()) :: :ok
  def emit_event_created(%Event{} = event) do
    :telemetry.execute(
      [:crucible_trace, :event, :created],
      %{system_time: System.system_time()},
      %{
        event_id: event.id,
        event_type: event.type,
        decision: event.decision,
        confidence: event.confidence,
        stage_id: event.stage_id,
        experiment_id: event.experiment_id
      }
    )

    :ok
  end

  @doc """
  Emits a telemetry event for chain operations.

  Events:
  - [:crucible_trace, :chain, :created]
  - [:crucible_trace, :chain, :saved]
  - [:crucible_trace, :chain, :loaded]
  """
  @spec emit_chain_event(atom(), CrucibleTrace.Chain.t(), map()) :: :ok
  def emit_chain_event(event_name, chain, metadata \\ %{})
      when event_name in [:created, :saved, :loaded] do
    :telemetry.execute(
      [:crucible_trace, :chain, event_name],
      %{system_time: System.system_time(), event_count: length(chain.events)},
      Map.merge(
        %{
          chain_id: chain.id,
          chain_name: chain.name
        },
        metadata
      )
    )

    :ok
  end

  @doc """
  Handles incoming pipeline telemetry events.

  Converts crucible_framework pipeline events to trace events.
  """
  @spec handle_pipeline_event([atom()], map(), map(), map()) :: Event.t() | nil
  def handle_pipeline_event(event_name, measurements, metadata, _config) do
    case event_name do
      [_, :pipeline, :stage, :start] ->
        Event.new(
          :stage_started,
          "Stage started: #{Map.get(metadata, :stage_id, "unknown")}",
          "Pipeline stage execution started",
          metadata: %{
            stage_id: Map.get(metadata, :stage_id),
            system_time: Map.get(measurements, :system_time)
          },
          stage_id: Map.get(metadata, :stage_id),
          experiment_id: Map.get(metadata, :experiment_id)
        )

      [_, :pipeline, :stage, :stop] ->
        Event.new(
          :stage_completed,
          "Stage completed: #{Map.get(metadata, :stage_id, "unknown")}",
          "Pipeline stage execution completed",
          metadata: %{
            stage_id: Map.get(metadata, :stage_id),
            duration: Map.get(measurements, :duration),
            system_time: Map.get(measurements, :system_time)
          },
          stage_id: Map.get(metadata, :stage_id),
          experiment_id: Map.get(metadata, :experiment_id)
        )

      _ ->
        nil
    end
  end
end
