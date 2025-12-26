defmodule CrucibleTrace.Training do
  @moduledoc """
  Helper functions for tracing ML training workflows.

  Provides convenience functions for common training events like
  epoch completion, loss recording, and checkpoint management.
  """

  alias CrucibleTrace.{Chain, Event}

  # Training lifecycle events

  @doc """
  Creates a training_started event.

  ## Options
  - :model_name - Name of the model being trained
  - :dataset - Dataset name
  - :config - Training configuration map
  - :experiment_id - Associated experiment ID
  - :stage_id - Associated stage ID
  - :parent_id - Parent event ID
  """
  @spec training_started(String.t(), String.t(), keyword()) :: Event.t()
  def training_started(decision, reasoning, opts \\ []) do
    metadata =
      opts
      |> Keyword.take([:model_name, :dataset, :config])
      |> Map.new()
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(:training_started, decision, reasoning,
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  @doc """
  Creates a training_completed event.

  ## Options
  - :final_loss - Final training loss
  - :final_accuracy - Final accuracy
  - :total_epochs - Total epochs trained
  - :experiment_id - Associated experiment ID
  """
  @spec training_completed(String.t(), String.t(), keyword()) :: Event.t()
  def training_completed(decision, reasoning, opts \\ []) do
    metadata =
      opts
      |> Keyword.take([:final_loss, :final_accuracy, :total_epochs])
      |> Map.new()
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(:training_completed, decision, reasoning,
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  @doc """
  Creates an epoch_completed event with metrics.

  ## Options
  - :experiment_id - Associated experiment ID
  - :stage_id - Associated stage ID
  - :parent_id - Parent event ID
  """
  @spec epoch_completed(non_neg_integer(), map(), keyword()) :: Event.t()
  def epoch_completed(epoch, metrics, opts \\ []) when is_integer(epoch) and is_map(metrics) do
    metadata =
      metrics
      |> Map.put(:epoch, epoch)
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(
      :epoch_completed,
      "Epoch #{epoch} completed",
      "Training epoch finished",
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  @doc """
  Creates a batch_processed event.

  ## Options
  - :epoch - Current epoch number
  - :experiment_id - Associated experiment ID
  """
  @spec batch_processed(non_neg_integer(), map(), keyword()) :: Event.t()
  def batch_processed(batch, metrics, opts \\ []) when is_integer(batch) and is_map(metrics) do
    metadata =
      metrics
      |> Map.put(:batch, batch)
      |> Map.put(:epoch, Keyword.get(opts, :epoch))
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(
      :batch_processed,
      "Batch #{batch} processed",
      "Training batch finished",
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  # Metrics events

  @doc """
  Creates a loss_computed event.

  ## Options
  - :loss_type - Type of loss (e.g., :cross_entropy, :mse)
  - :experiment_id - Associated experiment ID
  """
  @spec loss_computed(float(), keyword()) :: Event.t()
  def loss_computed(loss_value, opts \\ []) when is_number(loss_value) do
    metadata =
      %{loss_value: loss_value, loss_type: Keyword.get(opts, :loss_type)}
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(
      :loss_computed,
      "Loss: #{loss_value}",
      "Loss value computed",
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  # Checkpoint events

  @doc """
  Creates a checkpoint_saved event.

  ## Options
  - :metrics - Metrics at checkpoint time
  - :epoch - Epoch number
  - :experiment_id - Associated experiment ID
  """
  @spec checkpoint_saved(String.t(), keyword()) :: Event.t()
  def checkpoint_saved(path, opts \\ []) when is_binary(path) do
    metadata =
      %{
        path: path,
        metrics: Keyword.get(opts, :metrics),
        epoch: Keyword.get(opts, :epoch)
      }
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(
      :checkpoint_saved,
      "Checkpoint saved to #{path}",
      "Model checkpoint saved",
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  @doc """
  Creates a checkpoint_loaded event.

  ## Options
  - :resume_epoch - Epoch to resume from
  - :experiment_id - Associated experiment ID
  """
  @spec checkpoint_loaded(String.t(), keyword()) :: Event.t()
  def checkpoint_loaded(path, opts \\ []) when is_binary(path) do
    metadata =
      %{path: path, resume_epoch: Keyword.get(opts, :resume_epoch)}
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(
      :checkpoint_loaded,
      "Checkpoint loaded from #{path}",
      "Model checkpoint loaded",
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  @doc """
  Creates an early_stopped event.

  ## Options
  - :best_epoch - Best epoch before stopping
  - :patience - Patience value used
  - :experiment_id - Associated experiment ID
  """
  @spec early_stopped(String.t(), keyword()) :: Event.t()
  def early_stopped(reasoning, opts \\ []) when is_binary(reasoning) do
    metadata =
      %{
        best_epoch: Keyword.get(opts, :best_epoch),
        patience: Keyword.get(opts, :patience)
      }
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(
      :early_stopped,
      "Training stopped early",
      reasoning,
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  # Deployment events

  @doc """
  Creates a deployment_started event.

  ## Options
  - :environment - Deployment environment (:production, :staging, etc.)
  - :version - Model version
  - :experiment_id - Associated experiment ID
  """
  @spec deployment_started(String.t(), keyword()) :: Event.t()
  def deployment_started(model_path, opts \\ []) when is_binary(model_path) do
    metadata =
      %{
        model_path: model_path,
        environment: Keyword.get(opts, :environment),
        version: Keyword.get(opts, :version)
      }
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(
      :deployment_started,
      "Deployment started for #{model_path}",
      "Model deployment initiated",
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  @doc """
  Creates a model_loaded event.

  ## Options
  - :load_time_ms - Time to load model in milliseconds
  - :experiment_id - Associated experiment ID
  """
  @spec model_loaded(String.t(), keyword()) :: Event.t()
  def model_loaded(model_path, opts \\ []) when is_binary(model_path) do
    metadata =
      %{model_path: model_path, load_time_ms: Keyword.get(opts, :load_time_ms)}
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(
      :model_loaded,
      "Model loaded from #{model_path}",
      "Model loaded for inference",
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  @doc """
  Creates an inference_completed event.

  ## Options
  - :latency_ms - Inference latency in milliseconds
  - :batch_size - Batch size
  - :experiment_id - Associated experiment ID
  """
  @spec inference_completed(map(), keyword()) :: Event.t()
  def inference_completed(result, opts \\ []) when is_map(result) do
    metadata =
      %{
        result: result,
        latency_ms: Keyword.get(opts, :latency_ms),
        batch_size: Keyword.get(opts, :batch_size)
      }
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(
      :inference_completed,
      "Inference completed",
      "Model inference finished",
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  # RL/Feedback events

  @doc """
  Creates a reward_received event for RL workflows.

  ## Options
  - :step - Training step
  - :episode - Episode number
  - :experiment_id - Associated experiment ID
  """
  @spec reward_received(float(), keyword()) :: Event.t()
  def reward_received(reward, opts \\ []) when is_number(reward) do
    metadata =
      %{
        reward: reward,
        step: Keyword.get(opts, :step),
        episode: Keyword.get(opts, :episode)
      }
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(
      :reward_received,
      "Reward: #{reward}",
      "Reward signal received",
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  @doc """
  Creates a policy_updated event.

  ## Options
  - :learning_rate - Current learning rate
  - :gradient_norm - Gradient norm
  - :experiment_id - Associated experiment ID
  """
  @spec policy_updated(String.t(), keyword()) :: Event.t()
  def policy_updated(reasoning, opts \\ []) when is_binary(reasoning) do
    metadata =
      %{
        learning_rate: Keyword.get(opts, :learning_rate),
        gradient_norm: Keyword.get(opts, :gradient_norm)
      }
      |> Map.merge(Keyword.get(opts, :metadata, %{}))

    Event.new(
      :policy_updated,
      "Policy updated",
      reasoning,
      metadata: metadata,
      experiment_id: Keyword.get(opts, :experiment_id),
      stage_id: Keyword.get(opts, :stage_id),
      parent_id: Keyword.get(opts, :parent_id)
    )
  end

  # Batch operations

  @doc """
  Creates events for a complete training run from metrics history.

  ## Options
  - :experiment_id - Associated experiment ID
  - :stage_id - Associated stage ID
  """
  @spec from_training_metrics([map()], keyword()) :: [Event.t()]
  def from_training_metrics(metrics_list, opts \\ []) when is_list(metrics_list) do
    Enum.map(metrics_list, fn metrics ->
      epoch = Map.get(metrics, :epoch, 0)
      epoch_completed(epoch, metrics, opts)
    end)
  end

  @doc """
  Wraps a training function to automatically emit trace events.

  Returns `{updated_chain, result}` where result is the return value
  of the training function.
  """
  @spec trace_training(Chain.t(), (-> any()), keyword()) :: {Chain.t(), any()}
  def trace_training(%Chain{} = chain, training_fn, opts \\ [])
      when is_function(training_fn, 0) do
    start_event =
      training_started(
        "Training started",
        "Beginning training run",
        opts
      )

    chain = Chain.add_event(chain, start_event)

    try do
      result = training_fn.()

      complete_event =
        case result do
          {:ok, _} ->
            training_completed("Training completed successfully", "Training run finished", opts)

          {:error, _} ->
            training_completed("Training completed with error", "Training run had errors", opts)

          _ ->
            training_completed("Training completed", "Training run finished", opts)
        end

      chain = Chain.add_event(chain, complete_event)
      {chain, result}
    rescue
      e ->
        error_event =
          training_completed(
            "Training failed",
            "Training run failed: #{Exception.message(e)}",
            opts
          )

        chain = Chain.add_event(chain, error_event)
        {chain, {:error, Exception.message(e)}}
    end
  end
end
