defmodule FaktoryWorker.Batch.BatchTest do
  use ExUnit.Case, async: true

  alias FaktoryWorker.{Batch, Random}

  describe "build_payload/4" do
    test "should create new faktory batch struct without parent_bid with both success and complete" do
      faktory_name = :"Test_#{Random.string()}"
      opts = [faktory_name: faktory_name]

      args = [
        on_complete: {DefaultWorker, %{hey: "you!"}, opts},
        on_success: {DefaultWorker, %{hey: "me!"}, opts}
      ]

      {:ok, batch} =
        Batch.build_payload(
          "test description",
          args
        )

      assert batch.complete.args == [%{hey: "you!"}]
      assert batch.success.args == [%{hey: "me!"}]
    end

    test "should create new faktory batch struct without parent_bid with success" do
      faktory_name = :"Test_#{Random.string()}"
      opts = [faktory_name: faktory_name]

      args = [
        on_success: {DefaultWorker, %{hey: "me!"}, opts}
      ]

      {:ok, batch} =
        Batch.build_payload(
          "test description",
          args
        )

      assert batch.success.args == [%{hey: "me!"}]
    end

    test "should create new faktory batch struct without parent_bid with complete" do
      faktory_name = :"Test_#{Random.string()}"
      opts = [faktory_name: faktory_name]

      args = [
        on_complete: {DefaultWorker, %{hey: "you!"}, opts}
      ]

      {:ok, batch} =
        Batch.build_payload(
          "test description",
          args
        )

      assert batch.complete.args == [%{hey: "you!"}]
    end

    test "should return error if no success and complete are specified" do
      batch =
        Batch.build_payload(
          "test description",
          []
        )

      assert batch == {:error, "Success or Complete must be defined"}
    end

    test "should create new faktory batch struct with parent_bid" do
      faktory_name = :"Test_#{Random.string()}"
      opts = [faktory_name: faktory_name]

      args = [
        on_complete: {DefaultWorker, %{hey: "you!"}, opts},
        on_success: {DefaultWorker, %{hey: "me!"}, opts},
        parent_id: "parent_bid"
      ]

      {:ok, batch} =
        Batch.build_payload(
          "test description",
          args
        )

      assert batch.complete.args == [%{hey: "you!"}]
      assert batch.success.args == [%{hey: "me!"}]
      assert batch.parent_bid == "parent_bid"
    end

    test "should create new faktory batch struct with parent_bid and success only" do
      faktory_name = :"Test_#{Random.string()}"
      opts = [faktory_name: faktory_name]

      args = [
        on_success: {DefaultWorker, %{hey: "me!"}, opts},
        parent_id: "parent_bid"
      ]

      {:ok, batch} =
        Batch.build_payload(
          "test description",
          args
        )

      assert batch.parent_bid == "parent_bid"
      assert batch.success.args == [%{hey: "me!"}]
    end

    test "should create new faktory batch struct with parent_bid and complete only" do
      faktory_name = :"Test_#{Random.string()}"
      opts = [faktory_name: faktory_name]

      args = [
        on_complete: {DefaultWorker, %{hey: "you!"}, opts},
        parent_id: "parent_bid"
      ]

      {:ok, batch} =
        Batch.build_payload(
          "test description",
          args
        )

      assert batch.parent_bid == "parent_bid"
      assert batch.complete.args == [%{hey: "you!"}]
    end
  end
end
