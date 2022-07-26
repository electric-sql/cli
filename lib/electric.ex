defmodule Electric do
  @moduledoc """
  Documentation for `Electric`.
  """
  use Bakeware.Script

  require Logger

  alias Electric.Commands
  alias Electric.Util

  @env Mix.env()

  @commands [
    accounts: Commands.Accounts,
    apps: Commands.Apps,
    auth: Commands.Auth,
    migrations: Commands.Migrations
  ]

  @project Mix.Project.config()

  defp spec do
    subspecs =
      @commands
      |> Enum.map(fn {k, v} -> {k, v.spec()} end)

    Optimus.new!(
      name: "electric",
      description: "Electric SQL CLI",
      version: @project[:version],
      about: "...",
      allow_unknown_args: false,
      parse_double_dash: true,
      subcommands: subspecs
    )
  end

  @impl Bakeware.Script
  def main(argv \\ []) do
    run(argv)
  end

  def run(argv \\ []) do
    argv
    |> parse()
    |> set_verbosity()
    |> route()

    0
  end

  def parse(argv \\ []) do
    spec()
    |> Optimus.parse!(argv, &halt/1)
  end

  defp route({[key, command], %{flags: %{help: true}}}) do
    spec()
    |> Optimus.parse!(["help", "#{key}", "#{command}"], &halt/1)
  end

  defp route({[key, command], options}) when is_atom(key) and is_atom(command) do
    @commands
    |> Keyword.get(key)
    |> apply(command, [options])
    |> handle_command()
  end

  defp route({[key], _}) do
    spec()
    |> Optimus.parse!(["help", "#{key}"], &halt/1)
  end

  defp route(_) do
    spec()
    |> Optimus.parse!(["--help"], &halt/1)
  end

  defp set_verbosity({_route, %{flags: flags}} = options) do
    Electric.Util.enable_verbose(Map.get(flags, :verbose, false))

    options
  end

  defp set_verbosity(options) do
    options
  end

  defp handle_command({:result, data}) when is_binary(data) do
    data
    |> IO.puts()

    {:result, data}
  end

  defp handle_command({:result, data}) do
    data
    |> Jason.encode_to_iodata!(pretty: true)
    |> IO.puts()

    {:result, data}
  end

  defp handle_command({:results, data}) do
    data
    |> Jason.encode_to_iodata!(pretty: true)
    |> IO.puts()

    {:results, data}
  end

  defp handle_command({:success, message}) when is_binary(message) do
    message
    |> Util.format_success()
    |> IO.puts()

    {:success, message}
  end

  defp handle_command({:error, error}) when is_binary(error) do
    handle_command({:error, [error]})
  end

  defp handle_command({:error, errors}) when is_list(errors) do
    spec()
    |> Optimus.Errors.format(errors)
    |> Enum.map(&IO.puts/1)

    halt({:error, errors})
  end

  defp halt(val) do
    case @env do
      :test -> {:halt, val}
      _ -> System.halt(0)
    end
  end

  @doc """
  Provide `use Electric, :command`.
  """
  defmacro __using__(:command) do
    Electric.Commands.command()
  end
end
