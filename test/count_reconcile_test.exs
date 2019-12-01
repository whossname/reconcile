defmodule CountReconcileTest do
  use ExUnit.Case

  defmodule CountSub do
    use Reconcile, reconcile_key: :number, server: :count, topic: "*"

    def init_reconcile_value() do
      {:ok, 0}
    end

    def reconcile(new_value, old_value) do
      if new_value < old_value do
        {:error, "expect reconcile value to increase"}
      else
        records =
          (old_value + 1)..new_value
          |> Enum.to_list()
          |> Enum.map(&%{number: &1})

        {:ok, records}
      end
    end

    def handle_reconciled(numbers) do
      pid =
        Process.get()
        |> Keyword.fetch!(:"$ancestors")
        |> List.first()

      send(pid, numbers)
    end
  end

  test "it can count" do
    Phoenix.PubSub.PG2.start_link(:count, [])
    CountSub.start_link()

    # without reconcile
    Phoenix.PubSub.broadcast(:count, "*", {0, %{number: 1}})
    check_recieve([%{number: 1}])

    Phoenix.PubSub.broadcast(:count, "*", {1, %{number: 2}})
    check_recieve([%{number: 2}])

    # with reconcile
    Phoenix.PubSub.broadcast(:count, "*", {9, %{number: 10}})

    check_recieve([
      %{number: 3},
      %{number: 4},
      %{number: 5},
      %{number: 6},
      %{number: 7},
      %{number: 8},
      %{number: 9},
      %{number: 10}
    ])
  end

  defp check_recieve(val) do
    receive do
      ^val -> nil
      e -> throw("unexpected response: #{inspect(e)}")
    end
  end
end
