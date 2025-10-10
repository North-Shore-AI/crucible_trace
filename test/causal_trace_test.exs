defmodule CausalTraceTest do
  use ExUnit.Case
  doctest CrucibleTrace

  describe "integration test: full workflow" do
    test "creates, parses, and visualizes a complete chain" do
      # Create a chain manually
      chain = CrucibleTrace.new_chain("API Implementation")

      # Add events
      event1 =
        CrucibleTrace.create_event(
          :hypothesis_formed,
          "Use REST API with JSON",
          "Standard approach, widely supported",
          alternatives: ["GraphQL", "gRPC"],
          confidence: 0.85
        )

      event2 =
        CrucibleTrace.create_event(
          :pattern_applied,
          "Apply MVC pattern",
          "Separates concerns effectively",
          confidence: 0.9
        )

      chain =
        chain
        |> CrucibleTrace.add_event(event1)
        |> CrucibleTrace.add_event(event2)

      # Verify chain
      assert length(chain.events) == 2
      stats = CrucibleTrace.statistics(chain)
      assert stats.total_events == 2
      assert stats.avg_confidence > 0.8

      # Generate visualization
      html = CrucibleTrace.visualize(chain)
      assert html =~ "API Implementation"
      assert html =~ "Use REST API with JSON"
      assert html =~ "Apply MVC pattern"
    end

    test "parses LLM output and creates chain" do
      llm_output = """
      <event type="hypothesis_formed">
        <decision>Use GenServer for state management</decision>
        <alternatives>Agent, ETS table</alternatives>
        <reasoning>Need concurrent access and OTP supervision</reasoning>
        <confidence>0.9</confidence>
        <code_section>StateManager</code_section>
      </event>

      <event type="constraint_evaluated">
        <decision>Limit concurrent connections to 100</decision>
        <reasoning>Prevent resource exhaustion</reasoning>
        <confidence>0.95</confidence>
      </event>

      <code>
      defmodule StateManager do
        use GenServer
        def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end
      </code>
      """

      # Parse into chain
      assert {:ok, chain} =
               CrucibleTrace.parse_llm_output(llm_output, "State Manager Implementation")

      assert chain.name == "State Manager Implementation"
      assert length(chain.events) == 2

      # Extract code
      code = CrucibleTrace.extract_code(llm_output)
      assert code =~ "defmodule StateManager"
      refute code =~ "<event"

      # Analyze decision points
      decisions = CrucibleTrace.find_decision_points(chain)
      assert length(decisions) == 1
      assert hd(decisions).alternatives == ["Agent", "ETS table"]
    end

    test "filters and analyzes chain events" do
      chain = CrucibleTrace.new_chain("Analysis Test")

      events = [
        CrucibleTrace.create_event(:hypothesis_formed, "D1", "R1", confidence: 0.9),
        CrucibleTrace.create_event(:pattern_applied, "D2", "R2", confidence: 0.6),
        CrucibleTrace.create_event(:hypothesis_formed, "D3", "R3", confidence: 0.8),
        CrucibleTrace.create_event(:ambiguity_flagged, "D4", "R4", confidence: 0.5)
      ]

      chain = CrucibleTrace.add_events(chain, events)

      # Filter by type
      hypotheses = CrucibleTrace.get_events_by_type(chain, :hypothesis_formed)
      assert length(hypotheses) == 2

      # Find low confidence
      low_conf = CrucibleTrace.find_low_confidence(chain, 0.7)
      assert length(low_conf) == 2

      # Custom filter
      high_conf_chain = CrucibleTrace.filter_events(chain, fn e -> e.confidence >= 0.8 end)
      assert length(high_conf_chain.events) == 2
    end
  end

  describe "prompt building" do
    test "builds a causal prompt with instructions" do
      spec = "Implement a caching layer for database queries"
      prompt = CrucibleTrace.build_causal_prompt(spec)

      assert prompt =~ spec
      assert prompt =~ "For each significant decision"
      assert prompt =~ "<event type="
      assert prompt =~ "hypothesis_formed"
      assert prompt =~ "alternative_rejected"
      assert prompt =~ "pattern_applied"
      assert prompt =~ "<decision>"
      assert prompt =~ "<alternatives>"
      assert prompt =~ "<reasoning>"
      assert prompt =~ "<confidence>"
    end
  end

  describe "serialization" do
    test "converts chain to map and back preserves data" do
      original = CrucibleTrace.new_chain("Test", description: "Description")
      event = CrucibleTrace.create_event(:hypothesis_formed, "Decision", "Reasoning")
      original = CrucibleTrace.add_event(original, event)

      # Convert to map
      map = CrucibleTrace.chain_to_map(original)
      assert is_map(map)
      assert map.name == "Test"

      # Convert back
      restored = CrucibleTrace.chain_from_map(map)
      assert restored.name == original.name
      assert restored.description == original.description
      assert length(restored.events) == 1
    end

    test "converts event to map and back preserves data" do
      original =
        CrucibleTrace.create_event(
          :pattern_applied,
          "Use Supervisor",
          "Fault tolerance",
          alternatives: ["Manual restart"],
          confidence: 0.85
        )

      map = CrucibleTrace.event_to_map(original)
      restored = CrucibleTrace.event_from_map(map)

      assert restored.type == original.type
      assert restored.decision == original.decision
      assert restored.reasoning == original.reasoning
      assert restored.alternatives == original.alternatives
      assert restored.confidence == original.confidence
    end
  end

  describe "chain merging" do
    test "merges two chains combining events" do
      chain1 =
        CrucibleTrace.new_chain("Chain 1")
        |> CrucibleTrace.add_event(CrucibleTrace.create_event(:hypothesis_formed, "D1", "R1"))

      chain2 =
        CrucibleTrace.new_chain("Chain 2")
        |> CrucibleTrace.add_event(CrucibleTrace.create_event(:pattern_applied, "D2", "R2"))

      merged = CrucibleTrace.merge_chains(chain1, chain2)

      assert length(merged.events) == 2
      assert merged.name == "Chain 1"
    end
  end
end
