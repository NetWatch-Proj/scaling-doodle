defmodule Credo.Check.Design.RequireServiceInterface do
  @moduledoc """
  Ensures Service modules define a standard `call` function.

  Service modules should expose a single `call` function as their entry point.
  This provides a consistent interface across all services.
  """

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Service modules must define a `call` function as their entry point.

      Standard Service structure:
      - One public function: `call/1` or `call/0`
      - All business logic contained within or called from `call`
      - Private helper functions as needed
      - Returns `{:ok, result}` or `{:error, reason}`

      Benefits:
      - Consistent interface: always `Service.call(args)`
      - Encapsulation: internal structure can change without affecting callers
      - Testability: single entry point to test
      - Simplicity: clear contract between workers and services
      """
    ]

  @impl Credo.Check
  def run(%SourceFile{filename: file_path} = source_file, params) do
    # Only check files in services/ directory
    if service_file?(file_path) do
      ctx = Context.build(source_file, params, __MODULE__)

      # Parse the source file
      ast = Credo.Code.ast(source_file)

      # Check for call function
      call_info = find_call_function(ast)

      if call_info.found do
        # Service has call function - good!
        []
      else
        # Service doesn't have call function - issue!
        [
          format_issue(
            ctx,
            message:
              "Service module must define a `call` function as its entry point. " <>
                "Services should expose a single public interface: `call(args)`.",
            trigger: "defmodule",
            line_no: 1
          )
        ]
      end
    else
      []
    end
  end

  # Check if file is in services directory
  defp service_file?(path) do
    String.contains?(path, "/services/") and String.ends_with?(path, ".ex")
  end

  # Find call function in the AST
  defp find_call_function(ast) do
    {_, info} =
      Macro.prewalk(ast, %{found: false, line: nil}, fn
        # Public call function
        {:def, meta, [{:call, _, _args} | _]} = node, acc ->
          {node, %{acc | found: true, line: meta[:line]}}

        node, acc ->
          {node, acc}
      end)

    info
  end
end
