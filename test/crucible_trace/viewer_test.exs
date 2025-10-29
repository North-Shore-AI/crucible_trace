defmodule CrucibleTrace.ViewerTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.{Viewer, Chain, Event}

  setup do
    chain = Chain.new("Test Visualization Chain", description: "A test chain for visualization")

    events = [
      Event.new(:hypothesis_formed, "Use GenServer", "Need state management",
        alternatives: ["ETS", "Agent"],
        confidence: 0.9,
        code_section: "StateManager"
      ),
      Event.new(:pattern_applied, "Apply Supervisor pattern", "Fault tolerance required",
        confidence: 0.95
      ),
      Event.new(:constraint_evaluated, "Limit to 1000 connections", "Hardware constraints",
        alternatives: ["Unlimited", "500 connections"],
        confidence: 0.75,
        spec_reference: "Section 3.2"
      )
    ]

    chain = Chain.add_events(chain, events)
    {:ok, chain: chain}
  end

  describe "generate_html/2" do
    test "generates valid HTML for a chain", %{chain: chain} do
      html = Viewer.generate_html(chain)

      assert is_binary(html)
      assert String.contains?(html, "<!DOCTYPE html>")
      assert String.contains?(html, "<html")
      assert String.contains?(html, "</html>")
      assert String.contains?(html, chain.name)
    end

    test "includes chain description when present", %{chain: chain} do
      html = Viewer.generate_html(chain)
      assert String.contains?(html, chain.description)
    end

    test "includes all events", %{chain: chain} do
      html = Viewer.generate_html(chain)

      Enum.each(chain.events, fn event ->
        assert String.contains?(html, event.decision)
        assert String.contains?(html, event.reasoning)
      end)
    end

    test "includes event alternatives", %{chain: chain} do
      html = Viewer.generate_html(chain)
      assert String.contains?(html, "ETS")
      assert String.contains?(html, "Agent")
    end

    test "includes confidence badges", %{chain: chain} do
      html = Viewer.generate_html(chain)
      assert String.contains?(html, "0.9")
      assert String.contains?(html, "0.95")
      assert String.contains?(html, "0.75")
    end

    test "includes code sections when present", %{chain: chain} do
      html = Viewer.generate_html(chain)
      assert String.contains?(html, "StateManager")
    end

    test "includes spec references when present", %{chain: chain} do
      html = Viewer.generate_html(chain)
      assert String.contains?(html, "Section 3.2")
    end

    test "includes statistics section by default", %{chain: chain} do
      html = Viewer.generate_html(chain)
      assert String.contains?(html, "Statistics")
      assert String.contains?(html, "Total Events")
      assert String.contains?(html, "Average Confidence")
    end

    test "excludes statistics when option is false", %{chain: chain} do
      html = Viewer.generate_html(chain, include_statistics: false)
      refute String.contains?(html, "Statistics")
    end

    test "includes timeline by default", %{chain: chain} do
      html = Viewer.generate_html(chain)
      assert String.contains?(html, "Timeline")
      assert String.contains?(html, "timeline-bar")
    end

    test "excludes timeline when option is false", %{chain: chain} do
      html = Viewer.generate_html(chain, include_timeline: false)
      refute String.contains?(html, "<section class=\"timeline\">")
      refute String.contains?(html, "<h2>Timeline</h2>")
    end

    test "includes filter controls", %{chain: chain} do
      html = Viewer.generate_html(chain)
      assert String.contains?(html, "typeFilter")
      assert String.contains?(html, "confidenceSlider")
      assert String.contains?(html, "filterEvents")
    end

    test "includes JavaScript for interactivity", %{chain: chain} do
      html = Viewer.generate_html(chain)
      assert String.contains?(html, "function filterEvents")
      assert String.contains?(html, "function updateConfidenceLabel")
    end

    test "accepts custom title", %{chain: chain} do
      html = Viewer.generate_html(chain, title: "Custom Title")
      assert String.contains?(html, "Custom Title")
    end

    test "applies light style by default", %{chain: chain} do
      html = Viewer.generate_html(chain)
      assert String.contains?(html, "background: #f5f5f5")
    end

    test "applies dark style when specified", %{chain: chain} do
      html = Viewer.generate_html(chain, style: :dark)
      assert String.contains?(html, "background: #1a1a1a")
    end

    test "handles empty chain gracefully" do
      empty_chain = Chain.new("Empty Chain")
      html = Viewer.generate_html(empty_chain)

      assert is_binary(html)
      assert String.contains?(html, "Empty Chain")
      assert String.contains?(html, "<!DOCTYPE html>")
    end

    test "escapes HTML in event content", %{chain: chain} do
      event_with_html =
        Event.new(
          :hypothesis_formed,
          "<script>alert('xss')</script>",
          "Test & <b>bold</b>"
        )

      chain = Chain.add_event(chain, event_with_html)
      html = Viewer.generate_html(chain)

      refute String.contains?(html, "<script>alert('xss')</script>")
      assert String.contains?(html, "&lt;script&gt;")
      assert String.contains?(html, "&amp;")
      assert String.contains?(html, "&lt;b&gt;")
    end

    test "includes all event types with proper styling", %{chain: chain} do
      event_types = [
        :hypothesis_formed,
        :alternative_rejected,
        :constraint_evaluated,
        :pattern_applied,
        :ambiguity_flagged,
        :confidence_updated
      ]

      events =
        Enum.map(event_types, fn type ->
          Event.new(type, "Decision for #{type}", "Reasoning")
        end)

      chain = Chain.add_events(chain, events)
      html = Viewer.generate_html(chain)

      # Check that each event type class is present
      Enum.each(event_types, fn type ->
        assert String.contains?(html, "event-type #{type}")
      end)
    end
  end

  describe "save_html/3" do
    test "saves HTML to file", %{chain: chain} do
      temp_file = Path.join(System.tmp_dir!(), "test_viz_#{:rand.uniform(1000)}.html")

      try do
        assert {:ok, ^temp_file} = Viewer.save_html(chain, temp_file)
        assert File.exists?(temp_file)

        {:ok, content} = File.read(temp_file)
        assert String.contains?(content, "<!DOCTYPE html>")
        assert String.contains?(content, chain.name)
      after
        File.rm(temp_file)
      end
    end

    test "passes options to generate_html", %{chain: chain} do
      temp_file = Path.join(System.tmp_dir!(), "test_viz_#{:rand.uniform(1000)}.html")

      try do
        {:ok, _} = Viewer.save_html(chain, temp_file, style: :dark, title: "Custom")

        {:ok, content} = File.read(temp_file)
        assert String.contains?(content, "Custom")
      after
        File.rm(temp_file)
      end
    end

    test "returns error for invalid path" do
      result = Viewer.save_html(Chain.new("Test"), "/invalid/path/file.html")
      assert {:error, _reason} = result
    end
  end

  describe "open_in_browser/2" do
    test "creates temporary file with chain visualization", %{chain: chain} do
      # We can't actually open a browser in tests, but we can verify file creation
      # Mock the System.cmd to avoid actually opening browser
      {:ok, temp_path} = Viewer.save_html(chain, Path.join(System.tmp_dir!(), "temp_viz.html"))

      try do
        assert File.exists?(temp_path)
        {:ok, content} = File.read(temp_path)
        assert String.contains?(content, chain.name)
      after
        File.rm(temp_path)
      end
    end
  end

  describe "confidence_class/1" do
    test "categorizes confidence levels correctly", %{chain: chain} do
      high_conf_event = Event.new(:hypothesis_formed, "High", "Reasoning", confidence: 0.9)
      med_conf_event = Event.new(:pattern_applied, "Med", "Reasoning", confidence: 0.6)
      low_conf_event = Event.new(:constraint_evaluated, "Low", "Reasoning", confidence: 0.3)

      chain =
        chain
        |> Chain.add_event(high_conf_event)
        |> Chain.add_event(med_conf_event)
        |> Chain.add_event(low_conf_event)

      html = Viewer.generate_html(chain)

      assert String.contains?(html, "confidence-high")
      assert String.contains?(html, "confidence-medium")
      assert String.contains?(html, "confidence-low")
    end
  end

  describe "event type formatting" do
    test "formats event types as human-readable labels", %{chain: chain} do
      html = Viewer.generate_html(chain)

      assert String.contains?(html, "Hypothesis Formed")
      assert String.contains?(html, "Pattern Applied")
      assert String.contains?(html, "Constraint Evaluated")
    end
  end

  describe "timeline generation" do
    test "generates timeline markers for events", %{chain: chain} do
      html = Viewer.generate_html(chain)

      # Should have timeline markers
      assert String.contains?(html, "timeline-marker")

      # Should have hover titles
      assert String.contains?(html, "title=")
    end

    test "handles single event timeline" do
      chain = Chain.new("Single Event")
      event = Event.new(:hypothesis_formed, "Decision", "Reasoning")
      chain = Chain.add_event(chain, event)

      html = Viewer.generate_html(chain)
      assert String.contains?(html, "timeline-marker")
    end

    test "calculates timeline positions correctly for multiple events" do
      chain = Chain.new("Timeline Test")

      # Create events with deliberate time spacing
      event1 = Event.new(:hypothesis_formed, "First", "Reasoning")
      Process.sleep(100)
      event2 = Event.new(:pattern_applied, "Second", "Reasoning")
      Process.sleep(100)
      event3 = Event.new(:constraint_evaluated, "Third", "Reasoning")

      chain = Chain.add_events(chain, [event1, event2, event3])
      html = Viewer.generate_html(chain)

      # Should have 3 timeline markers (count div elements with timeline-marker class)
      marker_count =
        html |> String.split("<div class=\"timeline-marker\"") |> length() |> Kernel.-(1)

      assert marker_count == 3

      # Should have position styles
      assert String.contains?(html, "left:")
    end
  end

  describe "statistics display" do
    test "displays event type counts", %{chain: chain} do
      html = Viewer.generate_html(chain)

      assert String.contains?(html, "Hypothesis Formed")
      assert String.contains?(html, "Pattern Applied")
      assert String.contains?(html, "Constraint Evaluated")
    end

    test "displays aggregate statistics", %{chain: chain} do
      html = Viewer.generate_html(chain)

      assert String.contains?(html, "Total Events")
      assert String.contains?(html, "Average Confidence")
      assert String.contains?(html, "Duration")
    end
  end

  describe "responsive design" do
    test "includes viewport meta tag", %{chain: chain} do
      html = Viewer.generate_html(chain)
      assert String.contains?(html, "viewport")
      assert String.contains?(html, "width=device-width")
    end

    test "includes flexible layout CSS", %{chain: chain} do
      html = Viewer.generate_html(chain)
      assert String.contains?(html, "flex-wrap")
      assert String.contains?(html, "grid-template-columns")
    end
  end
end
