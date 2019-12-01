defmodule Reconcile.Server do
  use GenServer

  def init({server, topic, module, key}) do
    Phoenix.PubSub.subscribe(server, topic)
    {:ok, reconcile_value} = apply(module, :init_reconcile_value, [])
    {:ok, {reconcile_value, module, key}}
  end

  # runtime
  defp set_state(record, module, key) do
    reconcile_value = Map.get(record, key)
    state = {reconcile_value, module, key}
    {:noreply, state}
  end

  def handle_info({reconcile_value, record}, {reconcile_value, module, key}) do
    apply(module, :handle_reconciled, [[record]])

    set_state(record, module, key)
  end

  def handle_info({new_reconcile_value, record}, {old_reconcile_value, module, key}) do
    apply(module, :reconcile, [new_reconcile_value, old_reconcile_value])
    |> case do
      {:ok, records} ->
        apply(module, :handle_reconciled, [records ++ [record]])
        set_state(record, module, key)

      {:error, reason} ->
        throw(reason)
    end
  end
end