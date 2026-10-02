# DeepSeek Harness (`dsh`)

DeepSeek's open-source agent harness, installed 2026-09-24 at version
`0.1.5-rc.3` from the npm package `@deepseek-ai/dsh` (upstream:
`github.com/deepseek-ai/deepseek-harness`, docs:
`deepseek-harness.github.io/deepseek-harness`). It is **developer-preview
software with breaking changes** and, per upstream's `SAFETY.md`, unaudited:
it can execute model-generated commands and third-party plugins with the
invoking user's privileges. On this host that includes passwordless sudo —
approval prompts are a usability gate, not a security boundary. See
[passwordless-login.md](passwordless-login.md).

## Install

```bash
npm i -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh@latest
```

- User-level only: npm's global prefix is `~/.local`, so no sudo, no pacman
  transaction, no snapper snapshot.
- 520 packages, 283 MiB at `~/.local/lib/node_modules/@deepseek-ai/dsh`
  (dependencies are nested, not hoisted). Shim: `~/.local/bin/dsh`.
- `--allow-scripts` is required: npm 12 blocks dependency install scripts by
  default, and `node-pty` (native PTY), `koffi` (FFI), and
  `@deepseek-ai/dsh-subprocess-local` need theirs. The flag is per-command;
  `~/.npmrc` is untouched.
- Node: the shim uses `node` from `PATH` — currently `~/.local/bin/node`
  v26.7.0 (pacman `nodejs` 26.8.2 is the fallback).
- First boot created `~/.dsh/`; see **State layout** below.

## Profiles and modes (verified against the installed build)

`dsh` boots a *profile*: an ordered stack of plugin bundles under
`~/.dsh/profiles/`. Shipped templates are exactly `acp`, `web`, `headless`,
`sdk`, `sdk-minimal`. `web` and `headless` profile directories were
materialized on first use.

| Command | What it does |
|---|---|
| `dsh web` | Serve the browser UI (alias of `--profile web`) on `http://127.0.0.1:3080/?token=…`; opens the browser. Flags: `--no-open`, `--port N` (`0` = OS picks), `--host`, `--trusted-host` |
| `dsh --profile headless "task"` | One-shot: answers the task, streams reasoning to stderr, prints the final message, exits |
| `dsh --profile acp` | Agent Client Protocol on stdio, for editor embedding |
| `dsh --profile web --dump-config` | Composed plugin tree including user overrides |
| `dsh --profile web --dump-default-config` | Shipped defaults only |
| `dsh --profile rescue --from-default-profile web` | Clone a shipped profile as a custom one |
| `dsh plugin --profile <name> add <pkg>` | Plugin management — **forwards to pnpm, which is not installed on this machine** |

**There is no TUI in this release.** Verified three ways: `@deepseek-ai/dsh-tui`
and `dsh-tui-app` are not published on npm; the repo's `apps/` contains only
`cli`, `web`, `desktop`, `desktop-host`; and `PROFILE_TEMPLATES` has no `tui`
entry. The launcher's `--profile tui` help example is aspirational. Interactive
options today: the Web UI (over an SSH tunnel: `ssh -L 3080:127.0.0.1:3080 <host>`),
one-shot `headless`, or ACP in an editor. When upstream ships it: install
`pnpm` (`sudo pacman -Syu pnpm`), then `dsh plugin --profile tui add <pkg>`.

## Providers

Model routes live in `~/.dsh/settings.yaml` under `llm-pi-ai.providers`. Keys
are referenced by **environment variable name** (`apiKeyEnv`), never written
to the file; `~/.config/bash/user/secrets.sh` exports both variables in the
interactive shell, so no extra plumbing is needed. The adapters re-read the
file on the next request — no restart.

Current file (written 2026-09-24):

```yaml
llm-pi-ai:
  providers:
    ollama-cloud:
      apiKeyEnv: OLLAMA_API_KEY
      api: openai-completions
      baseURL: https://ollama.com/v1
      models:
        - id: "deepseek-v4.1-flash"
          compat:
            thinkingFormat: deepseek
        - id: "deepseek-v4-pro:0813"
          compat:
            thinkingFormat: deepseek
        - id: "deepseek-v4-flash:0731"
          compat:
            thinkingFormat: deepseek
        - id: "qwen3.5:397b"
        - id: "glm-5.3"
        - id: "glm-5.3-flash"
        - id: "minimax-m3"
    openrouter:
      apiKeyEnv: OPENROUTER_API_KEY
      api: openai-completions
      baseURL: https://openrouter.ai/api/v1
      models:
        - id: "anthropic/claude-opus-5.5"
        - id: "openai/gpt-6-luna"
        - id: "z-ai/glm-5.3-prime"
        - id: "xiaomi/mimo-v2.6-pro-ultraspeed"
```

- Both endpoints were verified live with the env keys: `/v1/models` answers on
  `https://ollama.com/v1` (20 models) and `https://openrouter.ai/api/v1`
  (458 models). Model ids may drift; use "Fetch available models" in the Web
  UI or re-run that listing.
- `compat.thinkingFormat: deepseek` is required on the DeepSeek V4 ids:
  behind an OpenAI-compatible gateway they think unless told otherwise, and
  this makes an `off` effort send `thinking: {type: disabled}`.
- Models listed by hand declare no reasoning levels, which also keeps dsh from
  sending the system prompt as `role: developer` — a shape many gateways
  reject. Add `reasoningEfforts:` only for a model whose gateway accepts them.
- Alternative to this file: paste keys in the Web UI (Settings → Models). Keys
  are write-only and land in `~/.dsh/.credentials.yaml` (0600). The env route
  was chosen instead so no secret is ever written by dsh.

### Default model

The shipped default is `deepseek-official` / `deepseek-flash` (needs a
DeepSeek account key). Overridden in both profiles via
`~/.dsh/profiles/{web,headless}/cordis.patch.yml`:

```yaml
- id: agent-default-model
  config:
    provider: ollama-cloud
    model: deepseek-v4.1-flash
```

Edit either file to change it; confirm with
`dsh --profile headless --dump-config | grep -A3 agent-default-model`.

## State layout

```text
~/.dsh/
├── settings.yaml              # provider routes (no secrets)
├── .credentials.yaml          # 0600; only used if keys are pasted in the UI
├── .anonymous-user-id
├── profiles/
│   ├── web/  headless/        # cordis.yml (bundle layer) + cordis.patch.yml (yours)
│   └── node_modules/          # symlink farm into the global install tree
└── storages/workspace.json    # 0600; workspace selections
```

`DSH_HOME` overrides the root. Deleting `~/.dsh` resets dsh completely.

## Daily use

```bash
cd ~/path/to/project
dsh web        # open the printed token URL; Settings → Models shows both providers;
               # "Choose workspace" → pick the project dir → send a task
```

Requests without the token get `401 dsh web authentication required`; treat
the token URL like a password and keep the server on `127.0.0.1` (never
`--host 0.0.0.0` casually). The Web UI asks for approval before operations
that require it under the active permission policy.

## Verification (2026-09-24)

- `dsh --version` → `0.1.5-rc.3`; `npm ls -g @deepseek-ai/dsh` lists it.
- `require('node-pty')` loads (linux-x64 prebuild); koffi FFI call
  `strlen("hello")` → 5; npm log shows all five install scripts ran, exit 0.
- `--dump-config` shows `agent-default-model → ollama-cloud /
  deepseek-v4.1-flash` for both profiles.
- Live one-shot: `dsh --profile headless "Reply with exactly: HARNESS OK"` →
  `HARNESS OK` (exit 0).
- Web smoke: tokenized URL returns HTTP 303 (redirect into the app);
  untokened request returns 401; server stopped by explicit PID, port
  released.

## Gotchas

- `dsh plugin …` (add/remove) needs **pnpm**, not installed. Use
  `sudo pacman -Syu pnpm` (full upgrade per repo rules) or `npm i -g pnpm`.
- Upgrades: `npm i -g @deepseek-ai/dsh@latest` and re-check npm's
  blocked-install-script warnings; expect breaking changes.
- All state is `~/.dsh/`; back it up if sessions matter.
- The agent inherits the user's full privileges. The hardening design
  (containment / on-access AV / integrity monitoring) is not yet written —
  see the pending question in this repo's conversation record.

## Rollback

```bash
rm ~/.dsh/settings.yaml
printf '[]\n' > ~/.dsh/profiles/web/cordis.patch.yml
printf '[]\n' > ~/.dsh/profiles/headless/cordis.patch.yml
# full removal:
npm rm -g @deepseek-ai/dsh && rm -rf ~/.dsh
```

## Files touched by this topic

| Location | Purpose | Revert |
|---|---|---|
| `~/.local/bin/dsh`, `~/.local/lib/node_modules/@deepseek-ai/dsh/` | npm global install | `npm rm -g @deepseek-ai/dsh` |
| `~/.dsh/settings.yaml` | provider routes (env-referenced keys) | delete file |
| `~/.dsh/profiles/{web,headless}/cordis.patch.yml` | default-model override | restore `[]` |
| `~/.dsh/` (created on first boot) | profiles, storages, credentials store | `rm -rf ~/.dsh` |
