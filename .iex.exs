# parallel
import FM.Factory

defmodule TT do
  def reload_emails do
    [Mix.Tasks.Fm.Emails, FMWeb.EmailView, FMWeb.Email, Mix.Tasks.Fm.Emails]
    |> Enum.each(&r/1)
  end

  def test_all_emails do
    Mix.Task.run("fm.emails")
  end
end
