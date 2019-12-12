defmodule TimeReconcileTest do
  use ExUnit.Case

  defmodule TimeSub do
    use Reconcile, reconcile_key: :timestamp, server: :time

    def init_reconcile_value([]) do
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.add(-10)
    end

    defp build_times(times, last_time) do
      [prev | _] = times
      next = NaiveDateTime.add(prev, 1)
      times = [next | times]

      if next == last_time do
        times
      else
        build_times(times, last_time)
      end
    end

    def should_reconcile?(new_value, old_value, []) do
      NaiveDateTime.diff(new_value, old_value) > 0
    end

    def reconcile(new_value, old_value, []) do
      records =
        [old_value]
        |> build_times(new_value)
        |> Enum.map(&%{timestamp: &1})
        # must be ascending
        |> Enum.reverse()

      [_old_value | records] = records

      {:ok, records}
    end

    def callback(_, times, []) do
      pid =
        Process.get()
        |> Keyword.fetch!(:"$ancestors")
        |> List.first()

      send(pid, times)
    end
  end

  test "time reconcile" do
    topic = "*"
    Phoenix.PubSub.PG2.start_link(:time, [])
    TimeSub.start_link(topic, [])

    t0 =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)

    t1 = NaiveDateTime.add(t0, 1)
    t2 = NaiveDateTime.add(t0, 2)
    t3 = NaiveDateTime.add(t0, 3)
    t4 = NaiveDateTime.add(t0, 4)
    t5 = NaiveDateTime.add(t0, 5)

    # prep
    Phoenix.PubSub.broadcast(:time, topic, {t0, %{timestamp: t1}})
    check_recieve_min_length(9)

    # pass through
    Phoenix.PubSub.broadcast(:time, topic, {t1, %{timestamp: t2}})
    check_recieve([%{timestamp: t2}])

    # no reconcile
    Phoenix.PubSub.broadcast(:time, topic, {t1, %{timestamp: t2}})

    # reconcile
    Phoenix.PubSub.broadcast(:time, topic, {t4, %{timestamp: t5}})
    check_recieve([%{timestamp: t3}, %{timestamp: t4}, %{timestamp: t5}])
  end

  defp check_recieve_min_length(length) do
    receive do
      list -> assert Enum.count(list) > length
    end
  end

  defp check_recieve(val) do
    receive do
      ^val -> nil
      e -> throw("unexpected response: #{inspect(e)}")
    end
  end
end
