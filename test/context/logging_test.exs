defmodule BorsNG.Database.Context.LoggingTest do
  use BorsNG.Database.ModelCase

  alias BorsNG.Database.Context.Logging
  alias BorsNG.Database.Installation
  alias BorsNG.Database.Patch
  alias BorsNG.Database.Project
  alias BorsNG.Database.User

  setup do
    installation =
      Repo.insert!(%Installation{
        installation_xref: 31
      })

    project =
      Repo.insert!(%Project{
        installation_id: installation.id,
        repo_xref: 13,
        name: "example/project"
      })

    user =
      Repo.insert!(%User{
        login: "lilac"
      })

    patch =
      Repo.insert!(%Patch{
        project: project
      })

    {:ok, project: project, user: user, patch: patch}
  end

  test "most recent command returns most recent activate", params do
    %{patch: patch, user: user} = params
    Logging.log_cmd(patch, user, :activate)
    Logging.log_cmd(patch, user, {:try, "--release"})
    user_id = user.id
    assert {%User{id: ^user_id}, {:try, "--release"}} = Logging.most_recent_cmd(patch)
  end

  test "most recent command returns nil when no commands logged", params do
    %{patch: patch} = params
    assert nil == Logging.most_recent_cmd(patch)
  end

  test "most recent command returns activate", params do
    %{patch: patch, user: user} = params
    Logging.log_cmd(patch, user, :activate)
    user_id = user.id
    assert {%User{id: ^user_id}, :activate} = Logging.most_recent_cmd(patch)
  end

  test "most recent command returns try", params do
    %{patch: patch, user: user} = params
    Logging.log_cmd(patch, user, {:try, ""})
    user_id = user.id
    assert {%User{id: ^user_id}, {:try, ""}} = Logging.most_recent_cmd(patch)
  end

  test "most recent command skips retry and finds activate", params do
    %{patch: patch, user: user} = params
    Logging.log_cmd(patch, user, :activate)
    Logging.log_cmd(patch, user, :retry)
    user_id = user.id
    assert {%User{id: ^user_id}, :activate} = Logging.most_recent_cmd(patch)
  end

  test "most recent command skips noise commands and finds activate", params do
    %{patch: patch, user: user} = params
    Logging.log_cmd(patch, user, :activate)
    Logging.log_cmd(patch, user, :ping)
    Logging.log_cmd(patch, user, :delegate)
    Logging.log_cmd(patch, user, {:set_priority, 1})
    user_id = user.id
    assert {%User{id: ^user_id}, :activate} = Logging.most_recent_cmd(patch)
  end

  test "most recent command returns nil when deactivate is most recent replayable boundary",
       params do
    %{patch: patch, user: user} = params
    Logging.log_cmd(patch, user, :activate)
    Logging.log_cmd(patch, user, :deactivate)
    assert nil == Logging.most_recent_cmd(patch)
  end

  test "most recent command returns nil when try_cancel is most recent replayable boundary",
       params do
    %{patch: patch, user: user} = params
    Logging.log_cmd(patch, user, {:try, ""})
    Logging.log_cmd(patch, user, :try_cancel)
    assert nil == Logging.most_recent_cmd(patch)
  end

  test "most recent command stops at deactivate even with noise after it", params do
    %{patch: patch, user: user} = params
    Logging.log_cmd(patch, user, :activate)
    Logging.log_cmd(patch, user, :deactivate)
    Logging.log_cmd(patch, user, :ping)
    assert nil == Logging.most_recent_cmd(patch)
  end
end
