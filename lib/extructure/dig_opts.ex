defmodule Extructure.DigOpts do
  @moduledoc false

  @type mode() :: :loose | :rigid
  @type key_type() :: :atom | :string

  @type t() ::
          %__MODULE__{
            mode: mode(),
            pair_var: boolean(),
            one_off: list(),
            key_type: key_type()
          }

  @enforce_keys [ :mode, :pair_var, :one_off, :key_type]
  defstruct @enforce_keys

  @doc "Instantiates DigOpts."
  @spec new( list()) :: t()
  def new( args) do
    struct!( __MODULE__, args)
  end

  @doc """
  Instructs interpreting sole variables as
  key pairs or leaving them as they are.
  """
  @spec pair_var( t(), boolean()) :: t()
  def pair_var( opts, pair_var?) do
    struct!( opts, pair_var: pair_var?)
  end

  @doc """
  Toggles structural matching mode from rigid to loose and vice versa.
  Raises KeyError if :mode not found in options.
  """
  @spec toggle_mode( t()) :: t()
  def toggle_mode( %{ mode: :loose} = opts), do: struct!( opts, mode: :rigid)
  def toggle_mode( %{ mode: :rigid} = opts), do: struct!( opts, mode: :loose)

  @doc """
  Toggles key type from atom to string or vice versa.
  """
  @spec toggle_key_type( t()) :: t()
  def toggle_key_type( %{ key_type: :atom} = opts), do: struct!( opts, key_type: :string)
  def toggle_key_type( %{ key_type: :string} = opts), do: struct!( opts, key_type: :atom)

  @doc "Sets one off options valid for just the next nested AST level."
  @spec one_off( t(), list()) :: t()
  def one_off( opts, one_off \\ []) do
    struct!( opts, one_off: one_off)
  end
end
