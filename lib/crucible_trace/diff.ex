defmodule CrucibleTrace.Diff do
  @moduledoc """
  Compares two reasoning chains and generates diff reports.

  Enables analysis of how LLM reasoning changes between different runs,
  models, or prompt variations.
  """

  alias CrucibleTrace.{Chain, Event}

  @type change :: {:changed, old_value :: term(), new_value :: term()}
  @type changes :: %{atom() => change()}

  @type t :: %__MODULE__{
          added_events: [Event.t()],
          removed_events: [Event.t()],
          modified_events: [{String.t(), changes()}],
          confidence_deltas: %{String.t() => float()},
          similarity_score: float(),
          summary: String.t()
        }

  defstruct [
    :added_events,
    :removed_events,
    :modified_events,
    :confidence_deltas,
    :similarity_score,
    :summary
  ]

  @doc """
  Compares two chains and returns a diff structure.

  ## Options

  - `:match_by` - How to match events: `:id` (default), `:position`, `:content`
  - `:ignore_timestamps` - Ignore timestamp differences (default: true)

  ## Examples

      {:ok, diff} = CrucibleTrace.Diff.compare(chain1, chain2)
      IO.puts(diff.summary)
      # => "2 added, 1 removed, 3 modified"
  """
  def compare(%Chain{} = chain1, %Chain{} = chain2, opts \\ []) do
    match_by = Keyword.get(opts, :match_by, :auto)
    ignore_timestamps = Keyword.get(opts, :ignore_timestamps, true)

    # Build event maps for comparison (auto falls back to content if ids don't overlap)
    {events1, events2} = build_event_maps(chain1.events, chain2.events, match_by)

    # Find added, removed, and common events
    keys1 = MapSet.new(Map.keys(events1))
    keys2 = MapSet.new(Map.keys(events2))

    added_keys = MapSet.difference(keys2, keys1)
    removed_keys = MapSet.difference(keys1, keys2)
    common_keys = MapSet.intersection(keys1, keys2)

    added_events = Enum.map(added_keys, &Map.get(events2, &1))
    removed_events = Enum.map(removed_keys, &Map.get(events1, &1))

    # Find modified events
    {modified_events, confidence_deltas_map} =
      common_keys
      |> Enum.map(fn key ->
        event1 = Map.get(events1, key)
        event2 = Map.get(events2, key)
        {key, compare_events(event1, event2, ignore_timestamps)}
      end)
      |> Enum.reduce({[], %{}}, fn {key, changes}, {mods, deltas} ->
        if map_size(changes) == 0 do
          {mods, deltas}
        else
          updated_deltas =
            case changes[:confidence] do
              {:changed, old_conf, new_conf} ->
                Map.put(deltas, key, Float.round(new_conf - old_conf, 6))

              _ ->
                deltas
            end

          {[{key, changes} | mods], updated_deltas}
        end
      end)

    modified_events = Enum.reverse(modified_events)

    # Calculate similarity score
    similarity = calculate_similarity(chain1.events, chain2.events, common_keys)

    # Generate summary
    summary =
      generate_summary(length(added_events), length(removed_events), length(modified_events))

    diff = %__MODULE__{
      added_events: added_events,
      removed_events: removed_events,
      modified_events: modified_events,
      confidence_deltas: confidence_deltas_map,
      similarity_score: similarity,
      summary: summary
    }

    {:ok, diff}
  end

  @doc """
  Converts a diff to human-readable text format.
  """
  def to_text(%__MODULE__{} = diff) do
    """
    # Chain Comparison Summary

    #{diff.summary}
    Similarity: #{Float.round(diff.similarity_score * 100, 1)}%

    ## Added Events (#{length(diff.added_events)})

    #{format_events_text(diff.added_events, "+")}

    ## Removed Events (#{length(diff.removed_events)})

    #{format_events_text(diff.removed_events, "-")}

    ## Modified Events (#{length(diff.modified_events)})

    #{format_modified_events_text(diff.modified_events)}

    ## Confidence Changes

    #{format_confidence_deltas(diff.confidence_deltas)}
    """
  end

  @doc """
  Generates an HTML visualization of the diff with side-by-side comparison.
  """
  def to_html(%__MODULE__{} = diff, %Chain{} = chain1, %Chain{} = chain2) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Chain Diff - #{html_escape(chain1.name)} vs #{html_escape(chain2.name)}</title>
      <style>
        #{generate_diff_css()}
      </style>
    </head>
    <body>
      <div class="container">
        <header>
          <h1>Chain Comparison</h1>
          <div class="chains">
            <div class="chain-info">
              <h3>Chain A: #{html_escape(chain1.name)}</h3>
              <p>Events: #{length(chain1.events)}</p>
            </div>
            <div class="chain-info">
              <h3>Chain B: #{html_escape(chain2.name)}</h3>
              <p>Events: #{length(chain2.events)}</p>
            </div>
          </div>
        </header>

        <section class="summary">
          <h2>Summary</h2>
          <p>#{html_escape(diff.summary)}</p>
          <div class="similarity">
            <span class="label">Similarity:</span>
            <span class="value">#{Float.round(diff.similarity_score * 100, 1)}%</span>
            <div class="similarity-bar">
              <div class="similarity-fill" style="width: #{diff.similarity_score * 100}%"></div>
            </div>
          </div>
        </section>

        #{generate_diff_sections_html(diff)}
      </div>
    </body>
    </html>
    """
  end

  # Private functions

  defp build_event_maps(events1, events2, :auto) do
    id_map1 = build_event_map(events1, :id)
    id_map2 = build_event_map(events2, :id)

    common_ids = MapSet.intersection(MapSet.new(Map.keys(id_map1)), MapSet.new(Map.keys(id_map2)))

    if MapSet.size(common_ids) > 0 do
      {id_map1, id_map2}
    else
      {build_event_map(events1, :content), build_event_map(events2, :content)}
    end
  end

  defp build_event_maps(events1, events2, strategy) do
    {build_event_map(events1, strategy), build_event_map(events2, strategy)}
  end

  defp build_event_map(events, :id) do
    Enum.map(events, fn event -> {event.id, event} end) |> Map.new()
  end

  defp build_event_map(events, :position) do
    events
    |> Enum.with_index()
    |> Enum.map(fn {event, idx} -> {idx, event} end)
    |> Map.new()
  end

  defp build_event_map(events, :content) do
    events
    |> Enum.map(fn event ->
      key = "#{event.type}_#{event.decision}"
      {key, event}
    end)
    |> Map.new()
  end

  defp compare_events(event1, event2, ignore_timestamps) do
    changes = %{}

    changes =
      if event1.decision != event2.decision do
        Map.put(changes, :decision, {:changed, event1.decision, event2.decision})
      else
        changes
      end

    changes =
      if event1.reasoning != event2.reasoning do
        Map.put(changes, :reasoning, {:changed, event1.reasoning, event2.reasoning})
      else
        changes
      end

    changes =
      if event1.confidence != event2.confidence do
        Map.put(changes, :confidence, {:changed, event1.confidence, event2.confidence})
      else
        changes
      end

    changes =
      if event1.alternatives != event2.alternatives do
        Map.put(changes, :alternatives, {:changed, event1.alternatives, event2.alternatives})
      else
        changes
      end

    changes =
      if !ignore_timestamps and event1.timestamp != event2.timestamp do
        Map.put(changes, :timestamp, {:changed, event1.timestamp, event2.timestamp})
      else
        changes
      end

    changes
  end

  defp calculate_similarity(events1, events2, common_keys) do
    total_events = max(length(events1), length(events2))

    if total_events == 0 do
      1.0
    else
      common_count = MapSet.size(common_keys)
      common_count / total_events
    end
  end

  defp generate_summary(added, removed, modified) do
    Enum.join(
      [
        "#{added} added",
        "#{removed} removed",
        "#{modified} modified"
      ],
      ", "
    )
  end

  defp format_events_text([], _prefix), do: "(none)"

  defp format_events_text(events, prefix) do
    events
    |> Enum.map(fn event ->
      """
      #{prefix} [#{event.type}] #{event.decision}
         Reasoning: #{event.reasoning}
         Confidence: #{event.confidence}
      """
    end)
    |> Enum.join("\n")
  end

  defp format_modified_events_text([]), do: "(none)"

  defp format_modified_events_text(modified) do
    modified
    |> Enum.map(fn {event_id, changes} ->
      change_strs =
        changes
        |> Enum.map(fn {field, {:changed, old, new}} ->
          "  - #{field}: #{inspect(old)} -> #{inspect(new)}"
        end)
        |> Enum.join("\n")

      """
      Event #{event_id}:
      #{change_strs}
      """
    end)
    |> Enum.join("\n")
  end

  defp format_confidence_deltas(deltas) when map_size(deltas) == 0, do: "(none)"

  defp format_confidence_deltas(deltas) do
    deltas
    |> Enum.map(fn {event_id, delta} ->
      sign = if delta >= 0, do: "+", else: ""
      "  #{event_id}: #{sign}#{Float.round(delta, 3)}"
    end)
    |> Enum.join("\n")
  end

  defp generate_diff_css do
    """
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      line-height: 1.6;
      color: #333;
      background: #f5f5f5;
      padding: 20px;
    }
    .container { max-width: 1200px; margin: 0 auto; }
    header {
      background: white;
      padding: 30px;
      border-radius: 8px;
      margin-bottom: 20px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    h1 { color: #2c3e50; margin-bottom: 20px; }
    .chains {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 20px;
      margin-top: 20px;
    }
    .chain-info {
      padding: 15px;
      background: #f8f9fa;
      border-radius: 6px;
    }
    .summary {
      background: white;
      padding: 25px;
      border-radius: 8px;
      margin-bottom: 20px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .similarity {
      margin-top: 15px;
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .similarity-bar {
      flex: 1;
      height: 20px;
      background: #ecf0f1;
      border-radius: 10px;
      overflow: hidden;
    }
    .similarity-fill {
      height: 100%;
      background: linear-gradient(90deg, #e74c3c, #f39c12, #27ae60);
      transition: width 0.3s;
    }
    .diff-section {
      background: white;
      padding: 25px;
      border-radius: 8px;
      margin-bottom: 20px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .added { border-left: 4px solid #27ae60; background: #e8f5e9; }
    .removed { border-left: 4px solid #e74c3c; background: #ffebee; }
    .modified { border-left: 4px solid #f39c12; background: #fff3e0; }
    .event {
      padding: 15px;
      margin-bottom: 10px;
      border-radius: 4px;
    }
    """
  end

  defp generate_diff_sections_html(diff) do
    """
    <section class="diff-section">
      <h2>Added Events (#{length(diff.added_events)})</h2>
      #{generate_events_html(diff.added_events, "added")}
    </section>

    <section class="diff-section">
      <h2>Removed Events (#{length(diff.removed_events)})</h2>
      #{generate_events_html(diff.removed_events, "removed")}
    </section>

    <section class="diff-section">
      <h2>Modified Events (#{length(diff.modified_events)})</h2>
      #{generate_modified_html(diff.modified_events)}
    </section>
    """
  end

  defp generate_events_html([], _class), do: "<p>None</p>"

  defp generate_events_html(events, class) do
    events
    |> Enum.map(fn event ->
      """
      <div class="event #{class}">
        <strong>[#{event.type}]</strong> #{html_escape(event.decision)}
        <p>#{html_escape(event.reasoning)}</p>
        <small>Confidence: #{event.confidence}</small>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp generate_modified_html([]), do: "<p>None</p>"

  defp generate_modified_html(modified) do
    modified
    |> Enum.map(fn {_id, changes} ->
      change_html =
        changes
        |> Enum.map(fn {field, {:changed, old, new}} ->
          "<li><strong>#{field}:</strong> #{html_escape(inspect(old))} → #{html_escape(inspect(new))}</li>"
        end)
        |> Enum.join("\n")

      """
      <div class="event modified">
        <ul>
          #{change_html}
        </ul>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp html_escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp html_escape(text), do: text
end
