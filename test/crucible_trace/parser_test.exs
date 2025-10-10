defmodule CrucibleTrace.ParserTest do
  use ExUnit.Case, async: true
  alias CrucibleTrace.{Parser, Chain}

  describe "parse/1" do
    test "parses single event from text" do
      text = """
      <event type="hypothesis_formed">
        <decision>Use GenServer</decision>
        <reasoning>Need state management</reasoning>
        <confidence>0.9</confidence>
      </event>
      """

      assert {:ok, [event]} = Parser.parse(text)
      assert event.type == :hypothesis_formed
      assert event.decision == "Use GenServer"
      assert event.reasoning == "Need state management"
      assert event.confidence == 0.9
    end

    test "parses multiple events" do
      text = """
      <event type="hypothesis_formed">
        <decision>Decision 1</decision>
        <reasoning>Reasoning 1</reasoning>
      </event>

      <event type="pattern_applied">
        <decision>Decision 2</decision>
        <reasoning>Reasoning 2</reasoning>
      </event>
      """

      assert {:ok, events} = Parser.parse(text)
      assert length(events) == 2
      assert Enum.at(events, 0).type == :hypothesis_formed
      assert Enum.at(events, 1).type == :pattern_applied
    end

    test "parses event with alternatives" do
      text = """
      <event type="alternative_rejected">
        <decision>Use map</decision>
        <alternatives>struct, keyword list, tuple</alternatives>
        <reasoning>Simplicity</reasoning>
      </event>
      """

      assert {:ok, [event]} = Parser.parse(text)
      assert event.alternatives == ["struct", "keyword list", "tuple"]
    end

    test "parses event with all optional fields" do
      text = """
      <event type="constraint_evaluated">
        <decision>Use async/await</decision>
        <alternatives>callbacks, promises</alternatives>
        <reasoning>Better readability</reasoning>
        <confidence>0.85</confidence>
        <code_section>async_handler</code_section>
        <spec_reference>Section 4.2</spec_reference>
      </event>
      """

      assert {:ok, [event]} = Parser.parse(text)
      assert event.confidence == 0.85
      assert event.code_section == "async_handler"
      assert event.spec_reference == "Section 4.2"
    end

    test "handles missing optional fields with defaults" do
      text = """
      <event type="hypothesis_formed">
        <decision>Decision</decision>
        <reasoning>Reasoning</reasoning>
      </event>
      """

      assert {:ok, [event]} = Parser.parse(text)
      assert event.alternatives == []
      assert event.confidence == 1.0
      assert event.code_section == ""
      assert event.spec_reference == ""
    end
  end

  describe "parse_to_chain/3" do
    test "parses events into a chain" do
      text = """
      <event type="hypothesis_formed">
        <decision>Decision</decision>
        <reasoning>Reasoning</reasoning>
      </event>
      """

      assert {:ok, chain} = Parser.parse_to_chain(text, "Test Chain")
      assert %Chain{} = chain
      assert chain.name == "Test Chain"
      assert length(chain.events) == 1
    end

    test "includes chain options" do
      text = """
      <event type="hypothesis_formed">
        <decision>Decision</decision>
        <reasoning>Reasoning</reasoning>
      </event>
      """

      assert {:ok, chain} =
               Parser.parse_to_chain(text, "Test Chain",
                 description: "Test description",
                 metadata: %{test: true}
               )

      assert chain.description == "Test description"
      assert chain.metadata == %{test: true}
    end
  end

  describe "extract_code/1" do
    test "extracts code from code tags" do
      text = """
      <event type="hypothesis_formed">
        <decision>Decision</decision>
        <reasoning>Reasoning</reasoning>
      </event>

      <code>
      defmodule MyModule do
        def hello, do: :world
      end
      </code>
      """

      code = Parser.extract_code(text)
      assert code =~ "defmodule MyModule"
      assert code =~ "def hello"
      refute code =~ "<event"
    end

    test "removes event tags but keeps other content" do
      text = """
      Some text before
      <event type="hypothesis_formed">
        <decision>Decision</decision>
        <reasoning>Reasoning</reasoning>
      </event>
      Some text after
      """

      result = Parser.extract_code(text)
      assert result =~ "Some text before"
      assert result =~ "Some text after"
      refute result =~ "<event"
    end
  end

  describe "build_causal_prompt/1" do
    test "wraps base spec with event instructions" do
      base_spec = "Implement a user authentication module"
      prompt = Parser.build_causal_prompt(base_spec)

      assert prompt =~ base_spec
      assert prompt =~ "For each significant decision"
      assert prompt =~ "<event type="
      assert prompt =~ "hypothesis_formed"
      assert prompt =~ "alternative_rejected"
      assert prompt =~ "<decision>"
      assert prompt =~ "<code>"
    end
  end

  describe "validate_events/1" do
    test "validates correctly formatted events" do
      text = """
      <event type="hypothesis_formed">
        <decision>Decision</decision>
        <reasoning>Reasoning</reasoning>
      </event>
      """

      assert {:ok, 1} = Parser.validate_events(text)
    end

    test "detects mismatched event tags" do
      text = """
      <event type="hypothesis_formed">
        <decision>Decision</decision>
        <reasoning>Reasoning</reasoning>
      """

      assert {:error, issues} = Parser.validate_events(text)
      assert Enum.any?(issues, &String.contains?(&1, "Mismatched"))
    end

    test "detects missing decision tag" do
      text = """
      <event type="hypothesis_formed">
        <reasoning>Reasoning</reasoning>
      </event>
      """

      assert {:error, issues} = Parser.validate_events(text)
      assert Enum.any?(issues, &String.contains?(&1, "missing <decision>"))
    end

    test "detects missing reasoning tag" do
      text = """
      <event type="hypothesis_formed">
        <decision>Decision</decision>
      </event>
      """

      assert {:error, issues} = Parser.validate_events(text)
      assert Enum.any?(issues, &String.contains?(&1, "missing <reasoning>"))
    end

    test "validates multiple events" do
      text = """
      <event type="hypothesis_formed">
        <decision>Decision 1</decision>
        <reasoning>Reasoning 1</reasoning>
      </event>

      <event type="pattern_applied">
        <decision>Decision 2</decision>
        <reasoning>Reasoning 2</reasoning>
      </event>
      """

      assert {:ok, 2} = Parser.validate_events(text)
    end
  end

  describe "extract_metadata/1" do
    test "extracts model info from comments" do
      text = """
      <!-- model: gpt-4 -->
      <event type="hypothesis_formed">
        <decision>Decision</decision>
        <reasoning>Reasoning</reasoning>
      </event>
      """

      metadata = Parser.extract_metadata(text)
      assert Map.get(metadata, :model) == "gpt-4"
    end

    test "extracts timestamp from comments" do
      text = """
      <!-- timestamp: 2024-01-15T10:30:00Z -->
      <event type="hypothesis_formed">
        <decision>Decision</decision>
        <reasoning>Reasoning</reasoning>
      </event>
      """

      metadata = Parser.extract_metadata(text)
      assert Map.get(metadata, :timestamp) == "2024-01-15T10:30:00Z"
    end

    test "returns empty map when no metadata present" do
      text = """
      <event type="hypothesis_formed">
        <decision>Decision</decision>
        <reasoning>Reasoning</reasoning>
      </event>
      """

      metadata = Parser.extract_metadata(text)
      assert metadata == %{}
    end
  end

  describe "split_events_and_code/1" do
    test "splits events from code" do
      text = """
      <event type="hypothesis_formed">
        <decision>Decision</decision>
        <reasoning>Reasoning</reasoning>
      </event>

      <code>
      defmodule MyModule do
        def hello, do: :world
      end
      </code>
      """

      {events_text, code} = Parser.split_events_and_code(text)

      assert events_text =~ "<event"
      assert events_text =~ "<decision>"
      refute events_text =~ "<code>"

      assert code =~ "defmodule MyModule"
      assert code =~ "def hello"
    end

    test "handles text without code tags" do
      text = """
      <event type="hypothesis_formed">
        <decision>Decision</decision>
        <reasoning>Reasoning</reasoning>
      </event>
      """

      {events_text, code} = Parser.split_events_and_code(text)

      assert events_text == text
      assert code == ""
    end
  end
end
