defmodule Alchemist.TopicManagerTest do
  use ExUnit.Case
  use Properties, otp_app: :alchemist

  import Mock

  alias Alchemist.TopicManager
  alias SmartCity.TestDataGenerator, as: TDG

  @ingestion_id "ingest1"
  @dataset_id1 "dataset1"
  @dataset_id2 "dataset2"

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:output_topic_prefix, generic: true)

  test "returns the input and output topic names" do
    with_mocks([
      {Elsa, [create_type: fn(_, _) -> :doesnt_matter end, topic?: fn(_, _) -> true end]}
    ]) do
      ingestion = TDG.create_ingestion(%{id: @ingestion_id, targetDatasets: [@dataset_id1, @dataset_id2]})

      topics = TopicManager.setup_topics(ingestion)

      assert "#{input_topic_prefix()}-#{@ingestion_id}" == Map.get(topics, :input_topic)

      assert [
               "#{output_topic_prefix()}-#{@dataset_id1}",
               "#{output_topic_prefix()}-#{@dataset_id2}"
             ] == Map.get(topics, :output_topics)
    end
  end

  test "creates a topic with the provided input topic name" do
    with_mocks([
      {Elsa, [create_type: fn(_, _) -> :doesnt_matter end, topic?: fn(_, _) -> true end]}
    ]) do
      ingestion = TDG.create_ingestion(%{id: @ingestion_id})

      TopicManager.setup_topics(ingestion)

      assert_called Elsa.create_topic(elsa_brokers(), "#{input_topic_prefix()}-#{@ingestion_id}")
    end
  end

  test "verifies input and output topics are available" do

    with_mock(Elsa, [create_topic: fn(_, _) -> :doesnt_matter]) do
      :meck.new(Elsa)
      :meck.expect(Elsa, topic?, [_, "#{input_topic_prefix()}-#{@ingestion_id}"], :meck.seq([false, false, true]))
      :meck.expect(Elsa, topic?, [_, "#{output_topic_prefix()}-#{@dataset_id1}"], :meck.seq([false, false, true]))

      ingestion = TDG.create_ingestion(%{id: @ingestion_id, targetDatasets: [@dataset_id1]})

      TopicManager.setup_topics(ingestion)

      assert_called Elsa.topic?(elsa_brokers(), "#{input_topic_prefix()}-#{@ingestion_id}"), times(3)
      assert_called Elsa.topic?(elsa_brokers(), "#{output_topic_prefix()}-#{@dataset_id1}"), times(3)

      :meck.unload(Elsa)
    end
  end

  test "raises an error when it times out waiting for a topic" do
    with_mocks([
      {Elsa, [create_topic: fn(_, _) -> :doesnt_matter, topic?: fn(_, "#{input_topic_prefix()}-#{@ingestion_id}") -> true end, topic?: fn(_, "#{output_topic_prefix()}-#{@dataset_id1}") -> true end]}
    ]) do
      ingestion = TDG.create_ingestion(%{id: @ingestion_id, targetDatasets: [@dataset_id1]})

      assert_raise RuntimeError, "Timed out waiting for #{output_topic_prefix()}-#{@dataset_id1} to be available", fn ->
        TopicManager.setup_topics(ingestion)
      end
    end
  end

  test "should delete input and output topic when the topic names are provided" do
    with_mock(Elsa, [delete_topic: fn(_, _) -> :doesnt_matter]) do
      ingestion = TDG.create_ingestion(%{id: @ingestion_id, targetDatasets: [@dataset_id1, @dataset_id2]})
      TopicManager.delete_topics(ingestion)
      assert_called(Elsa.delete_topic(elsa_brokers(), "#{input_topic_prefix()}-#{@ingestion_id}"))
      assert_called(Elsa.delete_topic(elsa_brokers(), "#{output_topic_prefix()}-#{@dataset_id1}"))
      assert_called(Elsa.delete_topic(elsa_brokers(), "#{output_topic_prefix()}-#{@dataset_id2}"))
    end
  end
end
