# CrucibleTrace Enhancement Implementation Prompt

**Date:** 2025-12-25
**Target Version:** 0.3.0
**Purpose:** Implementation guide for enhancing crucible_trace with ML training integration

---

## Mission

You are implementing enhancements to the CrucibleTrace library to integrate it with the crucible_framework ML experimentation ecosystem. Your goal is to add training stage events, pipeline integration, telemetry support, and event relationships while maintaining backward compatibility.

---

## Required Reading

Before making any changes, you MUST read these files to understand the codebase:

### Core Implementation Files

1. **Main API Module**
   - `/home/home/p/g/North-Shore-AI/crucible_trace/lib/causal_trace.ex` (391 lines)
   - Key functions: Lines 55-96, 119-157, 242-293, 357-388
   - Delegations pattern to submodules

2. **Event Module**
   - `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/event.ex` (181 lines)
   - Struct definition: Lines 17-28
   - Event types: Lines 9-15
   - `new/4` function: Lines 56-69
   - Validation: Lines 76-113

3. **Chain Module**
   - `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/chain.ex` (255 lines)
   - Struct definition: Lines 11-19
   - Statistics: Lines 108-137
   - Event operations: Lines 59-97

4. **Storage Module**
   - `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/storage.ex` (359 lines)
   - Export function: Lines 132-159 (add new training formats here)

5. **Parser Module**
   - `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/parser.ex` (281 lines)
   - Event type parsing: Lines 135-144 (extend with new types)

6. **Diff Module**
   - `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/diff.ex` (475 lines)
   - Reference for implementing new comparison features

7. **Mermaid Module**
   - `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/mermaid.ex` (278 lines)
   - Export patterns for new event types

### Test Files

8. **Event Tests**
   - `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/event_test.exs` (163 lines)

9. **Chain Tests**
   - `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/chain_test.exs` (252 lines)

10. **Parser Tests**
    - `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/parser_test.exs` (317 lines)

11. **Integration Tests**
    - `/home/home/p/g/North-Shore-AI/crucible_trace/test/causal_trace_test.exs` (188 lines)

### Configuration Files

12. **Mix Project**
    - `/home/home/p/g/North-Shore-AI/crucible_trace/mix.exs` (104 lines)

13. **Formatter**
    - `/home/home/p/g/North-Shore-AI/crucible_trace/.formatter.exs`

### Documentation

14. **README**
    - `/home/home/p/g/North-Shore-AI/crucible_trace/README.md` (527 lines)

15. **Previous Enhancement Design**
    - `/home/home/p/g/North-Shore-AI/crucible_trace/docs/20251125/enhancement_design.md`

16. **Gap Analysis**
    - `/home/home/p/g/North-Shore-AI/crucible_trace/docs/20251225/gaps.md`

---

## Implementation Tasks

### Task 1: Add Training Event Types

**File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/event.ex`

**Current event_type (Lines 9-15):**
```elixir
@type event_type ::
        :hypothesis_formed
        | :alternative_rejected
        | :constraint_evaluated
        | :pattern_applied
        | :ambiguity_flagged
        | :confidence_updated
```

**Add new training event types:**
```elixir
# Training lifecycle events
| :training_started
| :training_completed
| :epoch_started
| :epoch_completed
| :batch_processed

# Metrics events
| :loss_computed
| :metric_recorded
| :gradient_computed

# Checkpoint events
| :checkpoint_saved
| :checkpoint_loaded
| :early_stopped

# Deployment events
| :deployment_started
| :model_loaded
| :inference_completed
| :deployment_completed

# RL/Feedback events
| :reward_received
| :policy_updated
| :experience_sampled
```

**Update validate_type/1 (Lines 84-96)** to include new types.

**Update Parser (Lines 135-144)** to parse new type strings.

---

### Task 2: Add Event Relationships

**File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/event.ex`

**Extend struct (Line 31-42):**
```elixir
defstruct [
  :id,
  :timestamp,
  :type,
  :decision,
  :reasoning,
  alternatives: [],
  confidence: 1.0,
  code_section: nil,
  spec_reference: nil,
  metadata: %{},
  # NEW FIELDS
  parent_id: nil,          # String.t() | nil - parent event ID
  depends_on: [],          # [String.t()] - list of dependency event IDs
  stage_id: nil,           # String.t() | nil - associated pipeline stage
  experiment_id: nil       # String.t() | nil - associated experiment
]
```

**Update @type t (Lines 17-28)** to include new fields.

**Add new functions to Chain module:**
```elixir
@doc "Gets child events of a given event"
def get_children(%__MODULE__{} = chain, event_id)

@doc "Gets parent events in the chain"
def get_parent(%__MODULE__{} = chain, event_id)

@doc "Gets root events (no parent)"
def get_root_events(%__MODULE__{} = chain)

@doc "Gets leaf events (no children)"
def get_leaf_events(%__MODULE__{} = chain)

@doc "Validates no circular dependencies exist"
def validate_relationships(%__MODULE__{} = chain)

@doc "Gets all events for a given stage_id"
def get_events_by_stage(%__MODULE__{} = chain, stage_id)

@doc "Gets all events for a given experiment_id"
def get_events_by_experiment(%__MODULE__{} = chain, experiment_id)
```

---

### Task 3: Create Training Helpers Module

**New File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/training.ex`

```elixir
defmodule CrucibleTrace.Training do
  @moduledoc """
  Helper functions for tracing ML training workflows.

  Provides convenience functions for common training events like
  epoch completion, loss recording, and checkpoint management.
  """

  alias CrucibleTrace.{Event, Chain}

  @doc """
  Creates a training_started event.

  ## Options
  - :model_name - Name of the model being trained
  - :dataset - Dataset name
  - :config - Training configuration map
  - :experiment_id - Associated experiment ID
  """
  def training_started(decision, reasoning, opts \\ [])

  @doc """
  Creates an epoch_completed event with metrics.

  ## Options
  - :epoch - Epoch number
  - :train_loss - Training loss
  - :val_loss - Validation loss
  - :metrics - Map of additional metrics
  """
  def epoch_completed(epoch, metrics, opts \\ [])

  @doc """
  Creates a loss_computed event.
  """
  def loss_computed(loss_value, opts \\ [])

  @doc """
  Creates a checkpoint_saved event.
  """
  def checkpoint_saved(path, opts \\ [])

  @doc """
  Creates a deployment event.
  """
  def deployment_started(model_path, opts \\ [])

  @doc """
  Wraps a training function to automatically emit trace events.
  """
  def trace_training(chain, training_fn) when is_function(training_fn, 0)

  @doc """
  Creates events for a complete training run from metrics history.
  """
  def from_training_metrics(metrics_list, opts \\ [])
end
```

---

### Task 4: Add Telemetry Integration

**New File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/telemetry.ex`

```elixir
defmodule CrucibleTrace.Telemetry do
  @moduledoc """
  Telemetry integration for CrucibleTrace.

  Emits telemetry events for trace operations and can subscribe
  to pipeline telemetry to automatically create trace events.
  """

  @doc """
  Attaches telemetry handlers for automatic trace collection.
  """
  def attach_handlers(opts \\ [])

  @doc """
  Detaches telemetry handlers.
  """
  def detach_handlers()

  @doc """
  Emits a telemetry event for a trace event creation.

  Telemetry event: [:crucible_trace, :event, :created]
  """
  def emit_event_created(event)

  @doc """
  Emits a telemetry event for chain operations.

  Events:
  - [:crucible_trace, :chain, :created]
  - [:crucible_trace, :chain, :saved]
  - [:crucible_trace, :chain, :loaded]
  """
  def emit_chain_event(event_name, chain, metadata \\ %{})

  @doc """
  Handles incoming pipeline telemetry events.

  Converts crucible_framework pipeline events to trace events.
  """
  def handle_pipeline_event(event, measurements, metadata, config)
end
```

**Update Event.new/4 to emit telemetry:**
```elixir
def new(type, decision, reasoning, opts \\ []) do
  event = %__MODULE__{
    # ... existing fields
  }

  # Emit telemetry
  CrucibleTrace.Telemetry.emit_event_created(event)

  event
end
```

---

### Task 5: Create Pipeline Stage Module

**New File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/stage.ex`

```elixir
defmodule CrucibleTrace.Stage do
  @moduledoc """
  Pipeline stage wrapper that automatically traces execution.

  Implements a pattern for wrapping crucible_framework stages
  with automatic trace event generation.
  """

  @doc """
  Wraps a stage function with tracing.

  Creates events for:
  - Stage start
  - Stage completion (with duration)
  - Stage errors
  """
  def trace_stage(chain, stage_id, stage_fn) when is_function(stage_fn, 0)

  @doc """
  Creates a traced stage definition.
  """
  defmacro deftraced_stage(name, do: body)

  @doc """
  Decorator for automatically tracing a function.
  """
  defmacro trace(opts \\ [], do: body)
end
```

---

### Task 6: Add Advanced Query Module

**New File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/query.ex`

```elixir
defmodule CrucibleTrace.Query do
  @moduledoc """
  Advanced querying capabilities for trace chains.

  Supports full-text search, regex matching, and boolean queries.
  """

  alias CrucibleTrace.{Chain, Event}

  @doc """
  Searches events by content across decision and reasoning fields.

  ## Options
  - :type - Filter by event type(s)
  - :min_confidence - Minimum confidence threshold
  - :max_confidence - Maximum confidence threshold
  - :since - Only events after this datetime
  - :until - Only events before this datetime
  - :stage_id - Filter by stage ID
  - :experiment_id - Filter by experiment ID
  """
  def search_events(%Chain{} = chain, content, opts \\ [])

  @doc """
  Searches with regex pattern.
  """
  def search_regex(%Chain{} = chain, pattern, opts \\ [])

  @doc """
  Advanced query with boolean logic.

  ## Query Format
  %{
    or: [
      %{content: ~r/pattern/i, confidence: {:gte, 0.8}},
      %{type: :ambiguity_flagged}
    ],
    and: [
      %{stage_id: "training"}
    ]
  }
  """
  def query(%Chain{} = chain, query_map)

  @doc """
  Searches across multiple chains.
  """
  def search_all_chains(content, opts \\ [])

  @doc """
  Aggregates events by a field.
  """
  def aggregate_by(%Chain{} = chain, field, aggregation_fn)
end
```

---

### Task 7: Update Main API

**File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/causal_trace.ex`

Add new delegations and functions:

```elixir
# After line 45, add new module aliases
alias CrucibleTrace.{Chain, Event, Parser, Storage, Viewer, Diff, Mermaid,
                     Training, Telemetry, Stage, Query}

# Training Operations (new section after line 345)

@doc """
Creates a training_started event.
"""
defdelegate training_started(decision, reasoning, opts \\ []), to: Training

@doc """
Creates an epoch_completed event.
"""
defdelegate epoch_completed(epoch, metrics, opts \\ []), to: Training

@doc """
Creates a loss_computed event.
"""
defdelegate loss_computed(loss_value, opts \\ []), to: Training

@doc """
Creates a checkpoint_saved event.
"""
defdelegate checkpoint_saved(path, opts \\ []), to: Training

# Telemetry Operations

@doc """
Attaches telemetry handlers for automatic trace collection.
"""
defdelegate attach_telemetry(opts \\ []), to: Telemetry, as: :attach_handlers

@doc """
Detaches telemetry handlers.
"""
defdelegate detach_telemetry(), to: Telemetry, as: :detach_handlers

# Query Operations

@doc """
Searches events by content.
"""
defdelegate search_events(chain, content, opts \\ []), to: Query

@doc """
Advanced query with boolean logic.
"""
defdelegate query_events(chain, query_map), to: Query, as: :query

# Relationship Operations (add to Chain module)

@doc """
Gets child events of a given event.
"""
defdelegate get_children(chain, event_id), to: Chain

@doc """
Gets root events (no parent).
"""
defdelegate get_root_events(chain), to: Chain

@doc """
Validates relationship integrity.
"""
defdelegate validate_relationships(chain), to: Chain

# Stage Operations

@doc """
Wraps a stage function with tracing.
"""
defdelegate trace_stage(chain, stage_id, stage_fn), to: Stage
```

---

### Task 8: Update Tests

**Test-Driven Development Approach:**

Write tests BEFORE implementing each feature.

#### New Test File: `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/training_test.exs`

```elixir
defmodule CrucibleTrace.TrainingTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.{Training, Chain, Event}

  describe "training_started/3" do
    test "creates training_started event with model info" do
      event = Training.training_started(
        "Begin ResNet-50 training",
        "Using pretrained weights for transfer learning",
        model_name: "resnet50",
        dataset: "imagenet",
        experiment_id: "exp-001"
      )

      assert event.type == :training_started
      assert event.metadata[:model_name] == "resnet50"
      assert event.experiment_id == "exp-001"
    end
  end

  describe "epoch_completed/3" do
    test "creates epoch event with metrics" do
      event = Training.epoch_completed(5, %{
        train_loss: 0.234,
        val_loss: 0.289,
        accuracy: 0.876
      })

      assert event.type == :epoch_completed
      assert event.metadata[:epoch] == 5
      assert event.metadata[:train_loss] == 0.234
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
    end
  end
end
```

#### New Test File: `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/query_test.exs`

```elixir
defmodule CrucibleTrace.QueryTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.{Query, Chain, Event}

  describe "search_events/3" do
    setup do
      chain = Chain.new("Test")
      |> Chain.add_event(Event.new(:hypothesis_formed, "Use GenServer", "State management"))
      |> Chain.add_event(Event.new(:pattern_applied, "Apply Supervisor", "Fault tolerance"))
      |> Chain.add_event(Event.new(:training_started, "Train model", "Start training"))

      {:ok, chain: chain}
    end

    test "finds events by content substring", %{chain: chain} do
      events = Query.search_events(chain, "GenServer")
      assert length(events) == 1
      assert hd(events).decision == "Use GenServer"
    end

    test "filters by event type", %{chain: chain} do
      events = Query.search_events(chain, "", type: :training_started)
      assert length(events) == 1
    end

    test "filters by confidence threshold", %{chain: chain} do
      chain = Chain.add_event(chain, Event.new(:hypothesis_formed, "Low conf", "Test", confidence: 0.5))
      events = Query.search_events(chain, "", min_confidence: 0.8)
      assert length(events) == 3  # Original 3 with default 1.0 confidence
    end
  end

  describe "search_regex/3" do
    test "searches with regex pattern" do
      chain = Chain.new("Test")
      |> Chain.add_event(Event.new(:hypothesis_formed, "Use GenServer v1", "Reason"))
      |> Chain.add_event(Event.new(:hypothesis_formed, "Use GenServer v2", "Reason"))

      events = Query.search_regex(chain, ~r/GenServer v\d/)
      assert length(events) == 2
    end
  end
end
```

#### New Test File: `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/relationships_test.exs`

```elixir
defmodule CrucibleTrace.RelationshipsTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.{Chain, Event}

  describe "event relationships" do
    test "creates event with parent_id" do
      parent = Event.new(:hypothesis_formed, "Use OTP", "Standard pattern")
      child = Event.new(:pattern_applied, "Use GenServer", "State management",
        parent_id: parent.id
      )

      assert child.parent_id == parent.id
    end

    test "creates event with depends_on" do
      event1 = Event.new(:hypothesis_formed, "Decision 1", "Reason 1")
      event2 = Event.new(:hypothesis_formed, "Decision 2", "Reason 2")
      event3 = Event.new(:pattern_applied, "Depends on both", "Combined",
        depends_on: [event1.id, event2.id]
      )

      assert event3.depends_on == [event1.id, event2.id]
    end
  end

  describe "get_children/2" do
    test "returns child events" do
      parent = Event.new(:hypothesis_formed, "Parent", "Reason")
      child1 = Event.new(:pattern_applied, "Child 1", "Reason", parent_id: parent.id)
      child2 = Event.new(:pattern_applied, "Child 2", "Reason", parent_id: parent.id)

      chain = Chain.new("Test")
      |> Chain.add_events([parent, child1, child2])

      {:ok, children} = Chain.get_children(chain, parent.id)
      assert length(children) == 2
    end
  end

  describe "get_root_events/1" do
    test "returns events with no parent" do
      root1 = Event.new(:hypothesis_formed, "Root 1", "Reason")
      root2 = Event.new(:hypothesis_formed, "Root 2", "Reason")
      child = Event.new(:pattern_applied, "Child", "Reason", parent_id: root1.id)

      chain = Chain.new("Test")
      |> Chain.add_events([root1, root2, child])

      roots = Chain.get_root_events(chain)
      assert length(roots) == 2
    end
  end

  describe "validate_relationships/1" do
    test "passes for valid relationships" do
      parent = Event.new(:hypothesis_formed, "Parent", "Reason")
      child = Event.new(:pattern_applied, "Child", "Reason", parent_id: parent.id)

      chain = Chain.new("Test")
      |> Chain.add_events([parent, child])

      assert {:ok, _chain} = Chain.validate_relationships(chain)
    end

    test "detects circular dependencies" do
      event1 = Event.new(:hypothesis_formed, "Event 1", "Reason")
      event2 = %{Event.new(:pattern_applied, "Event 2", "Reason") |
                 parent_id: event1.id, depends_on: [event1.id]}
      # Create circular reference by making event1 depend on event2
      event1_circular = %{event1 | depends_on: [event2.id]}

      chain = Chain.new("Test")
      |> Chain.add_events([event1_circular, event2])

      assert {:error, _reason} = Chain.validate_relationships(chain)
    end
  end
end
```

#### Extend existing tests:

**Update:** `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/event_test.exs`

Add tests for new event types:
```elixir
describe "training event types" do
  test "validates training_started type" do
    event = Event.new(:training_started, "Start training", "Initializing")
    assert {:ok, ^event} = Event.validate(event)
  end

  test "validates epoch_completed type" do
    event = Event.new(:epoch_completed, "Epoch 5 done", "Completed epoch 5")
    assert {:ok, ^event} = Event.validate(event)
  end

  # Add tests for all new event types
end
```

---

## Quality Requirements

### Must Pass Before Commit

1. **No Warnings:**
   ```bash
   mix compile --warnings-as-errors
   ```

2. **All Tests Pass:**
   ```bash
   mix test
   ```

3. **Dialyzer Clean:**
   ```bash
   mix dialyzer
   ```

4. **Credo Strict:**
   ```bash
   mix credo --strict
   ```

5. **Formatted:**
   ```bash
   mix format --check-formatted
   ```

### Code Style

- Follow existing patterns in codebase
- Add @moduledoc to all new modules
- Add @doc to all public functions
- Add @spec to all public functions
- Use consistent error tuples: `{:ok, result}` or `{:error, reason}`
- Keep functions under 20 lines where possible
- Use pattern matching extensively

---

## README Updates

After implementation, update `/home/home/p/g/North-Shore-AI/crucible_trace/README.md`:

### New Sections to Add

```markdown
## ML Training Integration (v0.3.0)

CrucibleTrace now provides first-class support for ML training workflows:

### Training Events

```elixir
# Start training
event = CrucibleTrace.training_started(
  "Begin ResNet training",
  "Transfer learning from ImageNet",
  model_name: "resnet50",
  experiment_id: "exp-001"
)

# Record epoch completion
event = CrucibleTrace.epoch_completed(5, %{
  train_loss: 0.234,
  val_loss: 0.289,
  accuracy: 0.876
})

# Record checkpoint
event = CrucibleTrace.checkpoint_saved(
  "/models/checkpoint_epoch_5.pt",
  metrics: %{val_accuracy: 0.876}
)
```

### Event Relationships

Events can now reference parent events and dependencies:

```elixir
parent = CrucibleTrace.create_event(:training_started, ...)
child = CrucibleTrace.create_event(:epoch_completed, ...,
  parent_id: parent.id,
  experiment_id: "exp-001"
)

# Query relationships
{:ok, children} = CrucibleTrace.get_children(chain, parent.id)
roots = CrucibleTrace.get_root_events(chain)
```

### Telemetry Integration

Automatically trace pipeline events:

```elixir
# Attach handlers to capture crucible_framework events
CrucibleTrace.attach_telemetry()

# Events are automatically created for pipeline stage execution
```

### Advanced Querying

```elixir
# Content search
events = CrucibleTrace.search_events(chain, "GenServer",
  type: [:hypothesis_formed, :pattern_applied],
  min_confidence: 0.8
)

# Regex search
events = CrucibleTrace.search_regex(chain, ~r/epoch \d+/i)
```
```

### Update Roadmap Section

```markdown
## Roadmap

### Completed
- [x] Diff visualization between chains (v0.2.0)
- [x] Export to Mermaid diagrams (v0.2.0)
- [x] ML training event types (v0.3.0)
- [x] Event relationships (v0.3.0)
- [x] Telemetry integration (v0.3.0)
- [x] Advanced querying (v0.3.0)

### Planned
- [ ] Database storage backend
- [ ] Cryptographic verification
- [ ] Real-time chain updates via Phoenix LiveView
- [ ] Distributed training support
```

---

## Implementation Order

Follow this sequence for TDD approach:

1. **Event Types** (extend Event module)
   - Write tests for new types
   - Add types to @type
   - Update validate_type/1
   - Update Parser

2. **Event Relationships** (extend Event, Chain)
   - Write relationship tests
   - Add new fields to Event struct
   - Add relationship functions to Chain
   - Update to_map/from_map

3. **Training Module** (new module)
   - Write training tests
   - Implement Training module
   - Add delegations to main API

4. **Query Module** (new module)
   - Write query tests
   - Implement Query module
   - Add delegations to main API

5. **Telemetry Module** (new module)
   - Write telemetry tests
   - Implement Telemetry module
   - Integrate with Event.new/4

6. **Stage Module** (new module)
   - Write stage tests
   - Implement Stage module
   - Add delegations to main API

7. **Documentation**
   - Update README
   - Update CHANGELOG
   - Bump version to 0.3.0

---

## Success Criteria

- [ ] All 6 existing test files pass (103+ tests)
- [ ] 4 new test files created with 50+ tests
- [ ] No compilation warnings
- [ ] Dialyzer passes
- [ ] Credo strict passes
- [ ] README updated with new features
- [ ] CHANGELOG updated with v0.3.0
- [ ] Version bumped to 0.3.0 in mix.exs
- [ ] All new public functions documented
- [ ] All new modules have @moduledoc
- [ ] Backward compatible with v0.2.x saved chains
