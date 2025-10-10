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
end
