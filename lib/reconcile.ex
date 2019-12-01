defmodule Reconcile do
  @callback initial_reconcile_value() ::
              {:ok, state :: term()}
              | {:ok, state :: term(), timeout() | :hibernate | {:continue, term()}}
              | :ignore
              | {:stop, reason :: any()}

  @callback reconcile(reconcile_value :: any(), reconcile_value :: any()) ::
              {:error, String.t()} | {:ok, records :: list()}

  @callback handle_reconciled(records :: list()) :: any()

  defmacro __using__(reconcile_key: key, server: server, topic: topic) do
    quote do
      def process_id(server, topic), do: {__MODULE__, server, topic}

      defp via_tuple(server, topic) do
        {:via, :gproc, {:n, :l, process_id(server, topic)}}
      end

      # start up
      def start_link() do
        server = unquote(server)
        topic = unquote(topic)
        key = unquote(key)

        GenServer.start_link(
          Reconcile.Server,
          {server, topic, __MODULE__, key},
          name: via_tuple(server, topic)
        )
      end
    end
  end
end
