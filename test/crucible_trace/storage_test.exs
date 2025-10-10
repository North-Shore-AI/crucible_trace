defmodule CrucibleTrace.StorageTest do
  use ExUnit.Case
  alias CrucibleTrace.{Storage, Chain, Event}

  @test_storage_dir "test_causal_traces"

  setup do
    # Clean up test directory before each test
    File.rm_rf(@test_storage_dir)
    on_exit(fn -> File.rm_rf(@test_storage_dir) end)
    :ok
  end

  describe "save/2" do
    test "saves a chain to disk" do
      chain = Chain.new("Test Chain")
      event = Event.new(:hypothesis_formed, "Decision", "Reasoning")
      chain = Chain.add_event(chain, event)

      assert {:ok, file_path} = Storage.save(chain, storage_dir: @test_storage_dir)
      assert File.exists?(file_path)
      assert file_path =~ @test_storage_dir
    end

    test "creates storage directory if it doesn't exist" do
      chain = Chain.new("Test Chain")

      assert {:ok, _} = Storage.save(chain, storage_dir: @test_storage_dir)
      assert File.dir?(@test_storage_dir)
    end
  end

  describe "load/2" do
    test "loads a saved chain" do
      original = Chain.new("Test Chain", description: "Test description")
      event = Event.new(:hypothesis_formed, "Decision", "Reasoning")
      original = Chain.add_event(original, event)

      {:ok, _} = Storage.save(original, storage_dir: @test_storage_dir)

      assert {:ok, loaded} = Storage.load(original.id, storage_dir: @test_storage_dir)
      assert loaded.id == original.id
      assert loaded.name == original.name
      assert loaded.description == original.description
      assert length(loaded.events) == 1
    end

    test "returns error for non-existent chain" do
      assert {:error, _} = Storage.load("non-existent", storage_dir: @test_storage_dir)
    end
  end

  describe "list/1" do
    test "lists all chains in storage" do
      chain1 = Chain.new("Chain 1")
      chain2 = Chain.new("Chain 2")

      Storage.save(chain1, storage_dir: @test_storage_dir)
      Storage.save(chain2, storage_dir: @test_storage_dir)

      assert {:ok, chains} = Storage.list(storage_dir: @test_storage_dir)
      assert length(chains) == 2

      names = Enum.map(chains, & &1.name)
      assert "Chain 1" in names
      assert "Chain 2" in names
    end

    test "returns empty list when storage is empty" do
      assert {:ok, []} = Storage.list(storage_dir: @test_storage_dir)
    end

    test "includes chain metadata" do
      chain = Chain.new("Test Chain")
      event = Event.new(:hypothesis_formed, "Decision", "Reasoning")
      chain = Chain.add_event(chain, event)

      Storage.save(chain, storage_dir: @test_storage_dir)

      assert {:ok, [metadata]} = Storage.list(storage_dir: @test_storage_dir)
      assert metadata.id == chain.id
      assert metadata.name == chain.name
      assert metadata.event_count == 1
      assert %DateTime{} = metadata.created_at
    end
  end

  describe "delete/2" do
    test "deletes a chain from storage" do
      chain = Chain.new("Test Chain")
      {:ok, file_path} = Storage.save(chain, storage_dir: @test_storage_dir)

      assert File.exists?(file_path)
      assert :ok = Storage.delete(chain.id, storage_dir: @test_storage_dir)
      refute File.exists?(file_path)
    end

    test "returns error when file doesn't exist" do
      assert {:error, _} = Storage.delete("non-existent", storage_dir: @test_storage_dir)
    end
  end

  describe "search/2" do
    setup do
      # Create test chains with different attributes
      chain1 =
        Chain.new("User Authentication")
        |> Chain.add_event(Event.new(:hypothesis_formed, "D1", "R1"))

      chain2 =
        Chain.new("Data Processing")
        |> Chain.add_event(Event.new(:hypothesis_formed, "D2", "R2"))
        |> Chain.add_event(Event.new(:pattern_applied, "D3", "R3"))

      chain3 =
        Chain.new("User Authorization")
        |> Chain.add_event(Event.new(:hypothesis_formed, "D4", "R4"))
        |> Chain.add_event(Event.new(:pattern_applied, "D5", "R5"))
        |> Chain.add_event(Event.new(:constraint_evaluated, "D6", "R6"))

      Storage.save(chain1, storage_dir: @test_storage_dir)
      Storage.save(chain2, storage_dir: @test_storage_dir)
      Storage.save(chain3, storage_dir: @test_storage_dir)

      :ok
    end

    test "searches by name substring" do
      assert {:ok, results} =
               Storage.search(
                 [name_contains: "User"],
                 storage_dir: @test_storage_dir
               )

      assert length(results) == 2
      names = Enum.map(results, & &1.name)
      assert "User Authentication" in names
      assert "User Authorization" in names
    end

    test "searches by minimum event count" do
      assert {:ok, results} =
               Storage.search(
                 [min_events: 2],
                 storage_dir: @test_storage_dir
               )

      assert length(results) == 2
      assert Enum.all?(results, &(&1.event_count >= 2))
    end

    test "searches by maximum event count" do
      assert {:ok, results} =
               Storage.search(
                 [max_events: 1],
                 storage_dir: @test_storage_dir
               )

      assert length(results) == 1
      assert hd(results).event_count == 1
    end

    test "combines multiple search criteria" do
      assert {:ok, results} =
               Storage.search(
                 [name_contains: "User", min_events: 2],
                 storage_dir: @test_storage_dir
               )

      assert length(results) == 1
      assert hd(results).name == "User Authorization"
    end
  end

  describe "export/3" do
    test "exports chain to JSON format" do
      chain = Chain.new("Test Chain")
      event = Event.new(:hypothesis_formed, "Decision", "Reasoning")
      chain = Chain.add_event(chain, event)

      assert {:ok, json} = Storage.export(chain, :json)
      assert is_binary(json)
      assert json =~ "Test Chain"
      assert json =~ "Decision"
    end

    test "exports chain to Markdown format" do
      chain = Chain.new("Test Chain", description: "Description")
      event = Event.new(:hypothesis_formed, "Decision", "Reasoning", confidence: 0.9)
      chain = Chain.add_event(chain, event)

      assert {:ok, markdown} = Storage.export(chain, :markdown)
      assert markdown =~ "# Test Chain"
      assert markdown =~ "Description"
      assert markdown =~ "**Decision:** Decision"
      assert markdown =~ "**Reasoning:** Reasoning"
      assert markdown =~ "**Confidence:** 0.9"
    end

    test "exports chain to CSV format" do
      chain = Chain.new("Test Chain")
      event = Event.new(:hypothesis_formed, "Decision", "Reasoning")
      chain = Chain.add_event(chain, event)

      assert {:ok, csv} = Storage.export(chain, :csv)
      assert csv =~ "id,timestamp,type,decision"
      assert csv =~ "hypothesis_formed"
      assert csv =~ "Decision"
      assert csv =~ "Reasoning"
    end

    test "returns error for unsupported format" do
      chain = Chain.new("Test Chain")
      assert {:error, msg} = Storage.export(chain, :xml)
      assert msg =~ "Unsupported export format"
    end
  end
end
