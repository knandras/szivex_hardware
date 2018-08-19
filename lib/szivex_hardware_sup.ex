defmodule SzivexHardware.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      %{
        id: SzivexHardware.Hwinterface,
        start: {SzivexHardware.Hwinterface, :start_link, []}
      },
      %{
        id: SzivexHardware.State,
        start: {SzivexHardware.State, :start_link, []}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
