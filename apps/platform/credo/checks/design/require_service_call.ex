defmodule Credo.Check.Design.RequireServiceCall do
  @moduledoc """
  Ensures Oban workers call Service modules via the standard `call` interface.

  Service modules should expose a single `call` function as their entry point.
  Workers must use this standard interface rather than calling arbitrary functions.

  ## Examples

      # Preferred - Worker calls Service.call/1
      defmodule MyApp.Workers.ProcessDataWorker do
        use Oban.Worker

        alias MyApp.Services.DataProcessorService

        @impl Oban.Worker
        def perform(%Oban.Job{args: %{"id" => id}}) do
          # GOOD: Uses standard call interface
          DataProcessorService.call(id)
        end
      end

      # NOT preferred - Worker calls arbitrary function
      defmodule MyApp.Workers.ProcessDataWorker do
        use Oban.Worker

        alias MyApp.Services.DataProcessorService

        @impl Oban.Worker
        def perform(%Oban.Job{args: %{"id" => id}}) do
          # BAD: Calls specific function instead of call
          DataProcessorService.process(id)
        end
      end

      # NOT preferred - Worker doesn't call Service
      defmodule MyApp.Workers.ProcessDataWorker do
        use Oban.Worker

        @impl Oban.Worker
        def perform(%Oban.Job{args: %{"id" => _id}}) do
          # BAD: No service call
          Logger.info("Would process data")
          :ok
        end
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Oban workers must call Service modules via the `call` function.

      Standard Service interface:
      - Services expose a single `call` function
      - Workers call `Service.call(args)`
      - Services handle all business logic internally

      Benefits:
      - Consistent interface across all services
      - Easy to understand (always call `call`)
      - Services can evolve internally without changing worker code
      - Clear separation of concerns

      Example:
          # In Worker
          MyService.call(instance_id)

          # In Service  
          def call(instance_id) do
            # All business logic here
          end
      """
    ]

  alias Credo.Code.Name

  @impl Credo.Check
  def run(%SourceFile{filename: file_path} = source_file, params) do
    # Only check files in workers/ directory
    if worker_file?(file_path) do
      ctx = Context.build(source_file, params, __MODULE__)

      # Parse the source file
      ast = Credo.Code.ast(source_file)

      # Check if perform function exists
      perform_info = find_perform_function(ast)

      if perform_info.found do
        # Check for Service.call pattern
        service_call_info = find_service_call_pattern(ast)

        cond do
          service_call_info.count == 0 ->
            # Worker doesn't call any Service - issue!
            [
              format_issue(
                ctx,
                message:
                  "Worker `perform/1` doesn't call any Service module. " <>
                    "Workers must delegate to Service modules via `Service.call(args)`.",
                trigger: "perform",
                line_no: perform_info.line || 1
              )
            ]

          not service_call_info.uses_call_function ->
            # Worker calls Service but not via call function
            [
              format_issue(
                ctx,
                message:
                  "Worker calls Service but not via standard `call` interface. " <>
                    "Use `Service.call(args)` instead of custom functions. " <>
                    "Found calls to: #{Enum.join(service_call_info.functions, ", ")}",
                trigger: "perform",
                line_no: perform_info.line || 1
              )
            ]

          true ->
            # Worker correctly uses Service.call - good!
            []
        end
      else
        # No perform function found - that's a different issue
        []
      end
    else
      []
    end
  end

  # Check if file is in workers directory
  defp worker_file?(path) do
    String.contains?(path, "/workers/") and String.ends_with?(path, ".ex")
  end

  # Find perform function and return info about it
  defp find_perform_function(ast) do
    {_, info} =
      Macro.prewalk(ast, %{found: false, line: nil}, fn
        {:def, meta, [{:perform, _, _} | _]} = node, acc ->
          {node, %{acc | found: true, line: meta[:line]}}

        {:defp, meta, [{:perform, _, _} | _]} = node, acc ->
          {node, %{acc | found: true, line: meta[:line]}}

        node, acc ->
          {node, acc}
      end)

    info
  end

  # Find Service module calls and check if they use call function
  defp find_service_call_pattern(ast) do
    {_, info} =
      Macro.prewalk(ast, %{count: 0, uses_call_function: false, functions: []}, fn
        {:., _meta, [{:__aliases__, _, module_parts}, func_name]} = node, acc
        when is_atom(func_name) ->
          module_name = module_parts |> Enum.join(".") |> Name.full()

          if String.ends_with?(module_name, "Service") do
            func_str = Atom.to_string(func_name)

            new_acc = %{
              acc
              | count: acc.count + 1,
                uses_call_function: acc.uses_call_function or func_str == "call",
                functions: [func_str | acc.functions]
            }

            {node, new_acc}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    info
  end
end
