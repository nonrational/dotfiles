# One command for a new exe.dev box

## `scripts/new-exe-box.sh`: one command for a new VM

Lives in this repo because it runs from the Mac with the human's exe.dev key and 1Password session. exe.dev's `new` command offers `--setup-script` for first boot, but a first-boot run cannot be watched; the wrapper runs the provisioning itself over ssh instead, sequentially.

```
scripts/new-exe-box.sh <name>          # or make exe-box NAME=<name>
```

1. Probe `ssh -o StrictHostKeyChecking=accept-new <name>.exe.xyz true`. If the box answers, print `using existing <name>.exe.xyz` and skip steps 2 and 3, so a re-run converges an existing box.
2. `ssh exe.dev new --name <name> --json`. The box comes up bare; no `--setup-script`, so nothing runs before the wrapper can watch it.
3. Poll the same `true` probe until the box answers, within `EXE_BOX_WAIT` seconds (default 300), every `EXE_BOX_POLL` seconds (default 5).
4. Inject the token over stdin, never through `--env` or an argument, so it lands only in `gh`'s config on the VM, the same state an interactive login leaves:

   ```
   op read "op://<vault>/<item>/token" \
     | ssh <name>.exe.xyz 'gh auth login --with-token && gh auth setup-git'
   ```

5. Clone or update the dotfiles and install them, in one ssh call:

   ```
   ssh <name>.exe.xyz '{ git -C ~/.dotfiles pull --ff-only || git clone <repo URL> ~/.dotfiles; } && ~/.dotfiles/install.sh && ~/.claude/sync-plugins.sh'
   ```

   The run is sequential and as the login user, so there is no first-boot race. A re-run pulls first and converges on the upstream of the VM checkout's current branch (not necessarily `main`); a pull that fails on an existing clone sends `git clone` into a non-empty directory, which fails and stops the chain.
   The wrapper assumes the exeuntu image ships `git`, `gh` and `claude` (the exe.dev docs do not list the image's tools); B2's probe confirms it.
6. Print `ready: <name>.exe.xyz https://<name>.exe.xyz/`, then `optional: ssh <name>.exe.xyz ~/bin/setup-review-watcher`.

The script reads the token before creating anything: a bad reference costs a retry, not a half-provisioned VM.

Configuration, all environment variables with defaults in the script:

- `EXE_BOX_REPO_URL`: the repo to clone (default `https://github.com/nonreagent/dotfiles`).
- `EXE_BOX_GH_TOKEN_REF`: the 1Password item path (default `op://Private/nonreagent-github/token`). `op` unlocking is the only human touch.
- `EXE_BOX_WAIT` (300) and `EXE_BOX_POLL` (5): the wait loop's deadline and interval, in seconds.

The same pipe can carry a `claude setup-token` value into the VM's environment file, which would close the expired-login failure the review watcher records. That is a separate decision: a long-lived Claude token is a larger blast radius than a fine-grained PAT scoped to nonreagent's repositories. This spec leaves it out; the wrapper is written so adding a second injected secret is one more line.

Every ssh call passes `-o StrictHostKeyChecking=accept-new`: non-interactive ssh to the `exe.dev` lobby hangs on host-key prompts otherwise, as exe.dev's own skill file warns.

## Tests

`test/test_exe_box.sh` runs the script under a mktemp sandbox with stub `ssh` and `op` on `PATH`. It covers the create-wait-inject-install flow, reuse of an existing box, a bad token reference creating nothing, the token travelling on stdin only, the wait timeout, and the usage error.
