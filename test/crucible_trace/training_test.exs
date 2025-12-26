defmodule CrucibleTrace.TrainingTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.{Chain, Training}

  describe "training_started/3" do
    test "creates training_started event with model info" do
      event =
        Training.training_started(
          "Begin ResNet-50 training",
          "Using pretrained weights for transfer learning",
          model_name: "resnet50",
          dataset: "imagenet",
          experiment_id: "exp-001"
        )

      assert event.type == :training_started
      assert event.decision == "Begin ResNet-50 training"
      assert event.reasoning == "Using pretrained weights for transfer learning"
      assert event.metadata[:model_name] == "resnet50"
      assert event.metadata[:dataset] == "imagenet"
      assert event.experiment_id == "exp-001"
    end

    test "creates training_started event with defaults" do
      event = Training.training_started("Start training", "Initial run")

      assert event.type == :training_started
      assert event.decision == "Start training"
      assert event.reasoning == "Initial run"
      assert event.experiment_id == nil
    end
  end

  describe "training_completed/3" do
    test "creates training_completed event with metrics" do
      event =
        Training.training_completed(
          "Training complete",
          "Reached convergence",
          final_loss: 0.05,
          final_accuracy: 0.98,
          total_epochs: 100
        )

      assert event.type == :training_completed
      assert event.metadata[:final_loss] == 0.05
      assert event.metadata[:final_accuracy] == 0.98
      assert event.metadata[:total_epochs] == 100
    end
  end

  describe "epoch_completed/3" do
    test "creates epoch event with metrics" do
      event =
        Training.epoch_completed(5, %{
          train_loss: 0.234,
          val_loss: 0.289,
          accuracy: 0.876
        })

      assert event.type == :epoch_completed
      assert event.metadata[:epoch] == 5
      assert event.metadata[:train_loss] == 0.234
      assert event.metadata[:val_loss] == 0.289
      assert event.metadata[:accuracy] == 0.876
    end

    test "creates epoch event with custom options" do
      event =
        Training.epoch_completed(
          10,
          %{loss: 0.1},
          experiment_id: "exp-002",
          stage_id: "training-stage"
        )

      assert event.type == :epoch_completed
      assert event.metadata[:epoch] == 10
      assert event.experiment_id == "exp-002"
      assert event.stage_id == "training-stage"
    end
  end

  describe "batch_processed/3" do
    test "creates batch_processed event" do
      event =
        Training.batch_processed(
          50,
          %{batch_loss: 0.15},
          epoch: 3
        )

      assert event.type == :batch_processed
      assert event.metadata[:batch] == 50
      assert event.metadata[:batch_loss] == 0.15
      assert event.metadata[:epoch] == 3
    end
  end

  describe "loss_computed/2" do
    test "creates loss_computed event" do
      event = Training.loss_computed(0.234, loss_type: :cross_entropy)

      assert event.type == :loss_computed
      assert event.metadata[:loss_value] == 0.234
      assert event.metadata[:loss_type] == :cross_entropy
    end
  end

  describe "checkpoint_saved/2" do
    test "creates checkpoint_saved event" do
      event =
        Training.checkpoint_saved(
          "/models/checkpoint_epoch_5.pt",
          metrics: %{val_accuracy: 0.876},
          epoch: 5
        )

      assert event.type == :checkpoint_saved
      assert event.metadata[:path] == "/models/checkpoint_epoch_5.pt"
      assert event.metadata[:metrics] == %{val_accuracy: 0.876}
      assert event.metadata[:epoch] == 5
    end
  end

  describe "checkpoint_loaded/2" do
    test "creates checkpoint_loaded event" do
      event = Training.checkpoint_loaded("/models/best_model.pt", resume_epoch: 50)

      assert event.type == :checkpoint_loaded
      assert event.metadata[:path] == "/models/best_model.pt"
      assert event.metadata[:resume_epoch] == 50
    end
  end

  describe "early_stopped/2" do
    test "creates early_stopped event" do
      event =
        Training.early_stopped(
          "Validation loss stopped improving",
          best_epoch: 45,
          patience: 10
        )

      assert event.type == :early_stopped
      assert event.reasoning == "Validation loss stopped improving"
      assert event.metadata[:best_epoch] == 45
      assert event.metadata[:patience] == 10
    end
  end

  describe "deployment_started/2" do
    test "creates deployment_started event" do
      event =
        Training.deployment_started(
          "/models/production_v1.pt",
          environment: :production,
          version: "1.0.0"
        )

      assert event.type == :deployment_started
      assert event.metadata[:model_path] == "/models/production_v1.pt"
      assert event.metadata[:environment] == :production
      assert event.metadata[:version] == "1.0.0"
    end
  end

  describe "model_loaded/2" do
    test "creates model_loaded event" do
      event =
        Training.model_loaded(
          "/models/model.pt",
          load_time_ms: 150
        )

      assert event.type == :model_loaded
      assert event.metadata[:model_path] == "/models/model.pt"
      assert event.metadata[:load_time_ms] == 150
    end
  end

  describe "inference_completed/2" do
    test "creates inference_completed event" do
      event =
        Training.inference_completed(
          %{prediction: 0.95, label: "cat"},
          latency_ms: 25,
          batch_size: 1
        )

      assert event.type == :inference_completed
      assert event.metadata[:result] == %{prediction: 0.95, label: "cat"}
      assert event.metadata[:latency_ms] == 25
      assert event.metadata[:batch_size] == 1
    end
  end

  describe "reward_received/2" do
    test "creates reward_received event for RL" do
      event =
        Training.reward_received(
          1.5,
          step: 1000,
          episode: 42
        )

      assert event.type == :reward_received
      assert event.metadata[:reward] == 1.5
      assert event.metadata[:step] == 1000
      assert event.metadata[:episode] == 42
    end
  end

  describe "policy_updated/2" do
    test "creates policy_updated event" do
      event =
        Training.policy_updated(
          "Gradient update applied",
          learning_rate: 0.001,
          gradient_norm: 1.5
        )

      assert event.type == :policy_updated
      assert event.reasoning == "Gradient update applied"
      assert event.metadata[:learning_rate] == 0.001
      assert event.metadata[:gradient_norm] == 1.5
    end
  end

  describe "from_training_metrics/2" do
    test "creates event chain from metrics history" do
      metrics = [
        %{epoch: 1, loss: 1.0, acc: 0.5},
        %{epoch: 2, loss: 0.5, acc: 0.7},
        %{epoch: 3, loss: 0.3, acc: 0.85}
      ]

      events = Training.from_training_metrics(metrics)

      assert length(events) == 3
      assert Enum.all?(events, &(&1.type == :epoch_completed))

      first = hd(events)
      assert first.metadata[:epoch] == 1
      assert first.metadata[:loss] == 1.0
    end

    test "creates event chain with experiment_id" do
      metrics = [%{epoch: 1, loss: 0.5}]
      events = Training.from_training_metrics(metrics, experiment_id: "exp-test")

      assert hd(events).experiment_id == "exp-test"
    end
  end

  describe "trace_training/2" do
    test "wraps training function with events" do
      chain = Chain.new("Training Run")

      {updated_chain, result} =
        Training.trace_training(chain, fn ->
          {:ok, %{final_loss: 0.1}}
        end)

      assert result == {:ok, %{final_loss: 0.1}}
      refute Enum.empty?(updated_chain.events)

      types = Enum.map(updated_chain.events, & &1.type)
      assert :training_started in types
      assert :training_completed in types
    end

    test "handles training errors" do
      chain = Chain.new("Training Run")

      {updated_chain, result} =
        Training.trace_training(chain, fn ->
          {:error, :out_of_memory}
        end)

      assert result == {:error, :out_of_memory}
      # Should still have training_started event
      refute Enum.empty?(updated_chain.events)
    end
  end
end
