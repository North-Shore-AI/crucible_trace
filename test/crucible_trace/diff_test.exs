defmodule CrucibleTrace.DiffTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.{Chain, Event, Diff}

  describe "compare/3" do
    test "compares two identical chains" do
      chain1 = create_sample_chain()
      chain2 = create_sample_chain()

      {:ok, diff} = Diff.compare(chain1, chain2)

      assert diff.added_events == []
      assert diff.removed_events == []
      assert diff.modified_events == []
      assert diff.similarity_score == 1.0
    end

    test "detects added events" do
      chain1 = Chain.new("Test") |> Chain.add_event(event1())
      chain2 = Chain.new("Test") |> Chain.add_events([event1(), event2()])

      {:ok, diff} = Diff.compare(chain1, chain2)

      assert length(diff.added_events) == 1
      assert hd(diff.added_events).decision == "Decision 2"
      assert diff.removed_events == []
    end

    test "detects removed events" do
      chain1 = Chain.new("Test") |> Chain.add_events([event1(), event2()])
      chain2 = Chain.new("Test") |> Chain.add_event(event1())

      {:ok, diff} = Diff.compare(chain1, chain2)

      assert length(diff.removed_events) == 1
      assert hd(diff.removed_events).decision == "Decision 2"
      assert diff.added_events == []
    end

    test "detects modified events with different decisions" do
      event_a = Event.new(:hypothesis_formed, "Use GenServer", "Reasoning A")
      event_b = %{event_a | decision: "Use Agent"}

      chain1 = Chain.new("Test") |> Chain.add_event(event_a)
      chain2 = Chain.new("Test") |> Chain.add_event(event_b)

      {:ok, diff} = Diff.compare(chain1, chain2)

      assert length(diff.modified_events) == 1
      {event_id, changes} = hd(diff.modified_events)
      assert event_id == event_a.id
      assert changes[:decision] == {:changed, "Use GenServer", "Use Agent"}
    end

    test "detects confidence deltas" do
      event_a = Event.new(:hypothesis_formed, "Decision", "Reasoning", confidence: 0.8)
      event_b = %{event_a | confidence: 0.9}

      chain1 = Chain.new("Test") |> Chain.add_event(event_a)
      chain2 = Chain.new("Test") |> Chain.add_event(event_b)

      {:ok, diff} = Diff.compare(chain1, chain2)

      assert diff.confidence_deltas[event_a.id] == 0.1
    end

    test "calculates similarity score" do
      chain1 = Chain.new("Test") |> Chain.add_events([event1(), event2()])
      chain2 = Chain.new("Test") |> Chain.add_event(event1())

      {:ok, diff} = Diff.compare(chain1, chain2)

      # 50% similar (1 shared, 1 removed)
      assert diff.similarity_score >= 0.4 and diff.similarity_score <= 0.6
    end

    test "generates summary text" do
      chain1 = Chain.new("Test") |> Chain.add_event(event1())
      chain2 = Chain.new("Test") |> Chain.add_events([event1(), event2()])

      {:ok, diff} = Diff.compare(chain1, chain2)

      assert is_binary(diff.summary)
      assert diff.summary =~ "1 added"
      assert diff.summary =~ "0 removed"
    end
  end

  describe "to_text/1" do
    test "formats diff as readable text" do
      chain1 = Chain.new("Test") |> Chain.add_event(event1())
      chain2 = Chain.new("Test") |> Chain.add_events([event1(), event2()])

      {:ok, diff} = Diff.compare(chain1, chain2)
      text = Diff.to_text(diff)

      assert is_binary(text)
      assert text =~ "Added Events"
      assert text =~ "Decision 2"
    end
  end

  describe "to_html/3" do
    test "generates HTML diff view" do
      chain1 = Chain.new("Test") |> Chain.add_event(event1())
      chain2 = Chain.new("Test") |> Chain.add_events([event1(), event2()])

      {:ok, diff} = Diff.compare(chain1, chain2)
      html = Diff.to_html(diff, chain1, chain2)

      assert is_binary(html)
      assert html =~ "<html"
      assert html =~ "Diff"
      assert html =~ "Added"
    end
  end

  # Helper functions

  defp create_sample_chain do
    Chain.new("Sample Chain")
    |> Chain.add_events([event1(), event2()])
  end

  defp event1 do
    Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1", confidence: 0.8)
  end

  defp event2 do
    Event.new(:pattern_applied, "Decision 2", "Reasoning 2", confidence: 0.9)
  end
end
