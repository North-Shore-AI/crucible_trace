defmodule CrucibleTrace.Lineage do
  @moduledoc """
  Helpers for converting CrucibleTrace chains into LineageIR artifacts.

  These helpers return LineageIR structs when available and fall back to maps
  when the LineageIR dependency is not present.
  """

  import Bitwise

  alias CrucibleTrace.{Chain, Storage}

  @default_artifact_type "crucible_trace.chain"
  @default_mime_type "application/json"

  @type artifact_output :: map()
  @type ref_output :: map()

  @doc """
  Returns true when LineageIR structs are available at runtime.
  """
  @spec lineage_ir_available?() :: boolean()
  def lineage_ir_available? do
    artifact = lineage_artifact_module()
    artifact_ref = lineage_artifact_ref_module()

    Code.ensure_loaded?(artifact) and
      function_exported?(artifact, :__struct__, 0) and
      Code.ensure_loaded?(artifact_ref) and
      function_exported?(artifact_ref, :__struct__, 0)
  end

  @doc """
  Builds a LineageIR artifact for a CrucibleTrace chain.

  ## Options

  - `:artifact_id` - Override generated UUID
  - `:trace_id` - Associate artifact with a trace
  - `:span_id` - Associate artifact with a span
  - `:run_id` - Associate artifact with a run
  - `:step_id` - Associate artifact with a step
  - `:type` - Artifact type (default: #{@default_artifact_type})
  - `:uri` - Artifact location (overrides saving)
  - `:save` - Persist chain to storage and use file path as uri (default: false)
  - `:storage_dir` - Storage directory when save is true
  - `:format` - Storage format (default: :json)
  - `:mime_type` - MIME type (default: #{@default_mime_type})
  - `:metadata` - Extra metadata to merge in
  - `:include_chain` - Embed chain data in metadata (default: true)
  - `:include_checksum` - Compute sha256 checksum (default: true)
  - `:include_size` - Compute size_bytes from JSON (default: true)
  - `:created_at` - Override created_at timestamp
  """
  @spec chain_to_artifact(Chain.t(), keyword()) :: {:ok, artifact_output()} | {:error, term()}
  def chain_to_artifact(%Chain{} = chain, opts \\ []) do
    include_chain = Keyword.get(opts, :include_chain, true)
    include_checksum = Keyword.get(opts, :include_checksum, true)
    include_size = Keyword.get(opts, :include_size, true)
    save? = Keyword.get(opts, :save, false)
    uri_override = Keyword.get(opts, :uri)
    format = Keyword.get(opts, :format, :json)
    metadata = Keyword.get(opts, :metadata, %{}) || %{}

    needs_encoding = include_chain or include_checksum or include_size
    chain_map = if needs_encoding, do: Chain.to_map(chain), else: nil

    with {:ok, json} <- maybe_encode(chain_map, needs_encoding),
         {:ok, uri} <- resolve_uri(chain, uri_override, save?, opts) do
      {checksum, size_bytes} = checksum_and_size(json, include_checksum, include_size)

      artifact_metadata =
        chain_metadata(chain, chain_map, format, include_chain)
        |> merge_metadata(metadata)

      artifact =
        %{
          id: Keyword.get(opts, :artifact_id, generate_uuid()),
          trace_id: Keyword.get(opts, :trace_id),
          span_id: Keyword.get(opts, :span_id),
          run_id: Keyword.get(opts, :run_id),
          step_id: Keyword.get(opts, :step_id),
          type: Keyword.get(opts, :type, @default_artifact_type),
          uri: uri,
          checksum: checksum,
          size_bytes: size_bytes,
          mime_type: Keyword.get(opts, :mime_type, @default_mime_type),
          metadata: artifact_metadata,
          created_at: Keyword.get(opts, :created_at, now())
        }
        |> maybe_struct(lineage_artifact_module())

      {:ok, artifact}
    end
  end

  @doc """
  Builds a LineageIR artifact reference for a CrucibleTrace chain.
  """
  @spec chain_to_artifact_ref(Chain.t(), keyword()) :: {:ok, ref_output()} | {:error, term()}
  def chain_to_artifact_ref(%Chain{} = chain, opts \\ []) do
    with {:ok, artifact} <- chain_to_artifact(chain, opts) do
      artifact_to_ref(artifact, opts)
    end
  end

  @doc """
  Builds a LineageIR artifact reference from an artifact.
  """
  @spec artifact_to_ref(map(), keyword()) :: {:ok, ref_output()} | {:error, term()}
  def artifact_to_ref(artifact, opts \\ []) when is_map(artifact) do
    metadata = Keyword.get(opts, :metadata, %{}) || %{}
    ref_metadata = Map.merge(%{source: "crucible_trace"}, metadata)

    ref =
      %{
        artifact_id: Map.get(artifact, :id),
        type: Map.get(artifact, :type),
        uri: Map.get(artifact, :uri),
        checksum: Map.get(artifact, :checksum),
        metadata: ref_metadata
      }
      |> maybe_struct(lineage_artifact_ref_module())

    {:ok, ref}
  end

  defp maybe_encode(_chain_map, false), do: {:ok, nil}

  defp maybe_encode(chain_map, true) do
    case Jason.encode(chain_map) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_uri(_chain, uri, _save?, _opts) when is_binary(uri), do: {:ok, uri}

  defp resolve_uri(chain, nil, true, opts) do
    storage_opts = Keyword.take(opts, [:storage_dir, :format])

    case Storage.save(chain, storage_opts) do
      {:ok, path} -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_uri(_chain, nil, _save?, _opts), do: {:ok, nil}

  defp checksum_and_size(nil, _include_checksum, _include_size), do: {nil, nil}

  defp checksum_and_size(json, include_checksum, include_size) do
    checksum =
      if include_checksum do
        "sha256:" <> Base.encode16(:crypto.hash(:sha256, json), case: :lower)
      end

    size_bytes = if include_size, do: byte_size(json)

    {checksum, size_bytes}
  end

  defp chain_metadata(chain, chain_map, format, include_chain) do
    stats = Chain.statistics(chain)
    event_count = Map.get(stats, :total_events, length(chain.events))

    crucible_metadata = %{
      chain_id: chain.id,
      name: chain.name,
      event_count: event_count,
      avg_confidence: Map.get(stats, :avg_confidence),
      duration_seconds: Map.get(stats, :duration_seconds, 0),
      created_at: chain.created_at,
      updated_at: chain.updated_at,
      format: format,
      embedded: include_chain
    }

    crucible_metadata =
      if include_chain do
        Map.put(crucible_metadata, :chain, chain_map)
      else
        crucible_metadata
      end

    %{crucible_trace: crucible_metadata}
  end

  defp merge_metadata(base, extra) do
    Map.merge(base, extra, fn
      :crucible_trace, left, right when is_map(left) and is_map(right) ->
        Map.merge(left, right)

      _key, _left, right ->
        right
    end)
  end

  defp maybe_struct(attrs, module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0) do
      struct(module, attrs)
    else
      attrs
    end
  end

  defp lineage_artifact_module, do: Module.concat(["LineageIR", "Artifact"])
  defp lineage_artifact_ref_module, do: Module.concat(["LineageIR", "ArtifactRef"])

  defp generate_uuid do
    uuid4()
  end

  defp uuid4 do
    <<a1::32, a2::16, a3::16, a4::16, a5::48>> = :crypto.strong_rand_bytes(16)
    a3 = (a3 &&& 0x0FFF) ||| 0x4000
    a4 = (a4 &&& 0x3FFF) ||| 0x8000

    :io_lib.format(
      "~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b",
      [a1, a2, a3, a4, a5]
    )
    |> IO.iodata_to_binary()
  end

  defp now do
    DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end
end
