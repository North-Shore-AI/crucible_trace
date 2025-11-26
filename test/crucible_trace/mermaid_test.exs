defmodule CrucibleTrace.MermaidTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.{Chain, Event, Mermaid}

  describe "to_flowchart/2" do
    test "generates basic flowchart syntax" do
      chain = create_sample_chain()
      mermaid = Mermaid.to_flowchart(chain)

      assert is_binary(mermaid)
      assert mermaid =~ "flowchart TD"
      assert mermaid =~ "Decision 1"
      assert mermaid =~ "Decision 2"
    end

    test "escapes special characters in labels" do
      event = Event.new(:hypothesis_formed, "Use \"quoted\" text", "Reasoning")
      chain = Chain.new("Test") |> Chain.add_event(event)

      mermaid = Mermaid.to_flowchart(chain)

      assert mermaid =~ "quoted"
      refute mermaid =~ "\""
    end

    test "includes confidence when requested" do
      chain = create_sample_chain()
      mermaid = Mermaid.to_flowchart(chain, include_confidence: true)

      assert mermaid =~ "0.8"
      assert mermaid =~ "0.9"
    end

    test "colors events by type" do
      chain = create_sample_chain()
      mermaid = Mermaid.to_flowchart(chain, color_by_type: true)

      assert mermaid =~ "classDef"
      assert mermaid =~ "hypothesis"
      assert mermaid =~ "pattern"
    end

    test "truncates long labels" do
      long_decision = String.duplicate("x", 200)
      event = Event.new(:hypothesis_formed, long_decision, "Reasoning")
      chain = Chain.new("Test") |> Chain.add_event(event)

      mermaid = Mermaid.to_flowchart(chain, max_label_length: 50)

      assert mermaid =~ "..."
      refute String.contains?(mermaid, String.duplicate("x", 100))
    end

    test "handles empty chain" do
      chain = Chain.new("Empty")
      mermaid = Mermaid.to_flowchart(chain)

      assert mermaid =~ "flowchart TD"
      assert mermaid =~ "No events"
    end
  end

  describe "to_sequence/2" do
    test "generates sequence diagram syntax" do
      chain = create_sample_chain()
      mermaid = Mermaid.to_sequence(chain)

      assert is_binary(mermaid)
      assert mermaid =~ "sequenceDiagram"
      assert mermaid =~ "Decision 1"
      assert mermaid =~ "Decision 2"
    end

    test "includes alternatives as notes" do
      event =
        Event.new(:hypothesis_formed, "Decision", "Reasoning", alternatives: ["Alt1", "Alt2"])

      chain = Chain.new("Test") |> Chain.add_event(event)
      mermaid = Mermaid.to_sequence(chain)

      assert mermaid =~ "Note"
      assert mermaid =~ "Alt1"
      assert mermaid =~ "Alt2"
    end
  end

  describe "to_timeline/2" do
    test "generates timeline syntax" do
      chain = create_sample_chain()
      mermaid = Mermaid.to_timeline(chain)

      assert is_binary(mermaid)
      assert mermaid =~ "timeline"
      assert mermaid =~ "title"
    end

    test "groups events by timestamp" do
      event1 = Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1")
      Process.sleep(10)
      event2 = Event.new(:pattern_applied, "Decision 2", "Reasoning 2")

      chain = Chain.new("Test") |> Chain.add_events([event1, event2])
      mermaid = Mermaid.to_timeline(chain)

      assert mermaid =~ "Decision 1"
      assert mermaid =~ "Decision 2"
    end
  end

  describe "to_graph/2" do
    test "generates graph with relationships" do
      # Events with parent relationships would be tested here
      # For now, test basic graph generation
      chain = create_sample_chain()
      mermaid = Mermaid.to_graph(chain)

      assert is_binary(mermaid)
      assert mermaid =~ "graph"
    end
  end

  describe "escape_label/1" do
    test "escapes special characters" do
      assert Mermaid.escape_label("test\"quote\"") == "test&quot;quote&quot;"
      assert Mermaid.escape_label("line1\nline2") == "line1<br/>line2"
      assert Mermaid.escape_label("a<b>c") == "a&lt;b&gt;c"
    end

    test "handles nil" do
      assert Mermaid.escape_label(nil) == ""
    end
  end

  describe "truncate_label/2" do
    test "truncates long text" do
      long_text = String.duplicate("x", 100)
      truncated = Mermaid.truncate_label(long_text, 50)

      # 50 + "..."
      assert String.length(truncated) <= 53
      assert truncated =~ "..."
    end

    test "preserves short text" do
      short_text = "short"
      assert Mermaid.truncate_label(short_text, 50) == short_text
    end
  end

  # Helper functions

  defp create_sample_chain do
    event1 = Event.new(:hypothesis_formed, "Decision 1", "Reasoning 1", confidence: 0.8)
    event2 = Event.new(:pattern_applied, "Decision 2", "Reasoning 2", confidence: 0.9)

    Chain.new("Sample Chain")
    |> Chain.add_events([event1, event2])
  end
end
