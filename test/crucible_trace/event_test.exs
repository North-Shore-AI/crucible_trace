defmodule CrucibleTrace.EventTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.Event

  describe "new/4" do
    test "creates an event with required fields" do
      event = Event.new(:hypothesis_formed, "Use GenServer", "Need state management")

      assert event.type == :hypothesis_formed
      assert event.decision == "Use GenServer"
      assert event.reasoning == "Need state management"
      assert event.confidence == 1.0
      assert event.alternatives == []
      assert is_binary(event.id)
      assert %DateTime{} = event.timestamp
    end

    test "creates an event with optional fields" do
      event =
        Event.new(
          :pattern_applied,
          "Use Supervisor",
          "Fault tolerance",
          alternatives: ["GenServer", "Agent"],
          confidence: 0.85,
          code_section: "MyApp.Supervisor",
          spec_reference: "Section 3.2",
          metadata: %{priority: :high}
        )

      assert event.alternatives == ["GenServer", "Agent"]
      assert event.confidence == 0.85
      assert event.code_section == "MyApp.Supervisor"
      assert event.spec_reference == "Section 3.2"
      assert event.metadata == %{priority: :high}
    end
  end

  describe "validate/1" do
    test "validates a correct event" do
      event = Event.new(:hypothesis_formed, "Decision", "Reasoning")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "rejects invalid event type" do
      event = %Event{
        id: "123",
        timestamp: DateTime.utc_now(),
        type: :invalid_type,
        decision: "Decision",
        reasoning: "Reasoning"
      }

      assert {:error, msg} = Event.validate(event)
      assert msg =~ "Invalid event type"
    end

    test "rejects invalid confidence" do
      event = %Event{
        id: "123",
        timestamp: DateTime.utc_now(),
        type: :hypothesis_formed,
        decision: "Decision",
        reasoning: "Reasoning",
        confidence: 1.5
      }

      assert {:error, msg} = Event.validate(event)
      assert msg =~ "Confidence must be between 0.0 and 1.0"
    end

    test "rejects empty decision" do
      event = %Event{
        id: "123",
        timestamp: DateTime.utc_now(),
        type: :hypothesis_formed,
        decision: "",
        reasoning: "Reasoning"
      }

      assert {:error, msg} = Event.validate(event)
      assert msg =~ "must be non-empty strings"
    end
  end

  describe "to_map/1" do
    test "converts event to map" do
      event =
        Event.new(
          :hypothesis_formed,
          "Decision",
          "Reasoning",
          alternatives: ["Alt1", "Alt2"],
          confidence: 0.9
        )

      map = Event.to_map(event)

      assert map.id == event.id
      assert map.type == :hypothesis_formed
      assert map.decision == "Decision"
      assert map.reasoning == "Reasoning"
      assert map.alternatives == ["Alt1", "Alt2"]
      assert map.confidence == 0.9
      assert is_binary(map.timestamp)
    end
  end

  describe "from_map/1" do
    test "creates event from map with string keys" do
      map = %{
        "id" => "abc123",
        "timestamp" => DateTime.to_iso8601(DateTime.utc_now()),
        "type" => "hypothesis_formed",
        "decision" => "Decision",
        "reasoning" => "Reasoning",
        "alternatives" => ["Alt1"],
        "confidence" => 0.8
      }

      event = Event.from_map(map)

      assert event.id == "abc123"
      assert event.type == :hypothesis_formed
      assert event.decision == "Decision"
      assert event.reasoning == "Reasoning"
      assert event.alternatives == ["Alt1"]
      assert event.confidence == 0.8
    end

    test "creates event from map with atom keys" do
      map = %{
        id: "abc123",
        type: :pattern_applied,
        decision: "Decision",
        reasoning: "Reasoning"
      }

      event = Event.from_map(map)

      assert event.id == "abc123"
      assert event.type == :pattern_applied
      assert event.decision == "Decision"
    end

    test "handles missing optional fields" do
      map = %{
        "type" => "hypothesis_formed",
        "decision" => "Decision",
        "reasoning" => "Reasoning"
      }

      event = Event.from_map(map)

      assert event.alternatives == []
      assert event.confidence == 1.0
      assert event.code_section == nil
      assert event.spec_reference == nil
      assert is_binary(event.id)
    end
  end

  describe "training event types" do
    test "validates training_started type" do
      event = Event.new(:training_started, "Start training", "Initializing")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates training_completed type" do
      event = Event.new(:training_completed, "Training done", "Completed successfully")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates epoch_started type" do
      event = Event.new(:epoch_started, "Epoch 1 started", "Beginning epoch")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates epoch_completed type" do
      event = Event.new(:epoch_completed, "Epoch 5 done", "Completed epoch 5")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates batch_processed type" do
      event = Event.new(:batch_processed, "Batch 100 processed", "Batch complete")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates loss_computed type" do
      event = Event.new(:loss_computed, "Loss: 0.234", "Cross-entropy loss")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates metric_recorded type" do
      event = Event.new(:metric_recorded, "Accuracy: 0.95", "Validation accuracy")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates gradient_computed type" do
      event = Event.new(:gradient_computed, "Gradients computed", "Backward pass")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates checkpoint_saved type" do
      event = Event.new(:checkpoint_saved, "Checkpoint saved", "Epoch 10")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates checkpoint_loaded type" do
      event = Event.new(:checkpoint_loaded, "Checkpoint loaded", "Resuming training")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates early_stopped type" do
      event = Event.new(:early_stopped, "Training stopped early", "No improvement")
      assert {:ok, ^event} = Event.validate(event)
    end
  end

  describe "deployment event types" do
    test "validates deployment_started type" do
      event = Event.new(:deployment_started, "Deploying model", "Production deployment")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates model_loaded type" do
      event = Event.new(:model_loaded, "Model loaded", "Loaded from checkpoint")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates inference_completed type" do
      event = Event.new(:inference_completed, "Inference done", "Batch inference")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates deployment_completed type" do
      event = Event.new(:deployment_completed, "Deployment complete", "Now serving")
      assert {:ok, ^event} = Event.validate(event)
    end
  end

  describe "RL/feedback event types" do
    test "validates reward_received type" do
      event = Event.new(:reward_received, "Reward: 1.5", "Positive reward")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates policy_updated type" do
      event = Event.new(:policy_updated, "Policy updated", "Gradient update")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates experience_sampled type" do
      event = Event.new(:experience_sampled, "Experience sampled", "Replay buffer")
      assert {:ok, ^event} = Event.validate(event)
    end
  end

  describe "stage event types" do
    test "validates stage_started type" do
      event = Event.new(:stage_started, "Stage started", "Beginning execution")
      assert {:ok, ^event} = Event.validate(event)
    end

    test "validates stage_completed type" do
      event = Event.new(:stage_completed, "Stage completed", "Finished execution")
      assert {:ok, ^event} = Event.validate(event)
    end
  end
end
