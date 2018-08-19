defmodule SzivexHardware.Hwinterface do
  @moduledoc """
  Handles pin and interrupt setup, updates `SzivexHArdware.State` with pin changes when an interrupt occurs.
  Implements functions to turn the relay on or off.
  """
  use GenServer

  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: MyHW)
  end

  @doc """
  Turns the relay on the automation pHat on.
  """
  def relay_on() do
    GenServer.call(MyHW, :relay_on)
  end

  @doc """
  Turns the relay on the automation pHat off.
  """
  def relay_off() do
    GenServer.call(MyHW, :relay_off)
  end

  ## Server Callbacks

  @impl true
  def init(:ok) do
    {:ok, input1} = ElixirALE.GPIO.start_link(26, :input)
    {:ok, input2} = ElixirALE.GPIO.start_link(20, :input)
    {:ok, input3} = ElixirALE.GPIO.start_link(21, :input)
    {:ok, relay} = ElixirALE.GPIO.start_link(16, :output)
    ElixirALE.GPIO.write(relay, 0)
    IO.write("Starting SzivexHardware.Hwinterface, waiting 10sec for inputs to stabilise...")
    Process.sleep(10000)
    IO.puts("done.")
    ElixirALE.GPIO.set_int(input1, :both)
    ElixirALE.GPIO.set_int(input2, :both)
    ElixirALE.GPIO.set_int(input3, :both)
    IO.puts("SzivexHardware.Hwinterface started.")

    {:ok,
     %{
       :pids => %{:pump => input1, :emergency => input2, :level => input3, :relay => relay},
       :pin_state => %{:pump => :false, :emergency => :false, :level => :false, :relay => :false}
     }}
  end

  @impl true
  def handle_call(:relay_on, _from, state) do
    # TODO: use 'with' to check for succesful relay actuation
    pin_state =
      if (state[:pin_state][:pump] == :false) do
        IO.inspect((state[:pin_state][:pump] == :false), label: "ON Condition")
        IO.puts("Turning Relay on!")
        ElixirALE.GPIO.write(state[:pids][:relay], 1)
        pin_state = Map.replace!(state[:pin_state], :relay, true)
        SzivexHardware.State.update(pin_state)
        pin_state
      else
        IO.puts("Relay already on, nothing to do!")
        IO.inspect((state[:pin_state][:pump] == :false), label: "ON Condition")
        state[:pin_state]
      end
    IO.inspect({:reply, :ok, Map.replace!(state, :pin_state, pin_state)}, label: "Relay on")
  end

  @impl true
  def handle_call(:relay_off, _from, state) do
    # TODO: use 'with' to check for succesful relay actuation
    pin_state =
      if (state[:pin_state][:pump] == :true) do
        IO.inspect((state[:pin_state][:pump] == :true), label: "OFF Condition")
        IO.puts("Turning Relay off!")
        ElixirALE.GPIO.write(state[:pids][:relay], 0)
        pin_state = Map.replace!(state[:pin_state], :relay, false)
        SzivexHardware.State.update(pin_state)
        pin_state
      else
        IO.puts("Relay already off, nothing to do!")
        IO.inspect((state[:pin_state][:pump] == :true), label: "OFF Condition")
        state[:pin_state]
      end
    IO.inspect({:reply, :ok, Map.replace!(state, :pin_state, pin_state)}, label: "Relay off")
  end

  @impl true
  def handle_info({:gpio_interrupt, 26, :rising}, state) do
    # Pump stopped
    pin_state = Map.replace!(state[:pin_state], :pump, false)
    SzivexHardware.State.update(pin_state)
    IO.inspect({:noreply, Map.replace!(state, :pin_state, pin_state)}, label: "Pump stopped")
  end

  @impl true
  def handle_info({:gpio_interrupt, 26, :falling}, state) do
    # Pump started
    pin_state = Map.replace!(state[:pin_state], :pump, true)
    SzivexHardware.State.update(pin_state)
    IO.inspect({:noreply, Map.replace!(state, :pin_state, pin_state)}, label: "Pump started")
  end

  @impl true
  def handle_info({:gpio_interrupt, 20, :rising}, state) do
    # Emergency cleared
    pin_state = Map.replace!(state[:pin_state], :emergency, false)
    SzivexHardware.State.update(pin_state)
    IO.inspect({:noreply, Map.replace!(state, :pin_state, pin_state)}, label: "Emergency cleared")
  end

  @impl true
  def handle_info({:gpio_interrupt, 20, :falling}, state) do
    # Emergency triggered
    pin_state = Map.replace!(state[:pin_state], :emergency, true)
    SzivexHardware.State.update(pin_state)

    IO.inspect({:noreply, Map.replace!(state, :pin_state, pin_state)},
      label: "Emergency triggered"
    )
  end

  @impl true
  def handle_info({:gpio_interrupt, 21, :rising}, state) do
    # Level cleared
    pin_state = Map.replace!(state[:pin_state], :level, false)
    SzivexHardware.State.update(pin_state)
    IO.inspect({:noreply, Map.replace!(state, :pin_state, pin_state)}, label: "Level cleared")
  end

  @impl true
  def handle_info({:gpio_interrupt, 21, :falling}, state) do
    # Level triggered
    pin_state = Map.replace!(state[:pin_state], :level, true)
    SzivexHardware.State.update(pin_state)
    IO.inspect({:noreply, Map.replace!(state, :pin_state, pin_state)}, label: "Level triggered")
  end
end
