defmodule CountReconcileTest do
  use ExUnit.Case

  defmodule CountSub do
    use Reconcile, reconcile_key: :number, server: :count

    def init_reconcile_value(_), do: 0

    def should_reconcile?(new_value, old_value, _) do
      new_value > old_value
    end

    def reconcile(new_value, old_value, [count: :slow]) do
      records = [%{number: old_value + 1}]

      {:ok, records}
    end

    def reconcile(new_value, old_value, _) do
      records =
        (old_value + 1)..new_value
        |> Enum.to_list()
        |> Enum.map(&%{number: &1})

      {:ok, records}
    end

    def callback(_, numbers, _) do
      pid =
        Process.get()
        |> Keyword.fetch!(:"$ancestors")
        |> List.first()

      send(pid, numbers)
    end
  end

  test "it can count" do
    topic = "*"
    Phoenix.PubSub.PG2.start_link(:count, [])
    CountSub.start_link(topic)

    # without reconcile
    Phoenix.PubSub.broadcast(:count, topic, {0, %{number: 1}})
    check_recieve([%{number: 1}])

    Phoenix.PubSub.broadcast(:count, topic, {1, %{number: 2}})
    check_recieve([%{number: 2}])

    # no reconcile
    Phoenix.PubSub.broadcast(:count, topic, {0, %{number: 1}})

    # with reconcile
    Phoenix.PubSub.broadcast(:count, topic, {9, %{number: 10}})

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

    # many can count
    topic1 = "1"
    topic2 = "2"
    CountSub.start_link(topic1)
    CountSub.start_link(topic2)

    Phoenix.PubSub.broadcast(:count, topic1, {0, %{number: 1}})
    Phoenix.PubSub.broadcast(:count, topic2, {0, %{number: 1}})
    check_recieve([%{number: 1}])
    check_recieve([%{number: 1}])

    # can batch reconcile
    topic3 = "3"
    CountSub.start_link(topic3, count: :slow)
    Phoenix.PubSub.broadcast(:count, topic3, {2, %{number: 3}})
    check_recieve([%{number: 1}])
    check_recieve([%{number: 2}])
    check_recieve([%{number: 3}])
  end

  defp check_recieve(val) do
    receive do
      ^val -> nil
      e -> throw("unexpected response: #{inspect(e)}")
    end
  end
end
