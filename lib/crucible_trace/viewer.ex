defmodule CrucibleTrace.Viewer do
  @moduledoc """
  Generates interactive HTML visualizations of causal trace chains.

  Creates rich, browsable views of reasoning chains with syntax highlighting,
  filtering, and interactive exploration features.
  """

  alias CrucibleTrace.{Chain, Event}

  @doc """
  Generates an HTML page for visualizing a chain.

  Returns the HTML content as a string.

  ## Options

  - `:title` - Page title (default: chain name)
  - `:style` - CSS theme, `:light` or `:dark` (default: :light)
  - `:include_statistics` - Show statistics panel (default: true)
  - `:include_timeline` - Show timeline visualization (default: true)
  """
  def generate_html(%Chain{} = chain, opts \\ []) do
    title = Keyword.get(opts, :title, chain.name)
    style = Keyword.get(opts, :style, :light)
    include_stats = Keyword.get(opts, :include_statistics, true)
    include_timeline = Keyword.get(opts, :include_timeline, true)

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>#{html_escape(title)} - CausalTrace</title>
      <style>
        #{generate_css(style)}
      </style>
    </head>
    <body>
      <div class="container">
        <header>
          <h1>#{html_escape(chain.name)}</h1>
          #{if chain.description, do: "<p class=\"description\">#{html_escape(chain.description)}</p>", else: ""}
          <div class="metadata">
            <span>Chain ID: #{html_escape(chain.id)}</span>
            <span>Created: #{DateTime.to_string(chain.created_at)}</span>
            <span>Events: #{length(chain.events)}</span>
          </div>
        </header>

        #{if include_stats, do: generate_statistics_section(chain), else: ""}

        #{if include_timeline, do: generate_timeline(chain), else: ""}

        <section class="events">
          <h2>Reasoning Chain</h2>
          <div class="filter-controls">
            <label>Filter by type:
              <select id="typeFilter" onchange="filterEvents()">
                <option value="all">All Events</option>
                <option value="hypothesis_formed">Hypothesis Formed</option>
                <option value="alternative_rejected">Alternative Rejected</option>
                <option value="constraint_evaluated">Constraint Evaluated</option>
                <option value="pattern_applied">Pattern Applied</option>
                <option value="ambiguity_flagged">Ambiguity Flagged</option>
                <option value="confidence_updated">Confidence Updated</option>
              </select>
            </label>
            <label>Min confidence:
              <input type="range" id="confidenceSlider" min="0" max="100" value="0"
                     onchange="filterEvents()" oninput="updateConfidenceLabel(this.value)">
              <span id="confidenceLabel">0.0</span>
            </label>
          </div>
          #{generate_events_html(chain.events)}
        </section>
      </div>

      <script>
        #{generate_javascript()}
      </script>
    </body>
    </html>
    """
  end

  @doc """
  Saves the HTML visualization to a file.

  Returns `{:ok, file_path}` if successful, `{:error, reason}` otherwise.
  """
  def save_html(%Chain{} = chain, file_path, opts \\ []) do
    html = generate_html(chain, opts)

    case File.write(file_path, html) do
      :ok -> {:ok, file_path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Opens the HTML visualization in the default browser.

  Saves to a temporary file and opens it.
  """
  def open_in_browser(%Chain{} = chain, opts \\ []) do
    temp_file = Path.join(System.tmp_dir!(), "causal_trace_#{chain.id}.html")

    with {:ok, _path} <- save_html(chain, temp_file, opts) do
      case :os.type() do
        {:unix, :darwin} -> System.cmd("open", [temp_file])
        {:unix, _} -> System.cmd("xdg-open", [temp_file])
        {:win32, _} -> System.cmd("cmd", ["/c", "start", temp_file])
      end

      {:ok, temp_file}
    end
  end

  # Private functions

  defp generate_css(:light) do
    """
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      line-height: 1.6;
      color: #333;
      background: #f5f5f5;
    }

    .container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 20px;
    }

    header {
      background: white;
      padding: 30px;
      border-radius: 8px;
      margin-bottom: 20px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    h1 {
      color: #2c3e50;
      margin-bottom: 10px;
    }

    h2 {
      color: #34495e;
      margin-bottom: 15px;
      padding-bottom: 10px;
      border-bottom: 2px solid #3498db;
    }

    .description {
      color: #666;
      font-size: 1.1em;
      margin-bottom: 15px;
    }

    .metadata {
      display: flex;
      gap: 20px;
      flex-wrap: wrap;
      color: #7f8c8d;
      font-size: 0.9em;
      margin-top: 15px;
    }

    .statistics {
      background: white;
      padding: 25px;
      border-radius: 8px;
      margin-bottom: 20px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 20px;
      margin-top: 15px;
    }

    .stat-item {
      padding: 15px;
      background: #f8f9fa;
      border-radius: 6px;
      border-left: 4px solid #3498db;
    }

    .stat-label {
      font-size: 0.9em;
      color: #7f8c8d;
      margin-bottom: 5px;
    }

    .stat-value {
      font-size: 1.8em;
      font-weight: bold;
      color: #2c3e50;
    }

    .timeline {
      background: white;
      padding: 25px;
      border-radius: 8px;
      margin-bottom: 20px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    .timeline-bar {
      height: 40px;
      background: #ecf0f1;
      border-radius: 20px;
      position: relative;
      overflow: hidden;
    }

    .timeline-marker {
      position: absolute;
      width: 3px;
      height: 100%;
      background: #3498db;
      transition: all 0.3s;
    }

    .timeline-marker:hover {
      width: 6px;
      background: #2980b9;
    }

    .events {
      background: white;
      padding: 25px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    .filter-controls {
      display: flex;
      gap: 20px;
      margin-bottom: 20px;
      padding: 15px;
      background: #f8f9fa;
      border-radius: 6px;
      flex-wrap: wrap;
    }

    .filter-controls label {
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 0.95em;
    }

    .filter-controls select,
    .filter-controls input[type="range"] {
      padding: 5px 10px;
      border: 1px solid #ddd;
      border-radius: 4px;
    }

    .event {
      margin-bottom: 20px;
      padding: 20px;
      border-left: 4px solid #3498db;
      background: #f8f9fa;
      border-radius: 4px;
      transition: all 0.3s;
    }

    .event:hover {
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      transform: translateX(5px);
    }

    .event.hidden {
      display: none;
    }

    .event-header {
      display: flex;
      justify-content: space-between;
      align-items: start;
      margin-bottom: 15px;
    }

    .event-type {
      display: inline-block;
      padding: 4px 12px;
      border-radius: 12px;
      font-size: 0.85em;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .event-type.hypothesis_formed {
      background: #e8f5e9;
      color: #2e7d32;
    }

    .event-type.alternative_rejected {
      background: #ffebee;
      color: #c62828;
    }

    .event-type.constraint_evaluated {
      background: #fff3e0;
      color: #ef6c00;
    }

    .event-type.pattern_applied {
      background: #e3f2fd;
      color: #1565c0;
    }

    .event-type.ambiguity_flagged {
      background: #fff9c4;
      color: #f57f17;
    }

    .event-type.confidence_updated {
      background: #f3e5f5;
      color: #6a1b9a;
    }

    .confidence-badge {
      padding: 4px 10px;
      border-radius: 12px;
      font-size: 0.85em;
      font-weight: 600;
    }

    .confidence-high {
      background: #c8e6c9;
      color: #2e7d32;
    }

    .confidence-medium {
      background: #fff9c4;
      color: #f57f17;
    }

    .confidence-low {
      background: #ffcdd2;
      color: #c62828;
    }

    .decision {
      font-size: 1.1em;
      font-weight: 600;
      color: #2c3e50;
      margin-bottom: 10px;
    }

    .reasoning {
      color: #555;
      margin-bottom: 15px;
      line-height: 1.6;
    }

    .alternatives {
      background: white;
      padding: 12px;
      border-radius: 4px;
      margin-bottom: 10px;
    }

    .alternatives-label {
      font-weight: 600;
      color: #7f8c8d;
      font-size: 0.9em;
      margin-bottom: 5px;
    }

    .alternative-item {
      padding: 4px 8px;
      margin: 4px 0;
      color: #666;
    }

    .alternative-item:before {
      content: "• ";
      color: #3498db;
      font-weight: bold;
    }

    .event-meta {
      display: flex;
      gap: 15px;
      flex-wrap: wrap;
      margin-top: 15px;
      padding-top: 15px;
      border-top: 1px solid #ddd;
      font-size: 0.9em;
      color: #7f8c8d;
    }

    .code-section {
      font-family: 'Monaco', 'Menlo', monospace;
      background: #2c3e50;
      color: #ecf0f1;
      padding: 2px 6px;
      border-radius: 3px;
      font-size: 0.9em;
    }
    """
  end

  defp generate_css(:dark) do
    # Dark theme CSS (simplified for brevity)
    """
    /* Dark theme - similar structure with dark colors */
    body { background: #1a1a1a; color: #e0e0e0; }
    header, .statistics, .timeline, .events { background: #2d2d2d; }
    .event { background: #3a3a3a; }
    /* ... more dark theme styles ... */
    """
  end

  defp generate_statistics_section(chain) do
    stats = Chain.statistics(chain)

    type_counts_html =
      (stats[:event_type_counts] || %{})
      |> Enum.map(fn {type, count} ->
        "<div class=\"stat-item\">
          <div class=\"stat-label\">#{format_event_type(type)}</div>
          <div class=\"stat-value\">#{count}</div>
        </div>"
      end)
      |> Enum.join("\n")

    avg_confidence = stats[:avg_confidence] || 0.0
    duration = stats[:duration_seconds] || 0

    """
    <section class="statistics">
      <h2>Statistics</h2>
      <div class="stats-grid">
        <div class="stat-item">
          <div class="stat-label">Total Events</div>
          <div class="stat-value">#{stats.total_events}</div>
        </div>
        <div class="stat-item">
          <div class="stat-label">Average Confidence</div>
          <div class="stat-value">#{Float.round(avg_confidence, 2)}</div>
        </div>
        <div class="stat-item">
          <div class="stat-label">Duration</div>
          <div class="stat-value">#{duration}s</div>
        </div>
        #{type_counts_html}
      </div>
    </section>
    """
  end

  defp generate_timeline(chain) do
    if length(chain.events) == 0 do
      ""
    else
      first_time = List.first(chain.events).timestamp
      last_time = List.last(chain.events).timestamp
      total_duration = DateTime.diff(last_time, first_time, :millisecond)

      markers =
        chain.events
        |> Enum.map(fn event ->
          offset = DateTime.diff(event.timestamp, first_time, :millisecond)
          position = if total_duration > 0, do: offset / total_duration * 100, else: 0

          """
          <div class="timeline-marker" style="left: #{position}%"
               title="#{format_event_type(event.type)}: #{html_escape(event.decision)}"></div>
          """
        end)
        |> Enum.join("\n")

      """
      <section class="timeline">
        <h2>Timeline</h2>
        <div class="timeline-bar">
          #{markers}
        </div>
      </section>
      """
    end
  end

  defp generate_events_html(events) do
    events
    |> Enum.with_index(1)
    |> Enum.map(fn {event, idx} ->
      generate_event_html(event, idx)
    end)
    |> Enum.join("\n")
  end

  defp generate_event_html(%Event{} = event, idx) do
    confidence_class = confidence_class(event.confidence)
    alternatives_html = generate_alternatives_html(event.alternatives)

    meta_parts = []

    meta_parts =
      if event.code_section do
        [
          "<span>Code: <code class=\"code-section\">#{html_escape(event.code_section)}</code></span>"
          | meta_parts
        ]
      else
        meta_parts
      end

    meta_parts =
      if event.spec_reference do
        ["<span>Spec: #{html_escape(event.spec_reference)}</span>" | meta_parts]
      else
        meta_parts
      end

    meta_parts = ["<span>#{DateTime.to_string(event.timestamp)}</span>" | meta_parts]

    meta_html =
      if length(meta_parts) > 0 do
        "<div class=\"event-meta\">#{Enum.join(Enum.reverse(meta_parts), "")}</div>"
      else
        ""
      end

    """
    <div class="event" data-type="#{event.type}" data-confidence="#{event.confidence}">
      <div class="event-header">
        <span class="event-type #{event.type}">#{format_event_type(event.type)}</span>
        <span class="confidence-badge #{confidence_class}">#{Float.round(event.confidence, 2)}</span>
      </div>
      <div class="decision">#{idx}. #{html_escape(event.decision)}</div>
      <div class="reasoning">#{html_escape(event.reasoning)}</div>
      #{alternatives_html}
      #{meta_html}
    </div>
    """
  end

  defp generate_alternatives_html([]), do: ""

  defp generate_alternatives_html(alternatives) do
    items =
      alternatives
      |> Enum.map(fn alt ->
        "<div class=\"alternative-item\">#{html_escape(alt)}</div>"
      end)
      |> Enum.join("\n")

    """
    <div class="alternatives">
      <div class="alternatives-label">Alternatives Considered:</div>
      #{items}
    </div>
    """
  end

  defp confidence_class(confidence) when confidence >= 0.8, do: "confidence-high"
  defp confidence_class(confidence) when confidence >= 0.5, do: "confidence-medium"
  defp confidence_class(_), do: "confidence-low"

  defp format_event_type(type) do
    type
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp html_escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp html_escape(nil), do: ""
  defp html_escape(other), do: to_string(other) |> html_escape()

  defp generate_javascript do
    """
    function filterEvents() {
      const typeFilter = document.getElementById('typeFilter').value;
      const confidenceThreshold = document.getElementById('confidenceSlider').value / 100;
      const events = document.querySelectorAll('.event');

      events.forEach(event => {
        const eventType = event.dataset.type;
        const eventConfidence = parseFloat(event.dataset.confidence);

        const typeMatch = typeFilter === 'all' || eventType === typeFilter;
        const confidenceMatch = eventConfidence >= confidenceThreshold;

        if (typeMatch && confidenceMatch) {
          event.classList.remove('hidden');
        } else {
          event.classList.add('hidden');
        }
      });
    }

    function updateConfidenceLabel(value) {
      document.getElementById('confidenceLabel').textContent = (value / 100).toFixed(2);
    }

    // Initialize
    document.addEventListener('DOMContentLoaded', () => {
      filterEvents();
    });
    """
  end
end
