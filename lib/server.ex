defmodule Reconcile.Server do
  use GenServer

  # start up
  def init({server, topic, module, key, opts}) do
    Phoenix.PubSub.subscribe(server, topic)
    {:ok, {module, key, opts}, {:continue, :continue}}
  end

  def handle_continue(:continue, {module, key, opts}) do
    reconcile_value = apply(module, :init_reconcile_value, [opts])
    state = {reconcile_value, module, key, opts}
    {:noreply, state}
  end

  # runtime
  defp set_state(record, module, key, opts) do
    reconcile_value = Map.get(record, key)
    state = {reconcile_value, module, key, opts}
    {:noreply, state}
  end

  def handle_info({reconcile_value, record}, {reconcile_value, module, key, opts}) do
    apply(module, :handle_reconciled, [[record], opts])

    set_state(record, module, key, opts)
  end

  def handle_info({new_reconcile_value, record}, {old_reconcile_value, module, key, opts}) do
    apply(module, :reconcile, [new_reconcile_value, old_reconcile_value, opts])
    |> case do
      {:ok, records} ->
        apply(module, :handle_reconciled, [records ++ [record], opts])
        set_state(record, module, key, opts)

      {:error, reason} ->
        throw(reason)
    end
  end
end
