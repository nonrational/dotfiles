# Fish prompt research for the issue #29 spike

**Summary**

1. **Recommendation: spike with starship.** It is the only candidate that runs in both bash and fish from one `~/.config/starship.toml`, which matches a bash login shell with fish as the interactive shell ([starship.rs](https://starship.rs/), [config](https://starship.rs/config/)).
2. The config is a plain TOML file, so it fits the symlink-only deploy with no extra mechanism.
3. Tide and hydro are fish-only and async. Tide keeps config in universal variables, so reproducing it needs a `tide configure --auto` step that `deploy.sh` does not model ([tide wiki](https://github.com/IlanCosman/tide/wiki/Syncing-your-tide-config-in-your-dotfiles)).
4. Keep fish's built-in `fish_git_prompt` as the zero-dependency fallback if starship's synchronous git cost proves too high on large repos.
5. No prompt ships an agent-aware segment. `CLAUDECODE` marks subprocesses Claude Code spawns, not the user's outer shell, so it cannot show "an agent is running" in that outer prompt ([env vars](https://code.claude.com/docs/en/env-vars)). Cost and context data live in the `statusLine` JSON, not in the shell prompt.

## Comparison

| | starship | tide | hydro | pure (fish port) | fish built-in |
|---|---|---|---|---|---|
| Git computation | Module run by the `starship` binary; `command_timeout` default 500 ms ([config](https://starship.rs/config/)). Sync or async: unverified, not stated in the docs I read | Runs "everything in the background"; shows untracked, modified, deleted counts ([README](https://github.com/IlanCosman/tide)) | Branch, dirty `•`, ahead/behind; "prompt repaints asynchronously" ([README](https://github.com/jorgebucaran/hydro)) | Branch, dirty `*`, stash, ahead/behind; async only with `fish-async-prompt` ([README](https://github.com/pure-fish/pure)) | Synchronous by construction (no async claim in docs); dirty state and untracked counts are opt-in because they are slow in large repos ([docs](https://fishshell.com/docs/current/cmds/fish_git_prompt.html)) |
| Shells | bash, fish and others ([starship.rs](https://starship.rs/)) | fish only | fish only ([README](https://github.com/jorgebucaran/hydro)) | fish only | fish only |
| Config | `~/.config/starship.toml`, path overridable by `STARSHIP_CONFIG` ([config](https://starship.rs/config/)) | Fish variables `tide_*`, universal by default ([wiki](https://github.com/IlanCosman/tide/wiki/Configuration)) | `hydro_*` variables via `set --universal` or `set --global` ([README](https://github.com/jorgebucaran/hydro)) | Variables documented on the project's doc site; names not in the README ([README](https://github.com/pure-fish/pure)) | `__fish_git_prompt_*` variables ([docs](https://fishshell.com/docs/current/cmds/fish_git_prompt.html)) |
| Install | `brew install starship` or install script ([starship.rs](https://starship.rs/)) | `fisher install IlanCosman/tide@v6` ([README](https://github.com/IlanCosman/tide)) | `fisher install jorgebucaran/hydro` | `fisher install pure-fish/pure` | Ships with fish |
| Nerd Font | Listed as a prerequisite ([starship.rs](https://starship.rs/)) | Required ([README](https://github.com/IlanCosman/tide)) | Not mentioned; default symbols are `•`, `↑`, `↓`, `❱` | Not mentioned | No |
| Custom segments | `[custom.*]` modules | `_tide_item_<name>` functions ([wiki](https://github.com/IlanCosman/tide/wiki/Custom-items-(prompt-segments))) | None documented | None documented | Write your own `fish_prompt` |

## starship

Git state comes from the `git_status` module ([config](https://starship.rs/config/)). The docs I read give `command_timeout = 500` ms for commands starship runs and `scan_timeout = 30` ms for file scans ([config](https://starship.rs/config/)). Whether the render is sync or async is unverified; the fetched portion of the docs does not say. The same page warns that `git_status` is very slow in WSL Windows directories.

One TOML file serves both shells. Init lines are `eval "$(starship init bash)"` for `~/.bashrc` and `starship init fish | source` for `config.fish` ([starship.rs](https://starship.rs/)). That gives one prompt definition for a bash login shell with fish layered on top.

Install is `brew install starship` or `curl -sS https://starship.rs/install.sh | sh`. A Nerd Font is listed as a prerequisite ([starship.rs](https://starship.rs/)). I did not verify whether the font is optional with a plain-symbol preset.

## tide

Tide "runs everything in the background so that your prompt will always feel snappy," and uses that to show untracked, modified and deleted counts ([README](https://github.com/IlanCosman/tide)). The mechanism (universal variables as the channel) is unverified in primary sources I read; the README does not describe it.

Requirements are the latest fish (4.0.2 per the README) and a Nerd Font ([README](https://github.com/IlanCosman/tide)). Install is `fisher install IlanCosman/tide@v6`.

Config lives in fish variables named `tide_<section>_<option>`, set with `set --universal` or `set --global` in `config.fish` ([wiki](https://github.com/IlanCosman/tide/wiki/Configuration)). Universal variables are runtime state, not a tracked file. The wiki's reproducibility answer is to put `tide configure --auto --style=Lean --prompt_colors='16 colors' ...` in a dotfiles sync script, run after install; pressing `p` at the end of `tide configure` prints the matching command ([wiki](https://github.com/IlanCosman/tide/wiki/Syncing-your-tide-config-in-your-dotfiles)). `deploy.sh` is symlink-only by design (see `CLAUDE.md`), so this would need a separate bootstrap step. Setting `tide_*` with `set --global` in a tracked `config.fish` is an alternative; I did not verify that it covers everything `tide configure` writes.

Custom items are fish functions named `_tide_item_<name>` that call `_tide_print_item`, with colors and icon in `tide_<name>_color`, `tide_<name>_bg_color`, `tide_<name>_icon`, then added to `tide_right_prompt_items` ([wiki](https://github.com/IlanCosman/tide/wiki/Custom-items-(prompt-segments))).

## hydro

Hydro shows branch, dirty `•` ("staged, unstaged or untracked files"), and ahead/behind `↑`/`↓`; the README says the prompt repaints asynchronously ([README](https://github.com/jorgebucaran/hydro)). Install is `fisher install jorgebucaran/hydro`; it is "designed only for Fish."

Config is `hydro_*` variables (symbols, colors, `hydro_fetch`, `hydro_multiline`, `hydro_ignored_git_paths`, `hydro_cmd_duration_threshold`), set with `set --universal` or `set --global` in `config.fish`. The `set --global` route keeps config in a tracked file. The README documents no custom-segment mechanism.

## pure (fish port)

Pure shows branch, `*` dirty, `≡` stash, `⇡`/`⇣` ahead/behind ([README](https://github.com/pure-fish/pure)). Async git updates work "when configured with fish-async-prompt," a separate plugin, so async is not built in. Requires fish 3.x or later and Fisher. The README lists no variable names (docs are on the project site) and no custom-segment support. I did not read the site's configuration pages.

## fish built-in (`fish_git_prompt`, `fish_vcs_prompt`)

`fish_vcs_prompt` calls the git, Mercurial and Subversion prompt functions ([docs](https://fishshell.com/docs/current/cmds/fish_git_prompt.html)). Dirty state is opt-in with `__fish_git_prompt_showdirtystate`; untracked files with `__fish_git_prompt_showuntrackedfiles`. The docs warn that informative status "can take a lot of time" in large repositories and that counting untracked files "requires a lot of time," and show `git config --local bash.showInformativeStatus false` to turn it off per repo. The fetched page was the fish 4.9.3 version, marked older by the site. Zero dependencies, no Nerd Font, config is plain `set` lines in a tracked `config.fish`. Fish only.

## Agent-aware prompt

**What exists**

- `CLAUDECODE=1` is set in subprocesses Claude Code spawns: Bash and PowerShell tools, tmux sessions, hook commands, status line commands, stdio MCP servers, and IDE-extension integrated terminals ([env vars](https://code.claude.com/docs/en/env-vars)). `CLAUDE_CODE_CHILD_SESSION=1` is the stricter variant, set for Bash, PowerShell and Monitor tool subprocesses, hooks and status line commands, not MCP servers or IDE terminals.
- Implication (my reading of the table): a prompt in the terminal where you launched `claude` does not see these variables. They help in IDE terminals, tmux sessions Claude spawns, and any prompt rendered inside an agent subprocess.
- Starship `[custom.<name>]` modules take `command`, `when` (a boolean, or a shell command that shows the module on exit status 0), `require_repo`, `detect_files`, `format`, `shell`, `os` ([config](https://starship.rs/config/)). A segment such as `when = '[ "$CLAUDECODE" = 1 ]'` fits the documented semantics; I did not run it. The `env_var` module shows an environment variable's value when it exists ([config](https://starship.rs/config/)). Each `when` is a subprocess; its per-prompt cost is unverified.
- Tide custom items are fish functions (see tide section). Hydro and pure document no custom segments.
- Cost and context data come from Claude Code's `statusLine`, not the shell. The command receives JSON on stdin including `model.display_name`, `cost.total_cost_usd` (client-side estimate at list price), `context_window.used_percentage`, `rate_limits.five_hour.used_percentage`, and `session_id`; updates are debounced at 300 ms, with optional `refreshInterval` ([statusline docs](https://code.claude.com/docs/en/statusline)). That output renders in Claude Code's own bar, so it is a second surface alongside the shell prompt.
- `cship` is a third-party Starship-style statusline for Claude Code with its own Claude modules, per its crate listing ([docs.rs](https://docs.rs/crate/cship/1.7.1), [repo](https://github.com/tfenne/cship)). I did not read its source; treat details as unverified. A search found a setup guide for starship plus Claude Code ([claudecodeguides.com](https://claudecodeguides.com/claude-code-for-starship-prompt-workflow/)); it is a blog, not a primary source, and I did not rely on it.

**What does not exist**

- No project among starship, tide, hydro or pure documents an agent-session segment, a Claude Code integration, or a built-in cost display.
- No documented env var identifies Codex or other agents; I searched only Claude Code's docs. Other agents: unverified.
- Nothing I found makes a shell prompt show the cost of an agent session running in a different process. Cost is only available inside the `statusLine` command.

## Sources

- starship docs: https://starship.rs/ and https://starship.rs/config/ (raw source: https://raw.githubusercontent.com/starship/starship/master/docs/config/README.md)
- tide: https://github.com/IlanCosman/tide, https://github.com/IlanCosman/tide/wiki/Configuration, https://github.com/IlanCosman/tide/wiki/Syncing-your-tide-config-in-your-dotfiles, https://github.com/IlanCosman/tide/wiki/Custom-items-(prompt-segments)
- hydro: https://github.com/jorgebucaran/hydro
- pure: https://github.com/pure-fish/pure
- fish: https://fishshell.com/docs/current/cmds/fish_git_prompt.html
- Claude Code env vars: https://code.claude.com/docs/en/env-vars
- Claude Code status line: https://code.claude.com/docs/en/statusline
- cship (third party): https://docs.rs/crate/cship/1.7.1, https://github.com/tfenne/cship
- Blog, not relied on: https://claudecodeguides.com/claude-code-for-starship-prompt-workflow/
