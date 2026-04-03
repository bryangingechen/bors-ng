defmodule BorsNG.Database.Context.Logging do
  @moduledoc """
  Keeps user-accessible records of what happens to their repository.
  """

  use BorsNG.Database.Context

  @spec log_cmd(Patch.t(), User.t(), BorsNG.Command.cmd()) :: :ok
  def log_cmd(patch, user, cmd) do
    %Log{patch: patch, user: user, cmd: cmd}
    |> Repo.insert!()
  end

  @spec most_recent_cmd(Patch.t()) :: {User.t(), BorsNG.Command.cmd()} | nil
  def most_recent_cmd(%Patch{id: id}) do
    from(l in Log)
    |> where([l], l.patch_id == ^id)
    |> order_by([l], desc: l.updated_at, desc: l.id)
    |> preload([l], :user)
    |> Repo.all()
    |> find_replayable_cmd()
  end

  # Walk the command history from most recent to oldest.
  # - Return {:activate} / {:try, _} immediately — these are replayable.
  # - Return nil on :deactivate / :try_cancel — the last intent was to stop;
  #   do not replay past a deliberate cancellation.
  # - Skip :retry and all other commands (ping, delegate, priority, etc.).
  defp find_replayable_cmd([]), do: nil

  defp find_replayable_cmd([%Log{cmd: cmd, user: user} | rest]) do
    cond do
      replayable?(cmd) -> {user, cmd}
      stop_search?(cmd) -> nil
      true -> find_replayable_cmd(rest)
    end
  end

  defp replayable?(:activate), do: true
  defp replayable?({:activate_by, _}), do: true
  defp replayable?({:try, _}), do: true
  defp replayable?(_), do: false

  defp stop_search?(:deactivate), do: true
  defp stop_search?(:try_cancel), do: true
  defp stop_search?(_), do: false
end
