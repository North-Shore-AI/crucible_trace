# CrucibleTrace - Gap Analysis

**Date:** 2025-12-25
**Version:** 0.2.1
**Status:** Gap Analysis

---

## Executive Summary

CrucibleTrace is a mature library with solid core functionality for causal trace logging. However, several gaps exist that would enhance its integration with the broader crucible_framework ecosystem, particularly for ML training workflows and production deployments.

---

## Category 1: crucible_framework Integration Gaps

### 1.1 No Pipeline Stage Integration

**Gap:** CrucibleTrace operates standalone without integration into crucible_framework's pipeline runner.

**Current State:**
- Events are created manually via `create_event/4`
- No automatic tracing of pipeline stage execution
- No telemetry integration

**Expected:**
- Implement `Crucible.Stage` behaviour for automatic trace collection
- Hook into pipeline events (stage start, complete, error)
- Auto-generate events from stage transitions

**Impact:** High - Core integration needed for automated ML workflow tracing

---

### 1.2 No Training Stage Tracing

**Gap:** No specialized event types or helpers for ML training stages.

**Current State:**
- Generic 6 event types only
- No training-specific events (epoch_completed, loss_computed, checkpoint_saved)
- No model-specific metadata capture

**Expected Event Types:**
```elixir
:training_started
:epoch_completed
:batch_processed
:loss_computed
:gradient_computed
:checkpoint_saved
:early_stopped
:hyperparameter_tuned
:validation_run
:model_saved
```

**Impact:** High - Critical for ML experiment tracing

---

### 1.3 No Telemetry Integration

**Gap:** No integration with `:telemetry` for event emission/collection.

**Current State:**
- Events stored in Chain structs only
- No PubSub or telemetry hooks
- No real-time streaming

**Expected:**
- Emit `:telemetry` events for each trace event
- Subscribe to pipeline telemetry events
- Bridge with crucible_telemetry

**Impact:** Medium - Important for real-time monitoring

---

### 1.4 No crucible_ir Integration

**Gap:** Despite having `crucible_ir` as dependency, no actual integration.

**Current State:**
- `crucible_ir` in deps but unused
- No experiment/stage_def tracing
- No IR-to-trace conversion

**Expected:**
- Trace Crucible.IR.Experiment execution
- Capture stage_def configurations
- Link traces to experiments

**Impact:** Medium - Useful for experiment reproducibility

---

## Category 2: ML Training Workflow Gaps

### 2.1 No Deployment Trace Events

**Gap:** No event types for model deployment lifecycle.

**Missing Events:**
```elixir
:deployment_initiated
:model_loaded
:serving_started
:inference_completed
:deployment_rollback
:canary_promoted
:a_b_test_result
```

**Impact:** Medium - Important for MLOps workflows

---

### 2.2 No Feedback Loop Tracing

**Gap:** No support for capturing feedback loops in RL or online learning.

**Missing:**
- Reward signals from environment
- Policy update traces
- Experience replay sampling
- Online learning updates

**Impact:** Medium - Critical for RL workflows

---

### 2.3 No Distributed Training Support

**Gap:** No support for multi-node/multi-GPU training traces.

**Missing:**
- Worker identification
- Gradient aggregation events
- Communication timing
- Synchronization barriers

**Impact:** Low - Future scalability concern

---

### 2.4 No Checkpoint/Recovery Integration

**Gap:** No tracing of model checkpoints and recovery.

**Missing:**
- Checkpoint creation events
- Checkpoint loading events
- State recovery events
- Training resume traces

**Impact:** Medium - Important for long training runs

---

## Category 3: Analysis and Tooling Gaps

### 3.1 No Advanced Query Module

**Gap:** `CrucibleTrace.Query` planned but not implemented.

**Current State:**
- Basic filtering via `filter_events/2`
- Name-based search in Storage
- No content search
- No regex matching
- No boolean query logic

**Expected (from design doc):**
```elixir
CrucibleTrace.search_events(chain,
  content: "GenServer",
  type: [:hypothesis_formed, :pattern_applied],
  min_confidence: 0.8
)
```

**Impact:** Medium - Useful for large trace analysis

---

### 3.2 No Event Relationships

**Gap:** Events are flat list, no parent/child or dependency modeling.

**Current State:**
- Events have no `parent_id` field
- No `depends_on` relationships
- No DAG structure support

**Expected (from design doc):**
```elixir
event = CrucibleTrace.create_event(
  :pattern_applied,
  "Use Supervisor",
  "Based on earlier GenServer decision",
  parent_id: parent_event.id,
  depends_on: [event1.id, event2.id]
)
```

**Impact:** Medium - Important for complex reasoning chains

---

### 3.3 No Cryptographic Verification

**Gap:** Mentioned in description but not implemented.

**Current State:**
- No hash chain for events
- No tamper detection
- No digital signatures

**Expected:**
- SHA-256 hash of each event
- Chain-of-custody linking
- Verification API

**Impact:** Low - Important for audit/compliance use cases

---

### 3.4 No Performance Metrics

**Gap:** No built-in support for LLM performance tracking.

**Missing:**
- Token counts per event
- Latency per event
- API cost tracking
- Aggregate performance stats

**Impact:** Medium - Useful for LLM cost optimization

---

## Category 4: Storage and Persistence Gaps

### 4.1 No Database Backend

**Gap:** File-based storage only, no database option.

**Current State:**
- JSON files in directory
- Linear file scans for search
- No indexing
- No concurrent write safety

**Expected:**
- Optional ETS backend
- Optional SQLite/PostgreSQL
- Indexed queries
- Concurrent-safe writes

**Impact:** Medium - Needed for production deployments

---

### 4.2 No Streaming Storage

**Gap:** Chains must fit in memory before save.

**Current State:**
- Entire chain serialized to JSON
- No streaming writes
- No lazy loading

**Expected:**
- Stream events to disk
- Lazy load large chains
- Memory-efficient for large traces

**Impact:** Low - Issue for very large traces only

---

### 4.3 No Chain Versioning

**Gap:** No version history for chains.

**Current State:**
- Single version per chain
- Overwrite on save
- No history tracking

**Expected:**
- Version history
- Diff between versions
- Rollback support

**Impact:** Low - Nice to have for iterative work

---

## Category 5: Documentation and Examples Gaps

### 5.1 No Mermaid Test File

**Gap:** `mermaid_test.exs` mentioned in implementation summary but file not found.

**Current State:**
- Mermaid module exists
- No dedicated test file for Mermaid module
- Tests may be integrated elsewhere

**Impact:** Low - Testing gap

---

### 5.2 README Roadmap Out of Date

**Gap:** README roadmap shows completed items as TODO.

**Current State (from README lines 499-505):**
```markdown
## Roadmap

- [ ] More robust XML/JSON parsing
- [ ] Database storage backend option
- [ ] Real-time chain updates via Phoenix LiveView
- [ ] Diff visualization between chains  # Already implemented!
- [ ] Export to Mermaid diagrams          # Already implemented!
- [ ] Integration with popular LLM libraries
```

**Impact:** Low - Documentation cleanup needed

---

### 5.3 No Example Files Present

**Gap:** README references example files that may not be present.

**Expected Files:**
- `examples/basic_usage.exs`
- `examples/advanced_analysis.exs`
- `examples/llm_integration.exs`
- `examples/storage_and_search.exs`
- `examples/chain_comparison.exs`
- `examples/mermaid_export.exs`

**Impact:** Low - Verify and add if missing

---

## Category 6: Code Quality Gaps

### 6.1 No Type Specifications

**Gap:** Limited @spec annotations throughout codebase.

**Current State:**
- Some typespecs present
- Many public functions lack specs
- Dialyzer may not catch all issues

**Expected:**
- Full @spec coverage on public API
- @type definitions for complex types
- Dialyzer clean

**Impact:** Low - Quality improvement

---

### 6.2 Application Not Starting Supervision Tree

**Gap:** Application module has empty children list.

**Current State (line 10-13):**
```elixir
children = [
  # Starts a worker by calling: CrucibleTrace.Worker.start_link(arg)
  # {CrucibleTrace.Worker, arg}
]
```

**Expected:**
- Could start Storage GenServer for caching
- Could start telemetry handlers
- Currently no runtime processes

**Impact:** Low - May be intentional for library use

---

### 6.3 Inconsistent Naming

**Gap:** Module named `CrucibleTrace` but main file is `causal_trace.ex`.

**Current State:**
- `lib/causal_trace.ex` defines `CrucibleTrace`
- Submodules in `lib/crucible_trace/`
- Could confuse developers

**Expected:**
- Rename `causal_trace.ex` to `crucible_trace.ex`
- OR accept the historical naming

**Impact:** Very Low - Cosmetic

---

## Priority Matrix

| Gap | Impact | Effort | Priority |
|-----|--------|--------|----------|
| Pipeline Stage Integration | High | High | P0 |
| Training Stage Events | High | Medium | P0 |
| Telemetry Integration | Medium | Medium | P1 |
| Event Relationships | Medium | Medium | P1 |
| Advanced Query Module | Medium | Medium | P1 |
| Deployment Events | Medium | Low | P2 |
| Feedback Loop Tracing | Medium | Medium | P2 |
| crucible_ir Integration | Medium | Low | P2 |
| Checkpoint Integration | Medium | Low | P2 |
| Database Backend | Medium | High | P3 |
| Performance Metrics | Medium | Medium | P3 |
| Cryptographic Verification | Low | High | P4 |
| README Cleanup | Low | Low | P4 |

---

## Recommended Next Steps

### Phase 1: Core Integration (Immediate)
1. Add training-specific event types to Event module
2. Create `CrucibleTrace.Stage` behaviour for pipeline integration
3. Add telemetry emission to event creation

### Phase 2: ML Workflow Support (Near-term)
1. Add deployment and feedback loop event types
2. Implement event relationships (parent_id, depends_on)
3. Create helpers for common training patterns

### Phase 3: Production Readiness (Medium-term)
1. Implement database backend option
2. Add performance metrics tracking
3. Implement advanced query module

### Phase 4: Enterprise Features (Long-term)
1. Cryptographic verification
2. Distributed training support
3. Chain versioning

---

## Conclusion

CrucibleTrace has a solid foundation but requires significant enhancements to fully integrate with the crucible_framework ecosystem. The highest priority gaps are:

1. **Pipeline Stage Integration** - Currently no way to automatically trace pipeline execution
2. **Training Stage Events** - Missing ML-specific event types
3. **Telemetry Integration** - No bridge to crucible_telemetry

Addressing these three gaps would unlock the primary use case of automated ML experiment tracing.
