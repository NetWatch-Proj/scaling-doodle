defmodule Credo.Check.Refactor.NoWorkerBusinessLogic do
  @moduledoc """
  Ensures Oban workers don't contain business logic and only delegate to services.

  Workers should be thin wrappers that:
  1. Extract arguments from the job
  2. Call a Service module
  3. Return the result

  Business logic (Ash actions, Helm calls, complex conditionals) should be in Service modules.

  ## Examples

      # Preferred - Worker only delegates
      defmodule MyApp.Workers.ProcessDataWorker do
        use Oban.Worker

        alias MyApp.Services.DataProcessorService

        @impl Oban.Worker
        def perform(%Oban.Job{args: %{"id" => id}}) do
          DataProcessorService.process(id)
        end
      end

      # NOT preferred - Worker contains business logic
      defmodule MyApp.Workers.ProcessDataWorker do
        use Oban.Worker

        alias MyApp.Repo

        @impl Oban.Worker
        def perform(%Oban.Job{args: %{"id" => id}}) do
          # BAD: Business logic in worker
          record = Repo.get!(MyApp.Record, id)
          
          if record.status == "pending" do
            # More business logic...
            {:ok, result} = ExternalAPI.call(record.data)
            Repo.update!(change(record, status: "processed"))
          end
        end
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :refactor,
    param_defaults: [
      # Max lines of code in perform/1 (should be short)
      max_perform_lines: 15
    ],
    explanations: [
      check: """
      Oban workers should be thin wrappers that delegate to service modules.

      Workers should only:
      1. Extract arguments from the job
      2. Call a Service module function
      3. Return the result

      Business logic (database operations, API calls, complex logic) belongs in Service modules.

      This separation makes workers:
      - Easier to test (no need for job infrastructure)
      - Reusable from other contexts (not just from Oban)
      - Maintainable (business logic is centralized)
      """,
      params: [
        max_perform_lines: "Maximum lines allowed in perform/1 function"
      ]
    ]

  alias Credo.Code.Name

  @impl Credo.Check
  def run(%SourceFile{filename: file_path} = source_file, params) do
    # Only check files in workers/ directory
    if worker_file?(file_path) do
      ctx = Context.build(source_file, params, __MODULE__)
      max_lines = Params.get(params, :max_perform_lines, __MODULE__)

      result =
        Credo.Code.prewalk(
          source_file,
          &walk(&1, &2, max_lines),
          ctx
        )

      result.issues
    else
      []
    end
  end

  # Check if file is in workers directory
  defp worker_file?(path) do
    String.contains?(path, "/workers/") and String.ends_with?(path, ".ex")
  end

  # Walk the AST looking for issues in perform/1
  defp walk({:def, meta, [{:perform, _, _args} | body]} = ast, ctx, max_lines) do
    issues = check_perform_function(body, meta, max_lines, ctx)

    # Add issues one at a time using put_issue
    ctx_with_issues =
      Enum.reduce(issues, ctx, fn issue, acc_ctx ->
        %{acc_ctx | issues: [issue | acc_ctx.issues]}
      end)

    {ast, ctx_with_issues}
  end

  defp walk({:defp, meta, [{:perform, _, _args} | body]} = ast, ctx, max_lines) do
    issues = check_perform_function(body, meta, max_lines, ctx)

    ctx_with_issues =
      Enum.reduce(issues, ctx, fn issue, acc_ctx ->
        %{acc_ctx | issues: [issue | acc_ctx.issues]}
      end)

    {ast, ctx_with_issues}
  end

  # Check for calls to business logic modules
  defp walk({:., meta, [{:__aliases__, _, module_parts}, func_name]} = ast, ctx, _max_lines)
       when is_atom(func_name) do
    module_name = module_parts |> Enum.join(".") |> Name.full()
    full_call = "#{module_name}.#{func_name}"

    if business_logic_module?(module_name) do
      issue =
        format_issue(
          ctx,
          message:
            "Worker calls `#{full_call}` directly. Workers should only call Service modules.",
          trigger: full_call,
          line_no: meta[:line],
          column: meta[:column]
        )

      {ast, put_issue(ctx, issue)}
    else
      {ast, ctx}
    end
  end

  # Check for complex control flow
  defp walk({:case, meta, _} = ast, ctx, _max_lines) do
    issue =
      format_issue(
        ctx,
        message:
          "Worker uses `case` in `perform/1`. Workers should be simple delegators. Move logic to a Service module.",
        trigger: "case",
        line_no: meta[:line],
        column: meta[:column]
      )

    {ast, put_issue(ctx, issue)}
  end

  defp walk({:cond, meta, _} = ast, ctx, _max_lines) do
    issue =
      format_issue(
        ctx,
        message:
          "Worker uses `cond` in `perform/1`. Workers should be simple delegators. Move logic to a Service module.",
        trigger: "cond",
        line_no: meta[:line],
        column: meta[:column]
      )

    {ast, put_issue(ctx, issue)}
  end

  defp walk({:with, meta, _} = ast, ctx, _max_lines) do
    issue =
      format_issue(
        ctx,
        message:
          "Worker uses `with` in `perform/1`. Workers should be simple delegators. Move logic to a Service module.",
        trigger: "with",
        line_no: meta[:line],
        column: meta[:column]
      )

    {ast, put_issue(ctx, issue)}
  end

  # Check for if/else (if with else branch)
  defp walk({:if, meta, [_condition, [do: _, else: _]]} = ast, ctx, _max_lines) do
    issue =
      format_issue(
        ctx,
        message:
          "Worker uses `if/else` in `perform/1`. Workers should be simple delegators. Move logic to a Service module.",
        trigger: "if",
        line_no: meta[:line],
        column: meta[:column]
      )

    {ast, put_issue(ctx, issue)}
  end

  defp walk(ast, ctx, _max_lines) do
    {ast, ctx}
  end

  # Check the perform/1 function for complexity
  defp check_perform_function(body, meta, max_lines, ctx) do
    issues = []

    # Check function length
    lines = count_lines(body)

    issues =
      if lines > max_lines do
        issue =
          format_issue(
            ctx,
            message:
              "Worker `perform/1` is #{lines} lines (max: #{max_lines}). Consider extracting logic to a Service module.",
            trigger: "perform",
            line_no: meta[:line],
            column: meta[:column]
          )

        [issue | issues]
      else
        issues
      end

    issues
  end

  # Count lines in function body
  defp count_lines(body) do
    body
    |> Macro.to_string()
    |> String.split("\n")
    |> length()
  end

  # Check if module is a business logic module (not a Service module)
  defp business_logic_module?(module_name) do
    # Business logic modules that workers shouldn't call directly
    business_modules = [
      "Ash.",
      "Repo",
      "Helm.",
      "Kubernetes.",
      "Oban",
      "HTTP",
      "Req",
      "Tesla",
      "Finch"
    ]

    Enum.any?(business_modules, fn pattern ->
      String.contains?(module_name, pattern)
    end) and not String.contains?(module_name, "Service")
  end
end
