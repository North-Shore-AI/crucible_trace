defmodule CrucibleTrace.Storage do
  @moduledoc """
  Persists and retrieves causal trace chains to/from disk.

  Stores chains as JSON files in a configurable directory structure.
  Supports indexing, querying, and archival of trace data.
  """

  alias CrucibleTrace.Chain

  @default_storage_dir "causal_traces"

  @doc """
  Saves a chain to disk.

  Returns `{:ok, file_path}` if successful, `{:error, reason}` otherwise.

  ## Options

  - `:storage_dir` - Directory to store chains (default: "causal_traces")
  - `:format` - Storage format, currently only `:json` (default: :json)
  """
  def save(%Chain{} = chain, opts \\ []) do
    storage_dir = Keyword.get(opts, :storage_dir, @default_storage_dir)
    format = Keyword.get(opts, :format, :json)

    with :ok <- ensure_storage_dir(storage_dir),
         {:ok, file_path} <- build_file_path(storage_dir, chain, format),
         {:ok, content} <- encode_chain(chain, format),
         :ok <- File.write(file_path, content) do
      {:ok, file_path}
    end
  end

  @doc """
  Loads a chain from disk by ID.

  Returns `{:ok, chain}` if found, `{:error, reason}` otherwise.
  """
  def load(chain_id, opts \\ []) do
    storage_dir = Keyword.get(opts, :storage_dir, @default_storage_dir)
    format = Keyword.get(opts, :format, :json)

    file_path = Path.join([storage_dir, "#{chain_id}.#{format}"])

    with {:ok, content} <- File.read(file_path),
         {:ok, chain} <- decode_chain(content, format) do
      {:ok, chain}
    end
  end

  @doc """
  Lists all chains in the storage directory.

  Returns `{:ok, chain_list}` where each item contains basic chain metadata.
  """
  def list(opts \\ []) do
    storage_dir = Keyword.get(opts, :storage_dir, @default_storage_dir)
    format = Keyword.get(opts, :format, :json)

    case File.ls(storage_dir) do
      {:ok, files} ->
        chains =
          files
          |> Enum.filter(&String.ends_with?(&1, ".#{format}"))
          |> Enum.map(fn file ->
            file_path = Path.join(storage_dir, file)
            load_chain_metadata(file_path, format)
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, chains}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a chain from disk.

  Returns `:ok` if successful, `{:error, reason}` otherwise.
  """
  def delete(chain_id, opts \\ []) do
    storage_dir = Keyword.get(opts, :storage_dir, @default_storage_dir)
    format = Keyword.get(opts, :format, :json)

    file_path = Path.join([storage_dir, "#{chain_id}.#{format}"])
    File.rm(file_path)
  end

  @doc """
  Searches for chains matching a query.

  ## Options

  - `:name_contains` - Filter by name substring
  - `:created_after` - Filter by creation date
  - `:created_before` - Filter by creation date
  - `:min_events` - Minimum number of events
  - `:max_events` - Maximum number of events
  """
  def search(query, opts \\ []) do
    storage_dir = Keyword.get(opts, :storage_dir, @default_storage_dir)

    with {:ok, chains} <- list(storage_dir: storage_dir) do
      filtered =
        chains
        |> filter_by_name(query[:name_contains])
        |> filter_by_date_range(query[:created_after], query[:created_before])
        |> filter_by_event_count(query[:min_events], query[:max_events])

      {:ok, filtered}
    end
  end

  @doc """
  Exports a chain to a different format.

  Supported export formats:
  - `:json` - JSON format
  - `:markdown` - Human-readable markdown
  - `:csv` - CSV format for events
  """
  def export(%Chain{} = chain, format, _opts \\ []) do
    case format do
      :json ->
        encode_chain(chain, :json)

      :markdown ->
        {:ok, format_as_markdown(chain)}

      :csv ->
        {:ok, format_as_csv(chain)}

      _ ->
        {:error, "Unsupported export format: #{format}"}
    end
  end

  @doc """
  Archives old chains to a compressed format.

  Moves chains older than the specified days to an archive directory.
  """
  def archive(days_old, opts \\ []) do
    storage_dir = Keyword.get(opts, :storage_dir, @default_storage_dir)
    archive_dir = Path.join(storage_dir, "archive")

    with :ok <- ensure_storage_dir(archive_dir),
         {:ok, chains} <- list(storage_dir: storage_dir) do
      cutoff_date = DateTime.add(DateTime.utc_now(), -days_old * 24 * 60 * 60, :second)

      archived =
        chains
        |> Enum.filter(fn chain ->
          DateTime.compare(chain.created_at, cutoff_date) == :lt
        end)
        |> Enum.map(fn chain ->
          source = Path.join(storage_dir, "#{chain.id}.json")
          dest = Path.join(archive_dir, "#{chain.id}.json")
          File.rename(source, dest)
          chain.id
        end)

      {:ok, archived}
    end
  end

  # Private functions

  defp ensure_storage_dir(dir) do
    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to create storage directory: #{reason}"}
    end
  end

  defp build_file_path(storage_dir, %Chain{id: id}, format) do
    file_path = Path.join([storage_dir, "#{id}.#{format}"])
    {:ok, file_path}
  end

  defp encode_chain(%Chain{} = chain, :json) do
    case Jason.encode(Chain.to_map(chain), pretty: true) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, "Failed to encode chain: #{inspect(reason)}"}
    end
  end

  defp decode_chain(content, :json) do
    case Jason.decode(content) do
      {:ok, map} -> {:ok, Chain.from_map(map)}
      {:error, reason} -> {:error, "Failed to decode chain: #{inspect(reason)}"}
    end
  end

  defp load_chain_metadata(file_path, format) do
    case File.read(file_path) do
      {:ok, content} ->
        case decode_chain(content, format) do
          {:ok, chain} ->
            %{
              id: chain.id,
              name: chain.name,
              description: chain.description,
              event_count: length(chain.events),
              created_at: chain.created_at,
              updated_at: chain.updated_at
            }

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp filter_by_name(chains, nil), do: chains

  defp filter_by_name(chains, name_substr) do
    Enum.filter(chains, fn chain ->
      String.contains?(String.downcase(chain.name), String.downcase(name_substr))
    end)
  end

  defp filter_by_date_range(chains, nil, nil), do: chains

  defp filter_by_date_range(chains, start_date, end_date) do
    Enum.filter(chains, fn chain ->
      after_start =
        if start_date,
          do: DateTime.compare(chain.created_at, start_date) in [:gt, :eq],
          else: true

      before_end =
        if end_date, do: DateTime.compare(chain.created_at, end_date) in [:lt, :eq], else: true

      after_start and before_end
    end)
  end

  defp filter_by_event_count(chains, nil, nil), do: chains

  defp filter_by_event_count(chains, min_events, max_events) do
    Enum.filter(chains, fn chain ->
      min_ok = if min_events, do: chain.event_count >= min_events, else: true
      max_ok = if max_events, do: chain.event_count <= max_events, else: true
      min_ok and max_ok
    end)
  end

  defp format_as_markdown(%Chain{} = chain) do
    stats = Chain.statistics(chain)

    """
    # #{chain.name}

    #{if chain.description, do: "#{chain.description}\n", else: ""}
    **Chain ID:** #{chain.id}
    **Created:** #{DateTime.to_string(chain.created_at)}
    **Updated:** #{DateTime.to_string(chain.updated_at)}
    **Total Events:** #{stats.total_events}
    **Average Confidence:** #{Float.round(stats.avg_confidence, 2)}
    **Duration:** #{stats.duration_seconds}s

    ## Events

    #{format_events_as_markdown(chain.events)}
    """
  end

  defp format_events_as_markdown(events) do
    events
    |> Enum.with_index(1)
    |> Enum.map(fn {event, idx} ->
      """
      ### #{idx}. #{format_event_type(event.type)}

      **Decision:** #{event.decision}

      **Reasoning:** #{event.reasoning}

      #{if event.alternatives != [], do: "**Alternatives:** #{Enum.join(event.alternatives, ", ")}\n", else: ""}
      **Confidence:** #{event.confidence}
      #{if event.code_section, do: "**Code Section:** #{event.code_section}\n", else: ""}
      #{if event.spec_reference, do: "**Spec Reference:** #{event.spec_reference}\n", else: ""}
      **Timestamp:** #{DateTime.to_string(event.timestamp)}

      ---
      """
    end)
    |> Enum.join("\n")
  end

  defp format_as_csv(%Chain{} = chain) do
    header =
      "id,timestamp,type,decision,alternatives,reasoning,confidence,code_section,spec_reference\n"

    rows =
      Enum.map(chain.events, fn event ->
        [
          event.id,
          DateTime.to_iso8601(event.timestamp),
          event.type,
          escape_csv(event.decision),
          escape_csv(Enum.join(event.alternatives, "; ")),
          escape_csv(event.reasoning),
          event.confidence,
          event.code_section || "",
          event.spec_reference || ""
        ]
        |> Enum.join(",")
      end)
      |> Enum.join("\n")

    header <> rows
  end

  defp escape_csv(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"#{String.replace(value, "\"", "\"\"")}\""
    else
      value
    end
  end

  defp format_event_type(type) do
    type
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
