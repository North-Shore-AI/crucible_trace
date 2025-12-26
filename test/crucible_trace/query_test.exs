defmodule CrucibleTrace.QueryTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.{Chain, Event, Query}

  describe "search_events/3" do
    setup do
      chain =
        Chain.new("Test")
        |> Chain.add_event(Event.new(:hypothesis_formed, "Use GenServer", "State management"))
        |> Chain.add_event(Event.new(:pattern_applied, "Apply Supervisor", "Fault tolerance"))
        |> Chain.add_event(Event.new(:training_started, "Train model", "Start training"))

      {:ok, chain: chain}
    end

    test "finds events by content substring in decision", %{chain: chain} do
      events = Query.search_events(chain, "GenServer")
      assert length(events) == 1
      assert hd(events).decision == "Use GenServer"
    end

    test "finds events by content substring in reasoning", %{chain: chain} do
      events = Query.search_events(chain, "Fault tolerance")
      assert length(events) == 1
      assert hd(events).reasoning == "Fault tolerance"
    end

    test "case insensitive search", %{chain: chain} do
      events = Query.search_events(chain, "genserver")
      assert length(events) == 1
    end

    test "returns empty list when no match", %{chain: chain} do
      events = Query.search_events(chain, "nonexistent")
      assert events == []
    end

    test "filters by event type", %{chain: chain} do
      events = Query.search_events(chain, "", type: :training_started)
      assert length(events) == 1
      assert hd(events).type == :training_started
    end

    test "filters by multiple event types", %{chain: chain} do
      events = Query.search_events(chain, "", type: [:hypothesis_formed, :pattern_applied])
      assert length(events) == 2
    end

    test "filters by min_confidence" do
      chain =
        Chain.new("Test")
        |> Chain.add_event(Event.new(:hypothesis_formed, "High conf", "Test", confidence: 0.9))
        |> Chain.add_event(Event.new(:hypothesis_formed, "Low conf", "Test", confidence: 0.5))

      events = Query.search_events(chain, "", min_confidence: 0.8)
      assert length(events) == 1
      assert hd(events).decision == "High conf"
    end

    test "filters by max_confidence" do
      chain =
        Chain.new("Test")
        |> Chain.add_event(Event.new(:hypothesis_formed, "High conf", "Test", confidence: 0.9))
        |> Chain.add_event(Event.new(:hypothesis_formed, "Low conf", "Test", confidence: 0.5))

      events = Query.search_events(chain, "", max_confidence: 0.6)
      assert length(events) == 1
      assert hd(events).decision == "Low conf"
    end

    test "filters by stage_id" do
      chain =
        Chain.new("Test")
        |> Chain.add_event(Event.new(:hypothesis_formed, "Stage A", "Test", stage_id: "stage-a"))
        |> Chain.add_event(Event.new(:hypothesis_formed, "Stage B", "Test", stage_id: "stage-b"))

      events = Query.search_events(chain, "", stage_id: "stage-a")
      assert length(events) == 1
      assert hd(events).decision == "Stage A"
    end

    test "filters by experiment_id" do
      chain =
        Chain.new("Test")
        |> Chain.add_event(
          Event.new(:hypothesis_formed, "Exp 1", "Test", experiment_id: "exp-001")
        )
        |> Chain.add_event(
          Event.new(:hypothesis_formed, "Exp 2", "Test", experiment_id: "exp-002")
        )

      events = Query.search_events(chain, "", experiment_id: "exp-001")
      assert length(events) == 1
      assert hd(events).decision == "Exp 1"
    end

    test "combines multiple filters" do
      chain =
        Chain.new("Test")
        |> Chain.add_event(
          Event.new(:hypothesis_formed, "Match", "Test",
            confidence: 0.9,
            stage_id: "stage-a"
          )
        )
        |> Chain.add_event(
          Event.new(:hypothesis_formed, "No match", "Test",
            confidence: 0.5,
            stage_id: "stage-a"
          )
        )

      events =
        Query.search_events(chain, "Match",
          min_confidence: 0.8,
          stage_id: "stage-a"
        )

      assert length(events) == 1
      assert hd(events).decision == "Match"
    end
  end

  describe "search_regex/3" do
    test "searches with regex pattern" do
      chain =
        Chain.new("Test")
        |> Chain.add_event(Event.new(:hypothesis_formed, "Use GenServer v1", "Reason"))
        |> Chain.add_event(Event.new(:hypothesis_formed, "Use GenServer v2", "Reason"))
        |> Chain.add_event(Event.new(:hypothesis_formed, "Use Agent", "Reason"))

      events = Query.search_regex(chain, ~r/GenServer v\d/)
      assert length(events) == 2
    end

    test "case insensitive regex search" do
      chain =
        Chain.new("Test")
        |> Chain.add_event(Event.new(:hypothesis_formed, "Use GENSERVER", "Reason"))

      events = Query.search_regex(chain, ~r/genserver/i)
      assert length(events) == 1
    end

    test "applies filters with regex" do
      chain =
        Chain.new("Test")
        |> Chain.add_event(
          Event.new(:hypothesis_formed, "GenServer v1", "Reason", confidence: 0.9)
        )
        |> Chain.add_event(
          Event.new(:hypothesis_formed, "GenServer v2", "Reason", confidence: 0.5)
        )

      events = Query.search_regex(chain, ~r/GenServer/, min_confidence: 0.8)
      assert length(events) == 1
    end
  end

  describe "query/2" do
    setup do
      chain =
        Chain.new("Test")
        |> Chain.add_event(
          Event.new(:hypothesis_formed, "Decision A", "Reason A",
            confidence: 0.9,
            stage_id: "stage-1"
          )
        )
        |> Chain.add_event(
          Event.new(:pattern_applied, "Decision B", "Reason B",
            confidence: 0.7,
            stage_id: "stage-2"
          )
        )
        |> Chain.add_event(
          Event.new(:ambiguity_flagged, "Decision C", "Reason C",
            confidence: 0.5,
            stage_id: "stage-1"
          )
        )

      {:ok, chain: chain}
    end

    test "query with type filter", %{chain: chain} do
      events = Query.query(chain, %{type: :hypothesis_formed})
      assert length(events) == 1
      assert hd(events).decision == "Decision A"
    end

    test "query with confidence range", %{chain: chain} do
      events = Query.query(chain, %{confidence: {:gte, 0.7}})
      assert length(events) == 2
    end

    test "query with confidence less than", %{chain: chain} do
      events = Query.query(chain, %{confidence: {:lt, 0.6}})
      assert length(events) == 1
      assert hd(events).decision == "Decision C"
    end

    test "query with and logic", %{chain: chain} do
      events =
        Query.query(chain, %{
          and: [
            %{stage_id: "stage-1"},
            %{confidence: {:gte, 0.8}}
          ]
        })

      assert length(events) == 1
      assert hd(events).decision == "Decision A"
    end

    test "query with or logic", %{chain: chain} do
      events =
        Query.query(chain, %{
          or: [
            %{type: :hypothesis_formed},
            %{type: :ambiguity_flagged}
          ]
        })

      assert length(events) == 2
    end

    test "query with content regex", %{chain: chain} do
      events = Query.query(chain, %{content: ~r/Decision [AB]/})
      assert length(events) == 2
    end
  end

  describe "aggregate_by/3" do
    test "aggregates by type with count" do
      chain =
        Chain.new("Test")
        |> Chain.add_event(Event.new(:hypothesis_formed, "A", "R"))
        |> Chain.add_event(Event.new(:hypothesis_formed, "B", "R"))
        |> Chain.add_event(Event.new(:pattern_applied, "C", "R"))

      result = Query.aggregate_by(chain, :type, &length/1)

      assert result[:hypothesis_formed] == 2
      assert result[:pattern_applied] == 1
    end

    test "aggregates by stage_id" do
      chain =
        Chain.new("Test")
        |> Chain.add_event(Event.new(:hypothesis_formed, "A", "R", stage_id: "stage-1"))
        |> Chain.add_event(Event.new(:hypothesis_formed, "B", "R", stage_id: "stage-1"))
        |> Chain.add_event(Event.new(:pattern_applied, "C", "R", stage_id: "stage-2"))

      result = Query.aggregate_by(chain, :stage_id, &length/1)

      assert result["stage-1"] == 2
      assert result["stage-2"] == 1
    end

    test "aggregates with custom function" do
      chain =
        Chain.new("Test")
        |> Chain.add_event(Event.new(:hypothesis_formed, "A", "R", confidence: 0.8))
        |> Chain.add_event(Event.new(:hypothesis_formed, "B", "R", confidence: 0.6))

      avg_fn = fn events ->
        sum = Enum.reduce(events, 0, fn e, acc -> acc + e.confidence end)
        sum / length(events)
      end

      result = Query.aggregate_by(chain, :type, avg_fn)
      assert_in_delta result[:hypothesis_formed], 0.7, 0.01
    end
  end

  describe "edge cases" do
    test "search on empty chain" do
      chain = Chain.new("Empty")
      events = Query.search_events(chain, "anything")
      assert events == []
    end

    test "query on empty chain" do
      chain = Chain.new("Empty")
      events = Query.query(chain, %{type: :hypothesis_formed})
      assert events == []
    end

    test "aggregate on empty chain" do
      chain = Chain.new("Empty")
      result = Query.aggregate_by(chain, :type, &length/1)
      assert result == %{}
    end
  end
end
