#!/usr/bin/env elixir

# LineageIR integration examples
# Run with: mix run examples/lineage_integration.exs

IO.puts("\n=== CrucibleTrace LineageIR Integration Examples ===\n")

output_dir = System.get_env("EXAMPLES_OUTPUT_DIR", "example_traces")
File.mkdir_p!(output_dir)

chain =
  CrucibleTrace.new_chain("LineageIR Example")
  |> CrucibleTrace.add_event(
    CrucibleTrace.create_event(
      :hypothesis_formed,
      "Use supervisor tree for workers",
      "Improves fault tolerance and restart strategy",
      confidence: 0.9
    )
  )

# Example 1: Build an artifact with embedded chain data
IO.puts("Example 1: Embedded lineage artifact")
IO.puts("-----------------------------------")

{:ok, artifact} = CrucibleTrace.lineage_artifact(chain, include_chain: true)

IO.puts("Artifact ID: #{Map.get(artifact, :id)}")
IO.puts("Artifact Type: #{Map.get(artifact, :type)}")
IO.puts("Checksum: #{Map.get(artifact, :checksum)}")

embedded =
  get_in(artifact, [:metadata, :crucible_trace, :embedded]) ||
    get_in(artifact, [:metadata, "crucible_trace", "embedded"])

IO.puts("Embedded chain data: #{inspect(embedded)}")

# Example 2: Persist chain and use file path as uri
IO.puts("\nExample 2: Persisted lineage artifact")
IO.puts("-------------------------------------")

{:ok, saved} =
  CrucibleTrace.lineage_artifact(chain,
    save: true,
    storage_dir: output_dir
  )

uri = Map.get(saved, :uri)
IO.puts("Saved uri: #{uri}")
IO.puts("File exists? #{File.exists?(uri)}")

# Example 3: Build a lightweight artifact reference
IO.puts("\nExample 3: Artifact reference")
IO.puts("-----------------------------")

{:ok, ref} = CrucibleTrace.Lineage.artifact_to_ref(saved)

IO.puts("Ref artifact_id: #{Map.get(ref, :artifact_id)}")
IO.puts("Ref uri: #{Map.get(ref, :uri)}")

IO.puts("\n=== LineageIR integration examples completed ===\n")
