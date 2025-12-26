defmodule CrucibleTrace.StageTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.{Chain, Event, Stage}

  describe "trace_stage/3" do
    test "wraps stage function with start and complete events" do
      chain = Chain.new("Test")

      {updated_chain, result} =
        Stage.trace_stage(chain, "my-stage", fn ->
          {:ok, "result"}
        end)

      assert result == {:ok, "result"}
      assert length(updated_chain.events) == 2

      [start_event, complete_event] = updated_chain.events

      assert start_event.type == :stage_started
      assert start_event.stage_id == "my-stage"

      assert complete_event.type == :stage_completed
      assert complete_event.stage_id == "my-stage"
      assert is_integer(complete_event.metadata[:duration_us])
    end

    test "captures stage errors" do
      chain = Chain.new("Test")

      {updated_chain, result} =
        Stage.trace_stage(chain, "failing-stage", fn ->
          {:error, :something_failed}
        end)

      assert result == {:error, :something_failed}
      assert length(updated_chain.events) == 2

      complete_event = List.last(updated_chain.events)
      assert complete_event.type == :stage_completed
      assert complete_event.metadata[:status] == :error
    end

    test "captures stage exceptions" do
      chain = Chain.new("Test")

      {updated_chain, result} =
        Stage.trace_stage(chain, "exception-stage", fn ->
          raise "boom"
        end)

      assert {:error, _} = result
      assert length(updated_chain.events) == 2

      complete_event = List.last(updated_chain.events)
      assert complete_event.type == :stage_completed
      assert complete_event.metadata[:status] == :exception
      assert complete_event.metadata[:error] =~ "boom"
    end

    test "stage events have stage_id set" do
      chain = Chain.new("Test")

      {updated_chain, _result} =
        Stage.trace_stage(chain, "stage-with-id", fn ->
          :ok
        end)

      Enum.each(updated_chain.events, fn event ->
        assert event.stage_id == "stage-with-id"
      end)
    end

    test "records duration in microseconds" do
      chain = Chain.new("Test")

      {updated_chain, _result} =
        Stage.trace_stage(chain, "timed-stage", fn ->
          Process.sleep(10)
          :ok
        end)

      complete_event = List.last(updated_chain.events)
      # At least 10ms = 10_000 us
      assert complete_event.metadata[:duration_us] >= 10_000
    end
  end

  describe "trace_stage with options" do
    test "accepts experiment_id option" do
      chain = Chain.new("Test")

      {updated_chain, _result} =
        Stage.trace_stage(chain, "stage-1", fn -> :ok end, experiment_id: "exp-001")

      Enum.each(updated_chain.events, fn event ->
        assert event.experiment_id == "exp-001"
      end)
    end

    test "accepts parent_id option" do
      parent = Event.new(:hypothesis_formed, "Parent", "Reason")
      chain = Chain.new("Test") |> Chain.add_event(parent)

      {updated_chain, _result} =
        Stage.trace_stage(chain, "child-stage", fn -> :ok end, parent_id: parent.id)

      stage_events =
        Enum.filter(updated_chain.events, fn e ->
          e.type in [:stage_started, :stage_completed]
        end)

      Enum.each(stage_events, fn event ->
        assert event.parent_id == parent.id
      end)
    end

    test "accepts metadata option" do
      chain = Chain.new("Test")

      {updated_chain, _result} =
        Stage.trace_stage(chain, "stage-1", fn -> :ok end, metadata: %{custom: "value"})

      start_event = hd(updated_chain.events)
      assert start_event.metadata[:custom] == "value"
    end
  end

  describe "nested stages" do
    test "supports nested stage tracing" do
      chain = Chain.new("Test")

      {updated_chain, result} =
        Stage.trace_stage(chain, "outer-stage", fn ->
          inner_chain = Chain.new("Inner")

          {inner_updated, inner_result} =
            Stage.trace_stage(inner_chain, "inner-stage", fn ->
              {:ok, "inner result"}
            end)

          {{:ok, inner_result, inner_updated}, "outer result"}
        end)

      {{:ok, _, inner_chain}, outer_result} = result
      assert outer_result == "outer result"

      # Outer chain should have 2 events (start + complete)
      assert length(updated_chain.events) == 2

      # Inner chain should have 2 events (start + complete)
      assert length(inner_chain.events) == 2
    end
  end

  describe "stage event types" do
    test "stage_started is a valid event type" do
      event = Event.new(:stage_started, "Starting stage", "Stage execution begins")
      assert {:ok, _} = Event.validate(event)
    end

    test "stage_completed is a valid event type" do
      event = Event.new(:stage_completed, "Stage done", "Stage execution completed")
      assert {:ok, _} = Event.validate(event)
    end
  end
end
