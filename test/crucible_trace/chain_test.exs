defmodule CrucibleTrace.ChainTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.{Chain, Event}

  describe "new/2" do
    test "creates a new chain with name" do
      chain = Chain.new("Test Chain")

      assert chain.name == "Test Chain"
      assert chain.events == []
      assert is_binary(chain.id)
      assert %DateTime{} = chain.created_at
      assert %DateTime{} = chain.updated_at
    end

    test "creates a chain with options" do
      chain =
        Chain.new("Test Chain",
          description: "A test chain",
          metadata: %{key: "value"}
        )

      assert chain.description == "A test chain"
      assert chain.metadata == %{key: "value"}
    end
  end

  describe "add_event/2" do
    test "adds an event to the chain" do
      chain = Chain.new("Test Chain")
      event = Event.new(:hypothesis_formed, "Decision", "Reasoning")

      updated_chain = Chain.add_event(chain, event)

      assert length(updated_chain.events) == 1
      assert hd(updated_chain.events) == event
      assert DateTime.compare(updated_chain.updated_at, chain.updated_at) in [:gt, :eq]
    end

    test "adds multiple events" do
      chain = Chain.new("Test Chain")
      event1 = Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1")
      event2 = Event.new(:pattern_applied, "Decision 2", "Reasoning 2")

      chain =
        chain
        |> Chain.add_event(event1)
        |> Chain.add_event(event2)

      assert length(chain.events) == 2
      assert Enum.at(chain.events, 0) == event1
      assert Enum.at(chain.events, 1) == event2
    end
  end

  describe "add_events/2" do
    test "adds multiple events at once" do
      chain = Chain.new("Test Chain")

      events = [
        Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1"),
        Event.new(:pattern_applied, "Decision 2", "Reasoning 2")
      ]

      updated_chain = Chain.add_events(chain, events)

      assert length(updated_chain.events) == 2
    end
  end

  describe "get_event/2" do
    test "retrieves an event by ID" do
      event = Event.new(:hypothesis_formed, "Decision", "Reasoning")
      chain = Chain.new("Test Chain") |> Chain.add_event(event)

      assert {:ok, retrieved} = Chain.get_event(chain, event.id)
      assert retrieved == event
    end

    test "returns error for non-existent event" do
      chain = Chain.new("Test Chain")
      assert :error = Chain.get_event(chain, "non-existent-id")
    end
  end

  describe "get_events_by_type/2" do
    test "filters events by type" do
      chain = Chain.new("Test Chain")
      event1 = Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1")
      event2 = Event.new(:pattern_applied, "Decision 2", "Reasoning 2")
      event3 = Event.new(:hypothesis_formed, "Decision 3", "Reasoning 3")

      chain = Chain.add_events(chain, [event1, event2, event3])

      hypotheses = Chain.get_events_by_type(chain, :hypothesis_formed)

      assert length(hypotheses) == 2
      assert event1 in hypotheses
      assert event3 in hypotheses
    end
  end

  describe "statistics/1" do
    test "returns empty statistics for empty chain" do
      chain = Chain.new("Test Chain")
      stats = Chain.statistics(chain)

      assert stats.total_events == 0
    end

    test "calculates statistics for chain with events" do
      chain = Chain.new("Test Chain")

      events = [
        Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1", confidence: 0.8),
        Event.new(:pattern_applied, "Decision 2", "Reasoning 2", confidence: 0.9),
        Event.new(:hypothesis_formed, "Decision 3", "Reasoning 3", confidence: 0.7)
      ]

      chain = Chain.add_events(chain, events)
      stats = Chain.statistics(chain)

      assert stats.total_events == 3
      assert stats.event_type_counts[:hypothesis_formed] == 2
      assert stats.event_type_counts[:pattern_applied] == 1
      assert_in_delta stats.avg_confidence, 0.8, 0.01
      assert stats.duration_seconds >= 0
    end
  end

  describe "find_decision_points/1" do
    test "finds decision points with alternatives" do
      chain = Chain.new("Test Chain")

      events = [
        Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1", alternatives: ["Alt1", "Alt2"]),
        Event.new(:pattern_applied, "Decision 2", "Reasoning 2"),
        Event.new(:alternative_rejected, "Decision 3", "Reasoning 3", alternatives: ["Alt3"])
      ]

      chain = Chain.add_events(chain, events)
      decision_points = Chain.find_decision_points(chain)

      assert length(decision_points) == 2
      assert Enum.any?(decision_points, &(&1.decision == "Decision 1"))
      assert Enum.any?(decision_points, &(&1.decision == "Decision 3"))
    end
  end

  describe "find_low_confidence/2" do
    test "finds events below confidence threshold" do
      chain = Chain.new("Test Chain")

      events = [
        Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1", confidence: 0.9),
        Event.new(:pattern_applied, "Decision 2", "Reasoning 2", confidence: 0.6),
        Event.new(:hypothesis_formed, "Decision 3", "Reasoning 3", confidence: 0.5)
      ]

      chain = Chain.add_events(chain, events)
      low_conf = Chain.find_low_confidence(chain, 0.7)

      assert length(low_conf) == 2
      assert Enum.all?(low_conf, &(&1.confidence < 0.7))
    end
  end

  describe "merge/2" do
    test "merges two chains" do
      chain1 = Chain.new("Chain 1", metadata: %{a: 1})
      chain2 = Chain.new("Chain 2", metadata: %{b: 2})

      event1 = Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1")
      event2 = Event.new(:pattern_applied, "Decision 2", "Reasoning 2")

      chain1 = Chain.add_event(chain1, event1)
      chain2 = Chain.add_event(chain2, event2)

      merged = Chain.merge(chain1, chain2)

      assert length(merged.events) == 2
      assert merged.metadata == %{a: 1, b: 2}
    end
  end

  describe "filter_events/2" do
    test "filters events based on predicate" do
      chain = Chain.new("Test Chain")

      events = [
        Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1", confidence: 0.9),
        Event.new(:pattern_applied, "Decision 2", "Reasoning 2", confidence: 0.6),
        Event.new(:hypothesis_formed, "Decision 3", "Reasoning 3", confidence: 0.8)
      ]

      chain = Chain.add_events(chain, events)
      filtered = Chain.filter_events(chain, fn e -> e.confidence > 0.7 end)

      assert length(filtered.events) == 2
    end
  end

  describe "sort_by_timestamp/2" do
    test "sorts events by timestamp ascending" do
      chain = Chain.new("Test Chain")

      # Add events with small delays to ensure different timestamps
      event1 = Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1")
      Process.sleep(10)
      event2 = Event.new(:pattern_applied, "Decision 2", "Reasoning 2")
      Process.sleep(10)
      event3 = Event.new(:hypothesis_formed, "Decision 3", "Reasoning 3")

      # Add in reverse order
      chain = Chain.add_events(chain, [event3, event1, event2])
      sorted = Chain.sort_by_timestamp(chain, :asc)

      timestamps = Enum.map(sorted.events, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps, DateTime)
    end

    test "sorts events by timestamp descending" do
      chain = Chain.new("Test Chain")

      event1 = Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1")
      Process.sleep(10)
      event2 = Event.new(:pattern_applied, "Decision 2", "Reasoning 2")

      chain = Chain.add_events(chain, [event1, event2])
      sorted = Chain.sort_by_timestamp(chain, :desc)

      timestamps = Enum.map(sorted.events, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps, {:desc, DateTime})
    end
  end

  describe "to_map/1 and from_map/1" do
    test "converts chain to map and back" do
      original = Chain.new("Test Chain", description: "Description")
      event = Event.new(:hypothesis_formed, "Decision", "Reasoning")
      original = Chain.add_event(original, event)

      map = Chain.to_map(original)
      restored = Chain.from_map(map)

      assert restored.name == original.name
      assert restored.description == original.description
      assert length(restored.events) == 1
    end
  end
end
