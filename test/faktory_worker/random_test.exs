defmodule FaktoryWorker.RandomTest do
  use ExUnit.Case

  alias FaktoryWorker.Random

  describe "job_id/0" do
    test "should return a random hex" do
      hex1 = Random.job_id()
      hex2 = Random.job_id()

      assert hex1 != hex2
    end

    test "should return a lower case hex" do
      hex = Random.job_id()

      assert hex == String.downcase(hex)
    end

    test "should return a random hex based on 12 random bytes" do
      hex = Random.job_id()
      decoded = Base.decode16!(hex, case: :lower)

      assert byte_size(hex) == 24
      assert byte_size(decoded) == 12
    end
  end

  describe "worker_id/0" do
    test "should return a random hex" do
      hex1 = Random.worker_id()
      hex2 = Random.worker_id()

      assert hex1 != hex2
    end

    test "should return a lower case hex" do
      hex = Random.worker_id()

      assert hex == String.downcase(hex)
    end

    test "should return a random hex based on 12 random bytes" do
      hex = Random.worker_id()
      decoded = Base.decode16!(hex, case: :lower)

      assert byte_size(hex) == 16
      assert byte_size(decoded) == 8
    end
  end

  describe "string/0" do
    test "should return a random hex" do
      hex1 = Random.string()
      hex2 = Random.string()

      assert hex1 != hex2
    end
  end
end
