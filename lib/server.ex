defmodule Reconcile.Server do
  use GenServer

  # start up
  def init({server, topic, module, key, opts}) do
    Phoenix.PubSub.subscribe(server, topic)
    {:ok, {module, key, opts}, {:continue, :continue}}
  end

  def handle_continue(:continue, {module, key, opts}) do
    reconcile_value = apply(module, :init_reconcile_value, [opts])
    state = %{reconcile_value: reconcile_value, module: module, key: key, opts: opts, acc: nil}
    {:noreply, state}
  end

  # runtime
  defp set_state(record, state) do
    reconcile_value = Map.get(record, state.key)
    state = Map.put(state, :reconcile_value, reconcile_value)
    {:noreply, state}
  end

  defp callback(records, state) do
    acc = apply(state.module, :callback, [state.acc, records, state.opts])
    Map.put(state, :acc, acc)
  end

  defp should_reconcile?(reconcile_value, state) do
    apply(state.module, :should_reconcile?, [reconcile_value, state.reconcile_value, state.opts])
  end

  def handle_info({reconcile_value, record}, %{reconcile_value: reconcile_value} = state) do
    state = callback([record], state)
    set_state(record, state)
  end

  def handle_info({reconcile_value, record}, state) do
    if should_reconcile?(reconcile_value, state) do
      reconcile_to = Map.get(record, state.key)

      apply(state.module, :reconcile, [
        reconcile_to,
        state.reconcile_value,
        state.opts
      ])
      |> case do
        {:ok, records} ->
          last = List.last(records)

          callback(records, state)

          if Map.get(last, state.key) != reconcile_to do
            send(self(), {reconcile_value, record})
            set_state(last, state)
          else
            set_state(record, state)
          end

        {:error, reason} ->
          throw(reason)
      end
    else
      {:noreply, state}
    end
  end
end
