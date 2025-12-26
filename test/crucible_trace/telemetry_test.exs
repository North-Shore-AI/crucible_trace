defmodule CrucibleTrace.TelemetryTest do
  use ExUnit.Case, async: false
  alias CrucibleTrace.{Event, Telemetry}

  # These tests need to be async: false because they attach/detach telemetry handlers

  setup do
    # Detach any existing handlers to start fresh
    Telemetry.detach_handlers()
    on_exit(fn -> Telemetry.detach_handlers() end)
    :ok
  end

  describe "attach_handlers/1" do
    test "attaches telemetry handlers" do
      assert :ok = Telemetry.attach_handlers()
    end

    test "attaches with options" do
      assert :ok = Telemetry.attach_handlers(prefix: [:my_app])
    end
  end

  describe "detach_handlers/0" do
    test "detaches telemetry handlers" do
      :ok = Telemetry.attach_handlers()
      assert :ok = Telemetry.detach_handlers()
    end

    test "detach is idempotent" do
      assert :ok = Telemetry.detach_handlers()
      assert :ok = Telemetry.detach_handlers()
    end
  end

  describe "emit_event_created/1" do
    test "emits telemetry for event creation" do
      test_pid = self()

      :telemetry.attach(
        "test-event-created",
        [:crucible_trace, :event, :created],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event_name, measurements, metadata})
        end,
        nil
      )

      event = Event.new(:hypothesis_formed, "Test", "Reason")
      Telemetry.emit_event_created(event)

      assert_receive {:telemetry, [:crucible_trace, :event, :created], measurements, metadata}
      assert is_map(measurements)
      assert metadata.event_id == event.id
      assert metadata.event_type == :hypothesis_formed

      :telemetry.detach("test-event-created")
    end
  end

  describe "emit_chain_event/3" do
    test "emits chain created event" do
      test_pid = self()

      :telemetry.attach(
        "test-chain-created",
        [:crucible_trace, :chain, :created],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event_name, measurements, metadata})
        end,
        nil
      )

      chain = CrucibleTrace.Chain.new("Test Chain")
      Telemetry.emit_chain_event(:created, chain)

      assert_receive {:telemetry, [:crucible_trace, :chain, :created], _measurements, metadata}
      assert metadata.chain_id == chain.id
      assert metadata.chain_name == "Test Chain"

      :telemetry.detach("test-chain-created")
    end

    test "emits chain saved event with metadata" do
      test_pid = self()

      :telemetry.attach(
        "test-chain-saved",
        [:crucible_trace, :chain, :saved],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event_name, measurements, metadata})
        end,
        nil
      )

      chain = CrucibleTrace.Chain.new("Test Chain")
      Telemetry.emit_chain_event(:saved, chain, %{path: "/tmp/test.json"})

      assert_receive {:telemetry, [:crucible_trace, :chain, :saved], _measurements, metadata}
      assert metadata.path == "/tmp/test.json"

      :telemetry.detach("test-chain-saved")
    end

    test "emits chain loaded event" do
      test_pid = self()

      :telemetry.attach(
        "test-chain-loaded",
        [:crucible_trace, :chain, :loaded],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event_name, measurements, metadata})
        end,
        nil
      )

      chain = CrucibleTrace.Chain.new("Test Chain")
      Telemetry.emit_chain_event(:loaded, chain)

      assert_receive {:telemetry, [:crucible_trace, :chain, :loaded], _measurements, metadata}
      assert metadata.chain_id == chain.id

      :telemetry.detach("test-chain-loaded")
    end
  end

  describe "handle_pipeline_event/4" do
    test "converts pipeline stage start event to trace event" do
      event_name = [:crucible, :pipeline, :stage, :start]
      measurements = %{system_time: System.system_time()}
      metadata = %{stage_id: "training", experiment_id: "exp-001"}
      config = %{}

      result = Telemetry.handle_pipeline_event(event_name, measurements, metadata, config)

      assert %Event{} = result
      assert result.metadata[:stage_id] == "training"
    end

    test "converts pipeline stage stop event to trace event" do
      event_name = [:crucible, :pipeline, :stage, :stop]
      measurements = %{duration: 1_000_000, system_time: System.system_time()}
      metadata = %{stage_id: "training", experiment_id: "exp-001"}
      config = %{}

      result = Telemetry.handle_pipeline_event(event_name, measurements, metadata, config)

      assert %Event{} = result
      assert result.metadata[:duration] == 1_000_000
    end

    test "handles unknown pipeline events gracefully" do
      event_name = [:unknown, :event]
      measurements = %{}
      metadata = %{}
      config = %{}

      result = Telemetry.handle_pipeline_event(event_name, measurements, metadata, config)

      assert result == nil
    end
  end

  describe "measurements" do
    test "emit_event_created includes timestamp in measurements" do
      test_pid = self()

      :telemetry.attach(
        "test-measurements",
        [:crucible_trace, :event, :created],
        fn _event_name, measurements, _metadata, _config ->
          send(test_pid, {:measurements, measurements})
        end,
        nil
      )

      event = Event.new(:hypothesis_formed, "Test", "Reason")
      Telemetry.emit_event_created(event)

      assert_receive {:measurements, measurements}
      assert Map.has_key?(measurements, :system_time)

      :telemetry.detach("test-measurements")
    end
  end
end
