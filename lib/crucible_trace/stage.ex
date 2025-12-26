defmodule CrucibleTrace.Stage do
  @moduledoc """
  Pipeline stage wrapper that automatically traces execution.

  Implements a pattern for wrapping crucible_framework stages
  with automatic trace event generation.
  """

  alias CrucibleTrace.{Chain, Event}

  @doc """
  Wraps a stage function with tracing.

  Creates events for:
  - Stage start
  - Stage completion (with duration)
  - Stage errors

  ## Options
  - :experiment_id - Associated experiment ID
  - :parent_id - Parent event ID
  - :metadata - Additional metadata to include

  ## Returns
  `{updated_chain, result}` where result is the return value of the stage function.

  ## Examples

      {chain, result} = Stage.trace_stage(chain, "preprocessing", fn ->
        preprocess_data(data)
      end)
  """
  @spec trace_stage(Chain.t(), String.t(), (-> any()), keyword()) :: {Chain.t(), any()}
  def trace_stage(%Chain{} = chain, stage_id, stage_fn, opts \\ [])
      when is_binary(stage_id) and is_function(stage_fn, 0) do
    experiment_id = Keyword.get(opts, :experiment_id)
    parent_id = Keyword.get(opts, :parent_id)
    extra_metadata = Keyword.get(opts, :metadata, %{})

    # Create start event
    start_event =
      Event.new(
        :stage_started,
        "Stage #{stage_id} started",
        "Beginning stage execution",
        stage_id: stage_id,
        experiment_id: experiment_id,
        parent_id: parent_id,
        metadata: Map.merge(extra_metadata, %{stage_id: stage_id})
      )

    chain = Chain.add_event(chain, start_event)

    # Record start time
    start_time = System.monotonic_time(:microsecond)

    # Execute stage function and capture result
    {result, status, error_info} = execute_stage(stage_fn)

    # Calculate duration
    end_time = System.monotonic_time(:microsecond)
    duration_us = end_time - start_time

    # Create completion event
    complete_metadata =
      extra_metadata
      |> Map.merge(%{
        stage_id: stage_id,
        duration_us: duration_us,
        status: status
      })
      |> maybe_add_error(error_info)

    complete_event =
      Event.new(
        :stage_completed,
        "Stage #{stage_id} completed",
        format_completion_reason(status, duration_us),
        stage_id: stage_id,
        experiment_id: experiment_id,
        parent_id: parent_id,
        metadata: complete_metadata
      )

    chain = Chain.add_event(chain, complete_event)

    {chain, result}
  end

  # Private functions

  defp execute_stage(stage_fn) do
    result = stage_fn.()

    status =
      case result do
        {:error, _} -> :error
        :error -> :error
        _ -> :ok
      end

    {result, status, nil}
  rescue
    e ->
      {{:error, Exception.message(e)}, :exception, Exception.message(e)}
  catch
    kind, reason ->
      error_msg = "#{kind}: #{inspect(reason)}"
      {{:error, error_msg}, :exception, error_msg}
  end

  defp maybe_add_error(metadata, nil), do: metadata
  defp maybe_add_error(metadata, error), do: Map.put(metadata, :error, error)

  defp format_completion_reason(:ok, duration_us) do
    "Stage completed successfully in #{format_duration(duration_us)}"
  end

  defp format_completion_reason(:error, duration_us) do
    "Stage completed with error in #{format_duration(duration_us)}"
  end

  defp format_completion_reason(:exception, duration_us) do
    "Stage failed with exception after #{format_duration(duration_us)}"
  end

  defp format_duration(us) when us < 1000, do: "#{us}us"
  defp format_duration(us) when us < 1_000_000, do: "#{Float.round(us / 1000, 2)}ms"
  defp format_duration(us), do: "#{Float.round(us / 1_000_000, 2)}s"
end
