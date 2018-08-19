defmodule SzivexHardware.State do
  @moduledoc """
  Module to keep track of the pump state.

  Updates are recieved through the `update/1` function, and the internal state is set accordingly.
  Some states timeout after a set time, this is not always an error.
  """
  use GenServer
  import SzivexHardware.Hwinterface, only: [relay_on: 0, relay_off: 0]

  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: MyState)
  end

  @doc """
  Update the control state with the pin states.
  This function accepts a map that has the following keys:
  :pump
  :level
  :emergency
  :relay

  The internal state is derived from the pin states and the current state.
  """
  def update(pin_state) when is_map(pin_state) do
    GenServer.cast(MyState, {:update, pin_state})
  end

  @impl true
  def init(_) do
    IO.puts("State started.")

    {:ok,
     %{
       :state => :idle,
       :state_since => Time.utc_now(),
       :prev_state => :idle,
       :reason => "Starting up."
     }}
  end

  @impl true
  def handle_cast({:update, pin_state}, state) do
    retval =
      case {pin_state, state} do
        {%{:pump => true, :emergency => false, :level => false, :relay => true},
         %{:state => :pump_started_running}} ->
          {:noreply,
           %{
             :state => :pump_running,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "Level clear after pump started. Pump running normally."
           }, 120_000}

        {%{:pump => true, :emergency => false, :level => true, :relay => true},
         %{:state => :pump_started}} ->
          {:noreply,
           %{
             :state => :pump_started_running,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "Pump running, waiting for level to clear."
           }, 30000}

        {%{:pump => false, :emergency => false, :level => true, :relay => true},
         %{:state => :level_triggered}} ->
          {:noreply,
           %{
             :state => :pump_started,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "Pump starting."
           }, 7000}

        {%{:pump => false, :emergency => false, :level => true, :relay => false},
         %{:state => :idle}} ->
          relay_on()

          {:noreply,
           %{
             :state => :level_triggered,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "Level triggered, switching relay on."
           }}

        {%{:pump => false, :emergency => false, :level => false, :relay => false}, _} ->
          {:noreply,
           %{
             :state => :idle,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "Idle."
           }, 86_400_000}

        {%{:emergency => true}, _} ->
          relay_off()

          {:noreply,
           %{
             :state => :error,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "CRITICAL: Emergency triggered"
           }}

        _ ->
          relay_off()

          {:noreply,
           %{
             :state => :error,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "CRITICAL: None of the happy path conditions matched."
           }}
      end

    IO.inspect(retval, label: "Retval")
    retval
  end

  @impl true
  def handle_info(:timeout, state) do
    retval =
      case state do
        %{:state => :pump_stopping} ->
          {:noreply,
           %{
             :state => :error,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "CRITICAL: Pump failed to stop after relay was turned off!"
           }}

        %{:state => :pump_started} ->
          {:noreply,
           %{
             :state => :error,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "CRITICAL: Pump failed to start after relay was turned on!"
           }}

        %{:state => :pump_started_running} ->
          {:noreply,
           %{
             :state => :error,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "CRITICAL: Level failed to clear after pump started!"
           }}

        %{:state => :pump_running} ->
          relay_off()

          {:noreply,
           %{
             :state => :pump_stopping,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "Stopping pump after normal timeout."
           }, 10000}

        %{:state => :idle} ->
          # Send daily heartbeat here
          {:noreply,
           %{
             :state => :idle,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "Daily heartbeat timeout for idle."
           }, 86_400_000}

        _ ->
          {:noreply,
           %{
             :state => :error,
             :state_since => Time.utc_now(),
             :prev_state => state[:state],
             :reason => "CRITICAL: unhandled timeout."
           }}
      end

    IO.inspect(retval, label: "Timeout")
    retval
  end
end
