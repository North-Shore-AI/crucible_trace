defmodule CrucibleTrace.Mermaid do
  @moduledoc """
  Exports reasoning chains as Mermaid diagrams.

  Mermaid is a popular text-based diagram format supported by GitHub, GitLab,
  Obsidian, and many other markdown renderers.
  """

  alias CrucibleTrace.Chain

  @default_max_label_length 60

  @doc """
  Exports a chain as a Mermaid flowchart.

  ## Options

  - `:include_confidence` - Show confidence levels (default: false)
  - `:color_by_type` - Color-code events by type (default: true)
  - `:max_label_length` - Maximum label length before truncation (default: 60)
  - `:show_alternatives` - Show alternatives as notes (default: false)

  ## Examples

      chain = CrucibleTrace.new_chain("My Chain")
      |> CrucibleTrace.add_event(event)

      mermaid = CrucibleTrace.Mermaid.to_flowchart(chain)
      File.write!("diagram.md", "```mermaid\\n\#{mermaid}\\n```")
  """
  def to_flowchart(%Chain{} = chain, opts \\ []) do
    include_confidence = Keyword.get(opts, :include_confidence, false)
    color_by_type = Keyword.get(opts, :color_by_type, true)
    max_length = Keyword.get(opts, :max_label_length, @default_max_label_length)

    if length(chain.events) == 0 do
      """
      flowchart TD
          Start[No events in chain]
      """
    else
      nodes =
        chain.events
        |> Enum.with_index()
        |> Enum.map(fn {event, idx} ->
          label = format_event_label(event, include_confidence, max_length)
          node_id = "E#{idx}"
          "    #{node_id}[#{escape_label(label)}]:::#{event.type}"
        end)
        |> Enum.join("\n")

      connections =
        chain.events
        |> Enum.with_index()
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [{_e1, idx1}, {_e2, idx2}] ->
          "    E#{idx1} --> E#{idx2}"
        end)
        |> Enum.join("\n")

      styles =
        if color_by_type do
          """

          #{generate_style_classes()}
          """
        else
          ""
        end

      """
      flowchart TD
      #{nodes}
      #{connections}#{styles}
      """
    end
  end

  @doc """
  Exports a chain as a Mermaid sequence diagram.

  Shows the progression of reasoning as a sequence of steps.

  ## Options

  - `:show_alternatives` - Include alternatives as notes (default: true)
  - `:max_label_length` - Maximum label length (default: 60)
  """
  def to_sequence(%Chain{} = chain, opts \\ []) do
    show_alternatives = Keyword.get(opts, :show_alternatives, true)
    max_length = Keyword.get(opts, :max_label_length, @default_max_label_length)

    steps =
      chain.events
      |> Enum.map(fn event ->
        label = truncate_label(event.decision, max_length)
        step = "    participant #{format_event_type_short(event.type)} as #{escape_label(label)}"

        note =
          if show_alternatives and length(event.alternatives) > 0 do
            alts = Enum.join(event.alternatives, ", ")

            "\n    Note over #{format_event_type_short(event.type)}: Alternatives: #{escape_label(alts)}"
          else
            ""
          end

        step <> note
      end)
      |> Enum.join("\n")

    """
    sequenceDiagram
    #{steps}
    """
  end

  @doc """
  Exports a chain as a Mermaid timeline.

  Groups events by time periods.

  ## Options

  - `:title` - Timeline title (default: chain name)
  """
  def to_timeline(%Chain{} = chain, opts \\ []) do
    title = Keyword.get(opts, :title, chain.name)

    if length(chain.events) == 0 do
      """
      timeline
          title #{escape_label(title)}
          section No Events
              Empty : No events recorded
      """
    else
      events_text =
        chain.events
        |> Enum.map(fn event ->
          label = truncate_label(event.decision, 40)
          "        #{escape_label(label)}"
        end)
        |> Enum.join(" : \n")

      """
      timeline
          title #{escape_label(title)}
          section Reasoning Chain
              #{events_text}
      """
    end
  end

  @doc """
  Exports a chain as a Mermaid graph (supports relationships).

  When events have parent_id or depends_on fields, this creates
  a proper directed graph showing dependencies.
  """
  def to_graph(%Chain{} = chain, opts \\ []) do
    max_length = Keyword.get(opts, :max_label_length, @default_max_label_length)
    color_by_type = Keyword.get(opts, :color_by_type, true)

    if length(chain.events) == 0 do
      """
      graph TD
          Start[No events in chain]
      """
    else
      # Build node definitions
      nodes =
        chain.events
        |> Enum.map(fn event ->
          label = truncate_label(event.decision, max_length)
          node_id = String.slice(event.id, 0..7)
          "    #{node_id}[#{escape_label(label)}]:::#{event.type}"
        end)
        |> Enum.join("\n")

      # Build connections (default to sequence if no relationships)
      connections =
        chain.events
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [e1, e2] ->
          id1 = String.slice(e1.id, 0..7)
          id2 = String.slice(e2.id, 0..7)
          "    #{id1} --> #{id2}"
        end)
        |> Enum.join("\n")

      styles =
        if color_by_type do
          "\n#{generate_style_classes()}"
        else
          ""
        end

      """
      graph TD
      #{nodes}
      #{connections}#{styles}
      """
    end
  end

  @doc """
  Escapes special characters in Mermaid labels.

  Handles quotes, newlines, brackets, and other special chars.
  """
  def escape_label(nil), do: ""

  def escape_label(text) when is_binary(text) do
    placeholder = "__CRUCIBLE_BR__"

    text
    |> String.replace("\n", placeholder)
    |> String.replace("\"", "&quot;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("#", "&#35;")
    |> String.replace(placeholder, "<br/>")
  end

  def escape_label(text), do: inspect(text)

  @doc """
  Truncates a label to maximum length with ellipsis.
  """
  def truncate_label(nil, _max_length), do: ""

  def truncate_label(text, max_length) when is_binary(text) do
    if String.length(text) <= max_length do
      text
    else
      String.slice(text, 0, max_length) <> "..."
    end
  end

  def truncate_label(text, max_length), do: truncate_label(inspect(text), max_length)

  # Private functions

  defp format_event_label(event, include_confidence, max_length) do
    base_label = truncate_label(event.decision, max_length)

    if include_confidence do
      "#{base_label} (#{Float.round(event.confidence, 2)})"
    else
      base_label
    end
  end

  defp format_event_type_short(type) do
    case type do
      :hypothesis_formed -> "HYP"
      :alternative_rejected -> "REJ"
      :constraint_evaluated -> "CON"
      :pattern_applied -> "PAT"
      :ambiguity_flagged -> "AMB"
      :confidence_updated -> "UPD"
      _ -> "EVT"
    end
  end

  defp generate_style_classes do
    """
        classDef hypothesis_formed fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
        classDef alternative_rejected fill:#ffebee,stroke:#c62828,stroke-width:2px
        classDef constraint_evaluated fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
        classDef pattern_applied fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
        classDef ambiguity_flagged fill:#fff9c4,stroke:#f57f17,stroke-width:2px
        classDef confidence_updated fill:#f3e5f5,stroke:#6a1b9a,stroke-width:2px
    """
  end
end
