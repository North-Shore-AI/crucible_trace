#!/usr/bin/env elixir

# Storage and search examples for CrucibleTrace
# Run with: mix run examples/storage_and_search.exs

IO.puts("\n=== CrucibleTrace Storage and Search Examples ===\n")

output_dir = System.get_env("EXAMPLES_OUTPUT_DIR", "example_traces")
File.mkdir_p!(output_dir)
storage_dir = output_dir

# Helper function to create sample chains
defmodule ChainFactory do
  def create_sample_chain(name, event_count, avg_confidence) do
    chain = CrucibleTrace.new_chain(name, description: "Sample chain for #{name}")

    events =
      for i <- 1..event_count do
        # Vary confidence around the average
        confidence = max(0.5, min(1.0, avg_confidence + (:rand.uniform() - 0.5) * 0.2))

        type =
          Enum.random([
            :hypothesis_formed,
            :pattern_applied,
            :constraint_evaluated,
            :alternative_rejected
          ])

        CrucibleTrace.create_event(
          type,
          "Decision #{i} for #{name}",
          "Reasoning for decision #{i}",
          alternatives: ["Alt A", "Alt B"],
          confidence: confidence,
          code_section: "Module#{i}"
        )
      end

    CrucibleTrace.add_events(chain, events)
  end
end

# Example 1: Creating and saving multiple chains
IO.puts("Example 1: Creating and saving multiple chains")
IO.puts("-----------------------------------------------")

chains_to_create = [
  {"User Authentication System", 5, 0.9},
  {"Payment Processing", 8, 0.85},
  {"Email Notification Service", 4, 0.75},
  {"Database Migration Strategy", 6, 0.95},
  {"API Rate Limiting", 3, 0.80}
]

IO.puts("Creating #{length(chains_to_create)} sample chains...\n")

created_chains =
  Enum.map(chains_to_create, fn {name, count, conf} ->
    chain = ChainFactory.create_sample_chain(name, count, conf)

    case CrucibleTrace.save(chain, storage_dir: storage_dir) do
      {:ok, path} ->
        IO.puts("✓ #{name}: #{count} events, avg confidence #{conf}")
        IO.puts("  Saved to: #{Path.basename(path)}")
        chain

      {:error, reason} ->
        IO.puts("✗ Failed to save #{name}: #{inspect(reason)}")
        nil
    end
  end)
  |> Enum.reject(&is_nil/1)

IO.puts("\n✓ Created and saved #{length(created_chains)} chains")

# Example 2: Listing all chains
IO.puts("\n\nExample 2: Listing all saved chains")
IO.puts("-----------------------------------------------")

case CrucibleTrace.list_chains(storage_dir: storage_dir) do
  {:ok, chains} ->
    IO.puts("Found #{length(chains)} chain(s) in storage:\n")

    chains
    |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
    |> Enum.each(fn chain_meta ->
      IO.puts("• #{chain_meta.name}")
      IO.puts("  ID: #{chain_meta.id}")
      IO.puts("  Events: #{chain_meta.event_count}")
      IO.puts("  Created: #{DateTime.to_string(chain_meta.created_at)}")

      if chain_meta.description do
        IO.puts("  Description: #{chain_meta.description}")
      end

      IO.puts("")
    end)

  {:error, reason} ->
    IO.puts("✗ Failed to list chains: #{inspect(reason)}")
end

# Example 3: Loading a specific chain
IO.puts("\n\nExample 3: Loading and analyzing a specific chain")
IO.puts("-----------------------------------------------")

if length(created_chains) > 0 do
  chain_to_load = Enum.random(created_chains)
  IO.puts("Loading chain: #{chain_to_load.name}")

  case CrucibleTrace.load(chain_to_load.id, storage_dir: storage_dir) do
    {:ok, loaded_chain} ->
      IO.puts("✓ Successfully loaded chain")
      IO.puts("  Name: #{loaded_chain.name}")
      IO.puts("  Events: #{length(loaded_chain.events)}")
      IO.puts("  Created: #{DateTime.to_string(loaded_chain.created_at)}")

      stats = CrucibleTrace.statistics(loaded_chain)
      IO.puts("\n  Statistics:")
      IO.puts("    Average Confidence: #{Float.round(stats.avg_confidence, 2)}")
      IO.puts("    Event Types:")

      Enum.each(stats.event_type_counts, fn {type, count} ->
        IO.puts("      - #{type}: #{count}")
      end)

    {:error, reason} ->
      IO.puts("✗ Failed to load chain: #{inspect(reason)}")
  end
else
  IO.puts("No chains available to load")
end

# Example 4: Searching chains with filters
IO.puts("\n\nExample 4: Searching chains with filters")
IO.puts("-----------------------------------------------")

IO.puts("\n1. Search by name (containing 'System'):")

case CrucibleTrace.search([name_contains: "System"], storage_dir: storage_dir) do
  {:ok, results} ->
    IO.puts("   Found #{length(results)} match(es):")

    Enum.each(results, fn chain ->
      IO.puts("   • #{chain.name} (#{chain.event_count} events)")
    end)

  {:error, reason} ->
    IO.puts("   ✗ Search failed: #{inspect(reason)}")
end

IO.puts("\n2. Search by event count (minimum 5 events):")

case CrucibleTrace.search([min_events: 5], storage_dir: storage_dir) do
  {:ok, results} ->
    IO.puts("   Found #{length(results)} match(es):")

    Enum.each(results, fn chain ->
      IO.puts("   • #{chain.name} (#{chain.event_count} events)")
    end)

  {:error, reason} ->
    IO.puts("   ✗ Search failed: #{inspect(reason)}")
end

IO.puts("\n3. Search by creation date (created in last hour):")
one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

case CrucibleTrace.search([created_after: one_hour_ago], storage_dir: storage_dir) do
  {:ok, results} ->
    IO.puts("   Found #{length(results)} match(es) created in the last hour:")

    Enum.each(results, fn chain ->
      minutes_ago = DateTime.diff(DateTime.utc_now(), chain.created_at, :second) |> div(60)
      IO.puts("   • #{chain.name} (#{minutes_ago} minutes ago)")
    end)

  {:error, reason} ->
    IO.puts("   ✗ Search failed: #{inspect(reason)}")
end

IO.puts("\n4. Combined search (name + minimum events):")

case CrucibleTrace.search(
       [name_contains: "a", min_events: 4],
       storage_dir: storage_dir
     ) do
  {:ok, results} ->
    IO.puts("   Found #{length(results)} match(es):")

    Enum.each(results, fn chain ->
      IO.puts("   • #{chain.name} (#{chain.event_count} events)")
    end)

  {:error, reason} ->
    IO.puts("   ✗ Search failed: #{inspect(reason)}")
end

# Example 5: Exporting chains in different formats
IO.puts("\n\nExample 5: Exporting chains in different formats")
IO.puts("-----------------------------------------------")

if length(created_chains) > 0 do
  export_chain = hd(created_chains)
  IO.puts("Exporting chain: #{export_chain.name}\n")

  # Export to JSON
  case CrucibleTrace.export(export_chain, :json) do
    {:ok, json} ->
      json_file = Path.join(output_dir, "export_sample.json")
      File.write!(json_file, json)
      IO.puts("✓ JSON export: #{json_file}")
      IO.puts("  Size: #{String.length(json)} bytes")

    {:error, reason} ->
      IO.puts("✗ JSON export failed: #{reason}")
  end

  # Export to Markdown
  case CrucibleTrace.export(export_chain, :markdown) do
    {:ok, markdown} ->
      md_file = Path.join(output_dir, "export_sample.md")
      File.write!(md_file, markdown)
      IO.puts("✓ Markdown export: #{md_file}")
      IO.puts("  Size: #{String.length(markdown)} bytes")
      IO.puts("  Preview:")
      preview = markdown |> String.split("\n") |> Enum.take(10) |> Enum.join("\n")
      IO.puts("  " <> String.replace(preview, "\n", "\n  "))
      IO.puts("  ...")

    {:error, reason} ->
      IO.puts("✗ Markdown export failed: #{reason}")
  end

  # Export to CSV
  case CrucibleTrace.export(export_chain, :csv) do
    {:ok, csv} ->
      csv_file = Path.join(output_dir, "export_sample.csv")
      File.write!(csv_file, csv)
      IO.puts("✓ CSV export: #{csv_file}")
      IO.puts("  Size: #{String.length(csv)} bytes")
      IO.puts("  Rows: #{length(String.split(csv, "\n"))}")

    {:error, reason} ->
      IO.puts("✗ CSV export failed: #{reason}")
  end
end

# Example 6: Deleting chains
IO.puts("\n\nExample 6: Chain deletion")
IO.puts("-----------------------------------------------")

# Create a temporary chain for deletion demo
temp_chain = ChainFactory.create_sample_chain("Temporary Test Chain", 2, 0.8)

case CrucibleTrace.save(temp_chain, storage_dir: storage_dir) do
  {:ok, _path} ->
    IO.puts("✓ Created temporary chain for deletion demo")

    # Verify it exists
    case CrucibleTrace.load(temp_chain.id, storage_dir: storage_dir) do
      {:ok, _} ->
        IO.puts("✓ Verified chain exists")

        # Delete it
        case CrucibleTrace.delete(temp_chain.id, storage_dir: storage_dir) do
          :ok ->
            IO.puts("✓ Chain deleted successfully")

            # Verify deletion
            case CrucibleTrace.load(temp_chain.id, storage_dir: storage_dir) do
              {:error, _} ->
                IO.puts("✓ Verified chain no longer exists")

              {:ok, _} ->
                IO.puts("✗ Chain still exists after deletion!")
            end

          {:error, reason} ->
            IO.puts("✗ Failed to delete chain: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("✗ Chain doesn't exist: #{inspect(reason)}")
    end

  {:error, reason} ->
    IO.puts("✗ Failed to create temporary chain: #{inspect(reason)}")
end

# Example 7: Archiving old chains
IO.puts("\n\nExample 7: Archiving old chains")
IO.puts("-----------------------------------------------")

# Create some "old" chains for demo
old_chains =
  for i <- 1..3 do
    chain = ChainFactory.create_sample_chain("Old Chain #{i}", 3, 0.85)
    # Note: In a real scenario, these would actually be old
    # For demo purposes, we're creating them now
    case CrucibleTrace.save(chain, storage_dir: storage_dir) do
      {:ok, _} -> chain
      {:error, _} -> nil
    end
  end
  |> Enum.reject(&is_nil/1)

IO.puts("Created #{length(old_chains)} chains for archiving demo")

# Archive chains older than 0 days (for demo - in reality you'd use a larger number)
case CrucibleTrace.Storage.archive(0, storage_dir: storage_dir) do
  {:ok, archived_ids} ->
    IO.puts("✓ Archived #{length(archived_ids)} chain(s)")

    Enum.each(archived_ids, fn id ->
      IO.puts("  - #{id}")
    end)

  {:error, reason} ->
    IO.puts("✗ Archive failed: #{inspect(reason)}")
end

# Example 8: Batch operations
IO.puts("\n\nExample 8: Batch operations on chains")
IO.puts("-----------------------------------------------")

case CrucibleTrace.list_chains(storage_dir: storage_dir) do
  {:ok, chains} ->
    IO.puts("Analyzing #{length(chains)} chains:\n")

    # Calculate aggregate statistics
    total_events = Enum.sum(Enum.map(chains, & &1.event_count))
    avg_events_per_chain = if length(chains) > 0, do: total_events / length(chains), else: 0

    IO.puts("Aggregate Statistics:")
    IO.puts("  Total chains: #{length(chains)}")
    IO.puts("  Total events across all chains: #{total_events}")
    IO.puts("  Average events per chain: #{Float.round(avg_events_per_chain, 1)}")

    # Find largest and smallest chains
    if length(chains) > 0 do
      largest = Enum.max_by(chains, & &1.event_count)
      smallest = Enum.min_by(chains, & &1.event_count)

      IO.puts("\n  Largest chain: #{largest.name} (#{largest.event_count} events)")
      IO.puts("  Smallest chain: #{smallest.name} (#{smallest.event_count} events)")
    end

    # Group chains by approximate size
    IO.puts("\nChain size distribution:")

    size_groups =
      Enum.group_by(chains, fn chain ->
        cond do
          chain.event_count <= 3 -> "Small (1-3 events)"
          chain.event_count <= 6 -> "Medium (4-6 events)"
          true -> "Large (7+ events)"
        end
      end)

    Enum.each(size_groups, fn {size, group_chains} ->
      IO.puts("  #{size}: #{length(group_chains)} chain(s)")
    end)

  {:error, reason} ->
    IO.puts("✗ Failed to list chains: #{inspect(reason)}")
end

# Example 9: Storage statistics
IO.puts("\n\nExample 9: Storage statistics")
IO.puts("-----------------------------------------------")

storage_dir = "example_traces"

case File.ls(storage_dir) do
  {:ok, files} ->
    json_files = Enum.filter(files, &String.ends_with?(&1, ".json"))
    html_files = Enum.filter(files, &String.ends_with?(&1, ".html"))

    other_files =
      Enum.filter(files, fn f ->
        not String.ends_with?(f, ".json") and not String.ends_with?(f, ".html")
      end)

    IO.puts("Storage Directory: #{storage_dir}")
    IO.puts("  Chain files (.json): #{length(json_files)}")
    IO.puts("  Visualization files (.html): #{length(html_files)}")
    IO.puts("  Other files: #{length(other_files)}")

    # Calculate total storage size
    total_size =
      Enum.reduce(files, 0, fn file, acc ->
        path = Path.join(storage_dir, file)

        case File.stat(path) do
          {:ok, %{size: size}} -> acc + size
          _ -> acc
        end
      end)

    IO.puts("  Total storage: #{Float.round(total_size / 1024, 2)} KB")

  {:error, :enoent} ->
    IO.puts("Storage directory doesn't exist yet")

  {:error, reason} ->
    IO.puts("✗ Failed to read storage directory: #{inspect(reason)}")
end

IO.puts("\n=== Storage and search examples completed ===\n")
