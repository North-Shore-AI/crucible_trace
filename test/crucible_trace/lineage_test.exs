defmodule CrucibleTrace.LineageTest do
  use ExUnit.Case, async: true

  alias CrucibleTrace.{Chain, Event, Lineage}

  @test_storage_dir Path.join(System.tmp_dir!(), "crucible_trace_lineage_test")

  setup do
    File.rm_rf(@test_storage_dir)
    on_exit(fn -> File.rm_rf(@test_storage_dir) end)
    :ok
  end

  describe "chain_to_artifact/2" do
    test "builds a lineage artifact with embedded chain data by default" do
      chain =
        Chain.new("Lineage Chain")
        |> Chain.add_event(Event.new(:hypothesis_formed, "Decision", "Reasoning"))

      assert {:ok, artifact} = Lineage.chain_to_artifact(chain)

      assert Map.get(artifact, :type) == "crucible_trace.chain"
      assert Map.get(artifact, :mime_type) == "application/json"
      assert is_binary(Map.get(artifact, :id))

      metadata = get_in(artifact, [:metadata, :crucible_trace])
      assert metadata[:chain_id] == chain.id
      assert metadata[:name] == chain.name
      assert metadata[:event_count] == 1
      assert metadata[:embedded] == true
      assert is_map(metadata[:chain])

      checksum = Map.get(artifact, :checksum)
      size_bytes = Map.get(artifact, :size_bytes)
      assert is_binary(checksum)
      assert String.starts_with?(checksum, "sha256:")
      assert is_integer(size_bytes)
      assert size_bytes > 0
    end

    test "omits embedded chain data when include_chain is false" do
      chain = Chain.new("No Embed Chain")

      assert {:ok, artifact} = Lineage.chain_to_artifact(chain, include_chain: false)

      metadata = get_in(artifact, [:metadata, :crucible_trace])
      assert metadata[:embedded] == false
      refute Map.has_key?(metadata, :chain)
    end

    test "respects provided uri without persisting" do
      chain = Chain.new("URI Chain")

      assert {:ok, artifact} =
               Lineage.chain_to_artifact(chain, uri: "s3://traces/chain.json")

      assert Map.get(artifact, :uri) == "s3://traces/chain.json"
    end

    test "persists chain when save is true" do
      chain = Chain.new("Saved Chain")

      assert {:ok, artifact} =
               Lineage.chain_to_artifact(chain,
                 save: true,
                 storage_dir: @test_storage_dir
               )

      uri = Map.get(artifact, :uri)
      assert is_binary(uri)
      assert File.exists?(uri)
    end
  end

  describe "chain_to_artifact_ref/2" do
    test "builds a lineage artifact ref for a chain" do
      chain = Chain.new("Ref Chain")

      assert {:ok, ref} = Lineage.chain_to_artifact_ref(chain, uri: "file://trace.json")

      assert Map.get(ref, :type) == "crucible_trace.chain"
      assert Map.get(ref, :uri) == "file://trace.json"

      artifact_id = Map.get(ref, :artifact_id)
      assert is_binary(artifact_id)
      assert String.length(artifact_id) == 36
    end
  end
end
