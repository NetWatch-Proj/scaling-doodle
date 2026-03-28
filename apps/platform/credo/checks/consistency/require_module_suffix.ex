defmodule Credo.Check.Consistency.RequireModuleSuffix do
  @moduledoc """
  Ensures modules in specific directories follow naming conventions by requiring
  specific suffixes.

  For example, workers should end with "Worker", services with "Service", etc.

  ## Examples

      # .credo.exs
      %{
        configs: [
          %{
            name: "default",
            checks: [
              {Credo.Check.Consistency.RequireModuleSuffix,
                patterns: [
                  {"lib/**/workers/*.ex", "Worker"},
                  {"lib/**/services/*.ex", "Service"},
                  {"lib/**/changes/*.ex", "Change"}
                ]}
            ]
          }
        ]
      }
  """

  use Credo.Check,
    base_priority: :high,
    category: :consistency,
    param_defaults: [
      patterns: [
        {"lib/**/workers/*.ex", "Worker"},
        {"lib/**/services/*.ex", "Service"},
        {"lib/**/changes/*.ex", "Change"}
      ]
    ],
    explanations: [
      check: """
      Modules in specific directories should follow naming conventions.

      For example:
      - Files in `workers/` directory should define modules ending with `Worker`
      - Files in `services/` directory should define modules ending with `Service`
      - Files in `changes/` directory should define modules ending with `Change`
      """,
      params: [
        patterns: "List of {file_pattern, required_suffix} tuples"
      ]
    ]

  alias Credo.Code.Name

  @impl Credo.Check
  def run(%SourceFile{filename: file_path} = source_file, params) do
    patterns = Params.get(params, :patterns, __MODULE__)

    # Check if this file matches any of our patterns
    case matching_pattern(file_path, patterns) do
      nil ->
        # File doesn't match any pattern, skip
        []

      {_pattern, required_suffix} ->
        ctx = Context.build(source_file, params, __MODULE__)

        result =
          Credo.Code.prewalk(
            source_file,
            &walk(&1, &2, required_suffix),
            ctx
          )

        result.issues
    end
  end

  # Private functions

  defp walk({:defmodule, meta, [{:__aliases__, _aliases_meta, names} | _rest]} = ast, ctx, required_suffix) do
    module_name =
      names
      |> Enum.filter(&String.Chars.impl_for/1)
      |> Enum.join(".")

    full_module_name = Name.full(module_name)

    if String.ends_with?(full_module_name, required_suffix) do
      {ast, ctx}
    else
      suggested_name = suggest_module_name(full_module_name, required_suffix)

      issue =
        format_issue(
          ctx,
          message:
            "Module `#{full_module_name}` should end with `#{required_suffix}`. " <>
              "Consider renaming it to `#{suggested_name}`.",
          trigger: full_module_name,
          line_no: meta[:line],
          column: meta[:column]
        )

      {ast, put_issue(ctx, issue)}
    end
  end

  defp walk(ast, ctx, _required_suffix) do
    {ast, ctx}
  end

  defp matching_pattern(file_path, patterns) do
    Enum.find(patterns, fn {pattern, _suffix} ->
      matches_glob?(file_path, pattern)
    end)
  end

  defp matches_glob?(path, pattern) do
    # Convert glob pattern to regex
    # ** matches any number of directories
    # * matches any characters except /
    regex_pattern =
      pattern
      |> String.replace(".", "\\.")
      |> String.replace("**", "<<<DOUBLESTAR>>>")
      |> String.replace("*", "[^/]*")
      |> String.replace("<<<DOUBLESTAR>>>", ".*")

    Regex.match?(~r/^#{regex_pattern}$/, path)
  end

  defp suggest_module_name(current_name, suffix) do
    if String.ends_with?(current_name, suffix) do
      current_name
    else
      current_name <> suffix
    end
  end
end
