# CrucibleTrace - Current State Documentation

**Date:** 2025-12-25
**Version:** 0.2.1
**Location:** `/home/home/p/g/North-Shore-AI/crucible_trace`

## Overview

CrucibleTrace is a structured causal reasoning chain logging library for LLM code generation. It captures the decision-making process of LLMs, providing transparency and debugging capabilities by logging causal reasoning chains with events, alternatives considered, confidence levels, and supporting rationale.

## Architecture

```
CrucibleTrace (Main API - lib/causal_trace.ex)
    |
    +-- CrucibleTrace.Event      (lib/crucible_trace/event.ex)
    +-- CrucibleTrace.Chain      (lib/crucible_trace/chain.ex)
    +-- CrucibleTrace.Parser     (lib/crucible_trace/parser.ex)
    +-- CrucibleTrace.Storage    (lib/crucible_trace/storage.ex)
    +-- CrucibleTrace.Viewer     (lib/crucible_trace/viewer.ex)
    +-- CrucibleTrace.Mermaid    (lib/crucible_trace/mermaid.ex)
    +-- CrucibleTrace.Diff       (lib/crucible_trace/diff.ex)
    +-- CrucibleTrace.Application (lib/crucible_trace/application.ex)
```

## Module Inventory

### 1. CrucibleTrace (Main API)

**File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/causal_trace.ex`
**Lines:** 391 lines
**Purpose:** Unified public API that delegates to specialized modules

**Key Functions:**
| Function | Line | Description |
|----------|------|-------------|
| `new_chain/2` | 55 | Creates a new empty chain |
| `add_event/2` | 60 | Adds an event to a chain |
| `add_events/2` | 65 | Adds multiple events to a chain |
| `create_event/4` | 96 | Creates a new event |
| `validate_event/1` | 103 | Validates an event |
| `parse_llm_output/3` | 119 | Parses LLM output to extract trace events |
| `parse_events/1` | 128 | Parses LLM output, returns just events |
| `extract_code/1` | 139 | Extracts code from LLM output, removes event tags |
| `build_causal_prompt/1` | 150 | Builds prompt that instructs LLM to emit events |
| `validate_events/1` | 157 | Validates text contains properly formatted events |
| `save/2` | 175 | Saves a chain to disk |
| `load/2` | 182 | Loads a chain from disk by ID |
| `list_chains/1` | 189 | Lists all saved chains |
| `delete/2` | 196 | Deletes a chain from disk |
| `search/2` | 213 | Searches for chains matching criteria |
| `export/3` | 222 | Exports chain to different format |
| `visualize/2` | 242 | Generates HTML visualization |
| `save_visualization/3` | 249 | Saves HTML visualization to file |
| `open_visualization/2` | 258 | Opens visualization in browser |
| `statistics/1` | 275 | Gets statistics about a chain |
| `find_decision_points/1` | 282 | Finds decision points with alternatives |
| `find_low_confidence/2` | 293 | Finds events below confidence threshold |
| `get_events_by_type/2` | 302 | Gets events of specific type |
| `filter_events/2` | 311 | Filters events with predicate function |
| `sort_by_timestamp/2` | 318 | Sorts events by timestamp |
| `merge_chains/2` | 323 | Merges two chains together |
| `chain_to_map/1` | 330 | Converts chain to map |
| `chain_from_map/1` | 335 | Creates chain from map |
| `event_to_map/1` | 340 | Converts event to map |
| `event_from_map/1` | 345 | Creates event from map |
| `diff_chains/3` | 357 | Compares two chains, returns diff |
| `diff_to_text/1` | 362 | Converts diff to text format |
| `diff_to_html/3` | 367 | Generates HTML diff visualization |
| `export_mermaid/3` | 379-388 | Exports chain as Mermaid diagram |

---

### 2. CrucibleTrace.Event

**File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/event.ex`
**Lines:** 181 lines
**Purpose:** Represents a single causal reasoning event in the decision chain

**Struct Fields:**
```elixir
%CrucibleTrace.Event{
  id: String.t(),           # Unique identifier (32-char hex)
  timestamp: DateTime.t(),   # When event occurred
  type: event_type(),        # One of 6 event types
  decision: String.t(),      # What was decided
  alternatives: [String.t()],# Alternatives considered
  reasoning: String.t(),     # Why this decision was made
  confidence: float(),       # 0.0 to 1.0
  code_section: String.t() | nil,    # Related code section
  spec_reference: String.t() | nil,  # Related spec reference
  metadata: map()            # Additional metadata
}
```

**Event Types:**
- `:hypothesis_formed` - Initial approach or solution hypothesis
- `:alternative_rejected` - Explicit rejection of an alternative
- `:constraint_evaluated` - Evaluation of constraint or requirement
- `:pattern_applied` - Application of specific design pattern
- `:ambiguity_flagged` - Ambiguity encountered in specification
- `:confidence_updated` - Change in confidence for a decision

**Key Functions:**
| Function | Line | Description |
|----------|------|-------------|
| `new/4` | 56-69 | Creates new event with given attributes |
| `validate/1` | 76-81 | Validates an event struct |
| `to_map/1` | 118-131 | Converts event to JSON-encodable map |
| `from_map/1` | 136-149 | Creates event from map |

---

### 3. CrucibleTrace.Chain

**File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/chain.ex`
**Lines:** 255 lines
**Purpose:** Manages a collection of causal reasoning events forming a decision chain

**Struct Fields:**
```elixir
%CrucibleTrace.Chain{
  id: String.t(),           # Unique identifier
  name: String.t(),          # Chain name
  description: String.t() | nil,  # Optional description
  events: [Event.t()],       # List of events
  metadata: map(),           # Additional metadata
  created_at: DateTime.t(),  # When created
  updated_at: DateTime.t()   # Last updated
}
```

**Key Functions:**
| Function | Line | Description |
|----------|------|-------------|
| `new/2` | 40-52 | Creates new chain with name and options |
| `add_event/2` | 59-61 | Adds event to chain |
| `add_events/2` | 66-68 | Adds multiple events to chain |
| `get_event/2` | 75-79 | Gets event by ID |
| `get_events_by_type/2` | 85-87 | Filters events by type |
| `get_events_in_range/3` | 92-97 | Gets events within time range |
| `statistics/1` | 108-137 | Calculates chain statistics |
| `find_decision_points/1` | 144-156 | Finds decision points with alternatives |
| `find_low_confidence/2` | 161-163 | Finds events below threshold |
| `to_map/1` | 168-179 | Converts chain to map |
| `from_map/1` | 184-198 | Creates chain from map |
| `merge/2` | 203-210 | Merges two chains |
| `filter_events/2` | 215-217 | Filters events with predicate |
| `sort_by_timestamp/2` | 222-230 | Sorts events by timestamp |

---

### 4. CrucibleTrace.Parser

**File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/parser.ex`
**Lines:** 281 lines
**Purpose:** Parses causal reasoning events from LLM output using XML-style tags

**XML Format Expected:**
```xml
<event type="hypothesis_formed">
  <decision>What you chose</decision>
  <alternatives>Alt1, Alt2</alternatives>
  <reasoning>Why</reasoning>
  <confidence>0.9</confidence>
  <code_section>function_name</code_section>
  <spec_reference>Section 3.2</spec_reference>
</event>
```

**Key Functions:**
| Function | Line | Description |
|----------|------|-------------|
| `parse/1` | 28-35 | Parses events from LLM output text |
| `parse_to_chain/3` | 42-51 | Parses events and creates chain |
| `extract_code/1` | 58-63 | Extracts code sections from LLM output |
| `build_causal_prompt/1` | 70-106 | Builds prompt with event instructions |
| `validate_events/1` | 188-218 | Validates event tag formatting |
| `extract_metadata/1` | 245-263 | Extracts metadata from comments |
| `split_events_and_code/1` | 270-279 | Splits events from code sections |

---

### 5. CrucibleTrace.Storage

**File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/storage.ex`
**Lines:** 359 lines
**Purpose:** Persists and retrieves causal trace chains to/from disk as JSON files

**Key Functions:**
| Function | Line | Description |
|----------|------|-------------|
| `save/2` | 23-33 | Saves chain to disk |
| `load/2` | 40-49 | Loads chain from disk by ID |
| `list/1` | 57-80 | Lists all chains in storage |
| `delete/2` | 87-93 | Deletes chain from storage |
| `search/2` | 106-118 | Searches chains by criteria |
| `export/3` | 132-159 | Exports chain to format (json, markdown, csv, mermaid_*) |
| `archive/2` | 167-189 | Archives old chains to subdirectory |

**Export Formats:**
- `:json` - JSON format
- `:markdown` - Human-readable markdown
- `:csv` - CSV format for events
- `:mermaid_flowchart` - Mermaid flowchart diagram
- `:mermaid_sequence` - Mermaid sequence diagram
- `:mermaid_timeline` - Mermaid timeline
- `:mermaid_graph` - Mermaid graph

---

### 6. CrucibleTrace.Viewer

**File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/viewer.ex`
**Lines:** 632 lines
**Purpose:** Generates interactive HTML visualizations of causal trace chains

**Key Functions:**
| Function | Line | Description |
|----------|------|-------------|
| `generate_html/2` | 23-86 | Generates HTML page for chain |
| `save_html/3` | 93-100 | Saves HTML to file |
| `open_in_browser/2` | 107-119 | Opens visualization in browser |

**Visualization Features:**
- Light/dark theme support
- Statistics panel (event counts, avg confidence, duration)
- Timeline visualization with markers
- Event filtering by type and confidence
- Color-coded event types
- Interactive JavaScript filtering
- Responsive CSS design

---

### 7. CrucibleTrace.Mermaid

**File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/mermaid.ex`
**Lines:** 278 lines
**Purpose:** Exports reasoning chains as Mermaid diagrams for documentation

**Key Functions:**
| Function | Line | Description |
|----------|------|-------------|
| `to_flowchart/2` | 31-77 | Exports as Mermaid flowchart |
| `to_sequence/2` | 89-116 | Exports as sequence diagram |
| `to_timeline/2` | 127-153 | Exports as timeline |
| `to_graph/2` | 161-205 | Exports as graph (supports relationships) |
| `escape_label/1` | 212-226 | Escapes special characters in labels |
| `truncate_label/2` | 231-241 | Truncates long labels with ellipsis |

**Mermaid Format Options:**
- `:include_confidence` - Show confidence levels (default: false)
- `:color_by_type` - Color-code by event type (default: true)
- `:max_label_length` - Max label length before truncation (default: 60)
- `:show_alternatives` - Show alternatives as notes (default: false for flowchart)

---

### 8. CrucibleTrace.Diff

**File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/diff.ex`
**Lines:** 475 lines
**Purpose:** Compares two reasoning chains and generates diff reports

**Diff Struct:**
```elixir
%CrucibleTrace.Diff{
  added_events: [Event.t()],
  removed_events: [Event.t()],
  modified_events: [{String.t(), changes()}],
  confidence_deltas: %{String.t() => float()},
  similarity_score: float(),  # 0.0 to 1.0
  summary: String.t()
}
```

**Key Functions:**
| Function | Line | Description |
|----------|------|-------------|
| `compare/3` | 46-108 | Compares two chains, returns diff |
| `to_text/1` | 113-136 | Converts diff to text format |
| `to_html/3` | 141-185 | Generates HTML side-by-side comparison |

**Matching Strategies (`:match_by` option):**
- `:id` - Match by event ID
- `:position` - Match by position in chain
- `:content` - Match by event type + decision content
- `:auto` - Auto-detect (falls back to content if no ID overlap)

---

### 9. CrucibleTrace.Application

**File:** `/home/home/p/g/North-Shore-AI/crucible_trace/lib/crucible_trace/application.ex`
**Lines:** 21 lines
**Purpose:** OTP Application with supervisor (currently no children)

---

## Test Coverage

**Test Files:**

| File | Tests | Lines | Coverage |
|------|-------|-------|----------|
| `/home/home/p/g/North-Shore-AI/crucible_trace/test/causal_trace_test.exs` | 8 | 188 | Integration tests |
| `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/event_test.exs` | 11 | 163 | Event module |
| `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/chain_test.exs` | 18 | 252 | Chain module |
| `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/parser_test.exs` | 21 | 317 | Parser module |
| `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/storage_test.exs` | 21 | 219 | Storage module |
| `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/viewer_test.exs` | 30 | 336 | Viewer module |
| `/home/home/p/g/North-Shore-AI/crucible_trace/test/crucible_trace/diff_test.exs` | 15 | 133 | Diff module |

**Total:** 103+ tests across 7 test files

---

## Dependencies

From `mix.exs`:
```elixir
{:crucible_ir, "~> 0.1.1"},  # Intermediate representation
{:jason, "~> 1.4"},          # JSON encoding/decoding
{:ex_doc, "~> 0.31", only: :dev, runtime: false},
{:dialyxir, "~> 1.4", only: [:dev], runtime: false}
```

---

## Configuration

Default storage directory: `"causal_traces"`
Default format: `:json`

The library uses `Jason` for JSON serialization and has built-in support for Mermaid diagram rendering in ExDoc documentation.

---

## File Tree Summary

```
lib/
  causal_trace.ex              # Main API (391 lines)
  crucible_trace/
    application.ex             # OTP Application (21 lines)
    chain.ex                   # Chain struct & operations (255 lines)
    diff.ex                    # Chain comparison (475 lines)
    event.ex                   # Event struct & operations (181 lines)
    mermaid.ex                 # Mermaid diagram export (278 lines)
    parser.ex                  # LLM output parsing (281 lines)
    storage.ex                 # Persistence layer (359 lines)
    viewer.ex                  # HTML visualization (632 lines)

test/
  test_helper.exs              # ExUnit setup
  causal_trace_test.exs        # Integration tests
  crucible_trace/
    chain_test.exs             # Chain unit tests
    diff_test.exs              # Diff unit tests
    event_test.exs             # Event unit tests
    parser_test.exs            # Parser unit tests
    storage_test.exs           # Storage unit tests
    viewer_test.exs            # Viewer unit tests
```

**Total Implementation:** ~2,473 lines of source code
**Total Tests:** ~1,608 lines of test code
