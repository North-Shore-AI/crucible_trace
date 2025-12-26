defmodule CrucibleTrace.RelationshipsTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.{Chain, Event}

  describe "event relationships - parent_id" do
    test "creates event with parent_id" do
      parent = Event.new(:hypothesis_formed, "Use OTP", "Standard pattern")

      child =
        Event.new(:pattern_applied, "Use GenServer", "State management", parent_id: parent.id)

      assert child.parent_id == parent.id
    end

    test "parent_id defaults to nil" do
      event = Event.new(:hypothesis_formed, "Decision", "Reason")
      assert event.parent_id == nil
    end
  end

  describe "event relationships - depends_on" do
    test "creates event with depends_on" do
      event1 = Event.new(:hypothesis_formed, "Decision 1", "Reason 1")
      event2 = Event.new(:hypothesis_formed, "Decision 2", "Reason 2")

      event3 =
        Event.new(:pattern_applied, "Depends on both", "Combined",
          depends_on: [event1.id, event2.id]
        )

      assert event3.depends_on == [event1.id, event2.id]
    end

    test "depends_on defaults to empty list" do
      event = Event.new(:hypothesis_formed, "Decision", "Reason")
      assert event.depends_on == []
    end
  end

  describe "event relationships - stage_id and experiment_id" do
    test "creates event with stage_id" do
      event =
        Event.new(:hypothesis_formed, "Decision", "Reason", stage_id: "training-stage-1")

      assert event.stage_id == "training-stage-1"
    end

    test "creates event with experiment_id" do
      event =
        Event.new(:hypothesis_formed, "Decision", "Reason", experiment_id: "exp-001")

      assert event.experiment_id == "exp-001"
    end

    test "stage_id and experiment_id default to nil" do
      event = Event.new(:hypothesis_formed, "Decision", "Reason")
      assert event.stage_id == nil
      assert event.experiment_id == nil
    end
  end

  describe "Chain.get_children/2" do
    test "returns child events" do
      parent = Event.new(:hypothesis_formed, "Parent", "Reason")
      child1 = Event.new(:pattern_applied, "Child 1", "Reason", parent_id: parent.id)
      child2 = Event.new(:pattern_applied, "Child 2", "Reason", parent_id: parent.id)

      chain =
        Chain.new("Test")
        |> Chain.add_events([parent, child1, child2])

      {:ok, children} = Chain.get_children(chain, parent.id)
      assert length(children) == 2
      assert child1 in children
      assert child2 in children
    end

    test "returns empty list when no children" do
      event = Event.new(:hypothesis_formed, "No children", "Reason")

      chain =
        Chain.new("Test")
        |> Chain.add_event(event)

      {:ok, children} = Chain.get_children(chain, event.id)
      assert children == []
    end

    test "returns error for non-existent event" do
      chain = Chain.new("Test")
      assert {:error, _} = Chain.get_children(chain, "non-existent-id")
    end
  end

  describe "Chain.get_parent/2" do
    test "returns parent event" do
      parent = Event.new(:hypothesis_formed, "Parent", "Reason")
      child = Event.new(:pattern_applied, "Child", "Reason", parent_id: parent.id)

      chain =
        Chain.new("Test")
        |> Chain.add_events([parent, child])

      {:ok, found_parent} = Chain.get_parent(chain, child.id)
      assert found_parent.id == parent.id
    end

    test "returns nil for root events" do
      root = Event.new(:hypothesis_formed, "Root", "Reason")

      chain =
        Chain.new("Test")
        |> Chain.add_event(root)

      {:ok, parent} = Chain.get_parent(chain, root.id)
      assert parent == nil
    end
  end

  describe "Chain.get_root_events/1" do
    test "returns events with no parent" do
      root1 = Event.new(:hypothesis_formed, "Root 1", "Reason")
      root2 = Event.new(:hypothesis_formed, "Root 2", "Reason")
      child = Event.new(:pattern_applied, "Child", "Reason", parent_id: root1.id)

      chain =
        Chain.new("Test")
        |> Chain.add_events([root1, root2, child])

      roots = Chain.get_root_events(chain)
      assert length(roots) == 2
      assert root1 in roots
      assert root2 in roots
      refute child in roots
    end

    test "returns all events when none have parents" do
      event1 = Event.new(:hypothesis_formed, "Event 1", "Reason")
      event2 = Event.new(:hypothesis_formed, "Event 2", "Reason")

      chain =
        Chain.new("Test")
        |> Chain.add_events([event1, event2])

      roots = Chain.get_root_events(chain)
      assert length(roots) == 2
    end
  end

  describe "Chain.get_leaf_events/1" do
    test "returns events with no children" do
      parent = Event.new(:hypothesis_formed, "Parent", "Reason")
      leaf1 = Event.new(:pattern_applied, "Leaf 1", "Reason", parent_id: parent.id)
      leaf2 = Event.new(:pattern_applied, "Leaf 2", "Reason", parent_id: parent.id)

      chain =
        Chain.new("Test")
        |> Chain.add_events([parent, leaf1, leaf2])

      leaves = Chain.get_leaf_events(chain)
      assert length(leaves) == 2
      assert leaf1 in leaves
      assert leaf2 in leaves
      refute parent in leaves
    end
  end

  describe "Chain.validate_relationships/1" do
    test "passes for valid relationships" do
      parent = Event.new(:hypothesis_formed, "Parent", "Reason")
      child = Event.new(:pattern_applied, "Child", "Reason", parent_id: parent.id)

      chain =
        Chain.new("Test")
        |> Chain.add_events([parent, child])

      assert {:ok, _chain} = Chain.validate_relationships(chain)
    end

    test "detects circular dependencies via parent_id" do
      # Create two events
      event1 = Event.new(:hypothesis_formed, "Event 1", "Reason")
      event2_base = Event.new(:pattern_applied, "Event 2", "Reason")

      # Manually create circular reference
      event2 = %{event2_base | parent_id: event1.id}
      event1_circular = %{event1 | parent_id: event2.id}

      chain =
        Chain.new("Test")
        |> Chain.add_events([event1_circular, event2])

      assert {:error, reason} = Chain.validate_relationships(chain)
      assert reason =~ "circular" or reason =~ "Circular"
    end

    test "detects circular dependencies via depends_on" do
      event1 = Event.new(:hypothesis_formed, "Event 1", "Reason")
      event2_base = Event.new(:pattern_applied, "Event 2", "Reason")

      event2 = %{event2_base | depends_on: [event1.id]}
      event1_circular = %{event1 | depends_on: [event2.id]}

      chain =
        Chain.new("Test")
        |> Chain.add_events([event1_circular, event2])

      assert {:error, reason} = Chain.validate_relationships(chain)
      assert reason =~ "circular" or reason =~ "Circular"
    end

    test "detects missing parent references" do
      child = Event.new(:pattern_applied, "Child", "Reason", parent_id: "missing-parent-id")

      chain =
        Chain.new("Test")
        |> Chain.add_event(child)

      assert {:error, reason} = Chain.validate_relationships(chain)
      assert reason =~ "missing" or reason =~ "Missing" or reason =~ "not found"
    end

    test "passes for empty chain" do
      chain = Chain.new("Test")
      assert {:ok, _chain} = Chain.validate_relationships(chain)
    end
  end

  describe "Chain.get_events_by_stage/2" do
    test "returns events for a stage" do
      event1 = Event.new(:hypothesis_formed, "Event 1", "Reason", stage_id: "stage-a")
      event2 = Event.new(:pattern_applied, "Event 2", "Reason", stage_id: "stage-a")
      event3 = Event.new(:pattern_applied, "Event 3", "Reason", stage_id: "stage-b")

      chain =
        Chain.new("Test")
        |> Chain.add_events([event1, event2, event3])

      stage_a_events = Chain.get_events_by_stage(chain, "stage-a")
      assert length(stage_a_events) == 2
      assert event1 in stage_a_events
      assert event2 in stage_a_events
    end

    test "returns empty list for non-existent stage" do
      event = Event.new(:hypothesis_formed, "Event", "Reason", stage_id: "stage-a")

      chain =
        Chain.new("Test")
        |> Chain.add_event(event)

      events = Chain.get_events_by_stage(chain, "stage-x")
      assert events == []
    end
  end

  describe "Chain.get_events_by_experiment/2" do
    test "returns events for an experiment" do
      event1 = Event.new(:hypothesis_formed, "Event 1", "Reason", experiment_id: "exp-001")
      event2 = Event.new(:pattern_applied, "Event 2", "Reason", experiment_id: "exp-001")
      event3 = Event.new(:pattern_applied, "Event 3", "Reason", experiment_id: "exp-002")

      chain =
        Chain.new("Test")
        |> Chain.add_events([event1, event2, event3])

      exp_001_events = Chain.get_events_by_experiment(chain, "exp-001")
      assert length(exp_001_events) == 2
      assert event1 in exp_001_events
      assert event2 in exp_001_events
    end
  end

  describe "Event serialization with relationships" do
    test "to_map includes relationship fields" do
      event =
        Event.new(:hypothesis_formed, "Decision", "Reason",
          parent_id: "parent-123",
          depends_on: ["dep-1", "dep-2"],
          stage_id: "stage-a",
          experiment_id: "exp-001"
        )

      map = Event.to_map(event)

      assert map.parent_id == "parent-123"
      assert map.depends_on == ["dep-1", "dep-2"]
      assert map.stage_id == "stage-a"
      assert map.experiment_id == "exp-001"
    end

    test "from_map restores relationship fields" do
      map = %{
        "type" => "hypothesis_formed",
        "decision" => "Decision",
        "reasoning" => "Reason",
        "parent_id" => "parent-123",
        "depends_on" => ["dep-1", "dep-2"],
        "stage_id" => "stage-a",
        "experiment_id" => "exp-001"
      }

      event = Event.from_map(map)

      assert event.parent_id == "parent-123"
      assert event.depends_on == ["dep-1", "dep-2"]
      assert event.stage_id == "stage-a"
      assert event.experiment_id == "exp-001"
    end
  end
end
