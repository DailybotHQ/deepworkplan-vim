# Plugins and tools — what is installed and why

Every plugin, language server, formatter and external tool the editor carries,
with its reason to exist. The reason is always tied to the
[product focus](PRODUCT_SPEC.md#product-focus): a **mini VS Code in the
terminal** to navigate files, see what changed, read the diff and approve or
discard it, **agent-first**, with Deep Work Plan in view, **friendly** and
**lightweight**. A tool that serves none of that needs a reason here or goes.

This file is kept honest by a test: `tests/smoke/plugin_refs.lua` fails when a
plugin in `lua/plugin_specs.lua` or a server in `lua/lsp/server.lua` is missing
from it. Add the entry in the same change.

How to read the tables: **Pillar** is the part of the focus it serves
(Navigate, Changes = see what changed, Diff, Approve = approve or discard,
Agent, DWP, Friendly, Light, Foundation). **Cost** is the headless startup self
time measured in PLAN_013, before `vim.loader` (which cut the total by ~40%);
"—" means below measurement noise. **Loaded**: every plugin loads at startup
unless it says otherwise. **If removed** says what you would lose.

## The mini-VS-Code map

| VS Code idea | Here | Provided by |
|---|---|---|
| Explorer | `SPC n` file tree with git marks | nvim-tree |
| Quick Open (`Ctrl-P`) | `SPC f f`, recent `SPC f o`, search text `SPC f w` | telescope |
| Command palette | `SPC h h` command index; `SPC t` every finder | the glossary (`lua/mapping/glossary.lua`), telescope |
| Source Control (changes list) | git marks in the tree, margin signs, `SPC g s t`, the diff panel's file list | nvim-tree, vim-signify, vim-fugitive, diffview |
| Diff editor | `SPC g d` side-by-side diff | diffview |
| Stage / discard | diff panel `-` `s` `d`; `SPC g a p` by hunks | diffview, vim-fugitive |
| Tabs and status bar | tab line and status line (with the active plan) | bufferline, lualine |
| IntelliSense | completion, go to definition, hover, diagnostics | nvim-cmp, LSP |
| Integrated terminal | `Ctrl-T` opens a terminal on the left | the editor itself |
| Welcome page | the dashboard with shortcuts and plans | alpha-nvim + `lua/setUp/greeter*.lua` |
| Plans view | `SPC P` sidebar, reader, statusline segment | `lua/dwp/` (no plugin) |
| Extensions marketplace | deliberately **not** here — one curated, pinned set | — |

## Plugin manager

| Plugin | Pillar | What and why |
|---|---|---|
| `lewis6991/pckr.nvim` | Foundation | Installs and updates the plugins below at the commits pinned in `pckr/lockfile.lua`, so two installs of one release run the same code. Cost: ~11 ms (bootstrap and applying the lock). If removed: nothing installs. |

## LSP and formatting

| Plugin | Pillar | What and why |
|---|---|---|
| `neovim/nvim-lspconfig` | Agent, Friendly | Server definitions: how to start each language server. If removed: no go-to-definition, hover or diagnostics. |
| `williamboman/mason.nvim` | Foundation | Installs language servers into the user's data directory — no system packages. Cost: part of the ~38 ms `lsp.server` setup. |
| `williamboman/mason-lspconfig.nvim` | Foundation | Maps lspconfig names to Mason packages and installs the server list on first start. |
| `mhartington/formatter.nvim` | Friendly | `:Format` / `SPC f`: runs biome, black, shfmt or stylua on the buffer; also removes trailing whitespace everywhere. Cost: ~6 ms. If removed: no `:Format`. |

## Completion and snippets

| Plugin | Pillar | What and why |
|---|---|---|
| `hrsh7th/nvim-cmp` | Friendly | The completion menu. Cost: ~8 ms. |
| `hrsh7th/cmp-nvim-lsp` | Friendly | Completion from the language server. |
| `hrsh7th/cmp-buffer` | Friendly | Words from the open buffers (also `/` search). |
| `hrsh7th/cmp-path` | Friendly | File paths while typing. |
| `hrsh7th/cmp-cmdline` | Friendly | Completion on the command line. |
| `saadparwaiz1/cmp_luasnip` | Friendly | Snippet entries in the menu. |
| `onsails/lspkind.nvim` | Friendly | Kind icons in the menu; `completion.lua` requires it directly. |
| `L3MON4D3/LuaSnip` | Friendly | The snippet engine (snipmate snippets in `snippets/`). Cost: ~21 ms — the largest single item after the LSP chain; a candidate for loading on first insert. |

## Syntax and parsing

| Plugin | Pillar | What and why |
|---|---|---|
| `nvim-treesitter/nvim-treesitter` | Friendly | Parser manager for tree-sitter highlighting. **Known issue:** only the parsers Neovim bundles (c, lua, vim, markdown) are present and its `setup` options in `lua/setUp/highligth.lua` are ignored by the pinned version; `vim-polyglot` carries the rest. |
| `windwp/nvim-ts-autotag` | Friendly | Closes and renames HTML/JSX tags. |
| `sheerun/vim-polyglot` | Friendly | Syntax and indent for many languages with no parser installed. Cost: ~12 ms, the largest single plugin — kept until the parser work is done. |

## Navigate

| Plugin | Pillar | What and why |
|---|---|---|
| `nvim-tree/nvim-tree.lua` | Navigate, Changes | The file tree (`SPC n`), on the left by default (side and width from `dwpvim.json`, see [CONFIGURATION.md](CONFIGURATION.md)); shows git state as `M A D U R` in the sign column. Cost: ~5 ms. If removed: no explorer. |
| `nvim-tree/nvim-web-devicons` | Navigate | File icons for the tree, the finder and the status line. |
| `nvim-telescope/telescope.nvim` | Navigate | Quick open, recent files, text search, bookmarks and the dashboard shortcuts. Cost: ~6 ms. If removed: the dashboard buttons and `SPC f …` stop working. |
| `nvim-lua/plenary.nvim` | Foundation | Library telescope and diffview are built on. |
| `easymotion/vim-easymotion` | Navigate | Jump to any visible two-character target (`SPC s s`). Cost: ~3 ms; a candidate for loading on its key. |
| `christoomey/vim-tmux-navigator` | Navigate | Move between Neovim splits and tmux panes with one set of keys; only useful inside tmux. |

## See what changed, review, approve or discard

| Plugin | Pillar | What and why |
|---|---|---|
| `tpope/vim-fugitive` | Changes, Approve | `:Git` — status, stage by hunks (`SPC g a p`), commit, blame, show, pull and push. |
| `mhinz/vim-signify` | Changes, Approve | Margin signs for added, changed and removed lines; `]c` / `[c` jump between hunks; `:SignifyHunkUndo` discards one (not yet mapped — see the roadmap). |
| `sindrets/diffview.nvim` | Diff, Approve | The side-by-side diff and its file panel (`SPC g d`): stage `-` / `s`, discard `d` after a confirmation. Cost: ~6 ms. If removed: no diff view and no one-key discard. |

## Interface

| Plugin | Pillar | What and why |
|---|---|---|
| `goolord/alpha-nvim` | Friendly, DWP | The dashboard: wordmark, shortcuts and "Your plans". If removed: a blank start. |
| `akinsho/bufferline.nvim` | Friendly | The tab line. Cost: ~6 ms. |
| `nvim-lualine/lualine.nvim` | Friendly, DWP | The status line, including the active plan's clickable segment. |
| `lukas-reineke/indent-blankline.nvim` | Friendly | Indent guides. |

## Editing helpers

| Plugin | Pillar | What and why |
|---|---|---|
| `preservim/nerdcommenter` | Friendly | Comment and uncomment (its default `<Leader>c…` mappings). |
| `tpope/vim-surround` | Friendly | Add, change and delete surrounding quotes and brackets. |
| `tpope/vim-repeat` | Friendly | Makes `.` repeat plugin actions such as surround. |
| `jiangmiao/auto-pairs` | Friendly | Closes brackets and quotes. |
| `terryma/vim-multiple-cursors` | Friendly | Several cursors for repeated edits. |
| `editorconfig/editorconfig-vim` | Friendly | Honours a project's `.editorconfig`, so an agent and a person format alike. |
| `ap/vim-css-color` | Friendly | Shows colour literals in CSS. |
| `KabbAmine/vCoolor.vim` | Friendly | Colour picker. |
| `Pocco81/auto-save.nvim` | Friendly | Saves automatically after edits, so buffers do not drift from disk. |

## Markdown and live preview

| Plugin | Pillar | What and why |
|---|---|---|
| `iamcco/markdown-preview.nvim` | Friendly | `SPC m p`: preview in the browser. |
| `MeanderingProgrammer/render-markdown.nvim` | Friendly | `SPC m r`: render in place; loaded only for markdown buffers. |
| `turbio/bracey.vim` | Friendly | `:Bracey` live HTML preview; loaded only on that command. |

## Language servers (installed by Mason on first start)

Eleven servers, each started only for its own filetypes. Six install through
`npm` (ts_ls, eslint, jsonls, yamlls, dockerls, emmet_ls), which
`lua/lsp/npm_guard.lua` keeps real; the other five are native binaries or pip
packages.

| Server | Languages | Why |
|---|---|---|
| `lua_ls` | Lua | The editor's own language. |
| `ts_ls` | TypeScript, JavaScript | The most common agent and project language. |
| `eslint` | JS/TS | Reports and fixes lint problems through the language server (the editor has no separate linter). |
| `jsonls` | JSON | Schemas and validation for configs. |
| `yamlls` | YAML | CI, Compose and plan files. |
| `taplo` | TOML | Cargo and project configs. |
| `marksman` | Markdown | Follow a link to its target, complete links and headings, outline and rename headings — in docs and plans. Its **diagnostics are silenced** on purpose (`lua/lsp/server.lua`): a warning icon beside a file in the tree for an ambiguous or git-ignored link is noise. |
| `dockerls` | Dockerfile | The contributor image. |
| `emmet_ls` | HTML/CSS | Emmet expansion. |
| `rust_analyzer` | Rust | The rust toolchain. |
| `jedi_language_server` | Python | Completion and navigation for Python. |

Retired (PLAN_013), not coming back without a reason: efm, diagnosticls,
tailwindcss, grammarly, bashls, astro, svelte, vuels, angularls, sqlls, vimls.

## Formatters (`:Format`, `lua/lsp/formatter.lua`)

| Tool | Files | Installed by |
|---|---|---|
| `biome` | JS, TS, JSON, CSS, GraphQL | the installer (`pnpm add -g @biomejs/biome`) |
| `black` | Python | the installer, via the system package manager |
| `shfmt` | shell | the installer |
| `stylua` | Lua | the installer |
| trailing-whitespace remover | every file | built into formatter.nvim |

There is no prettier and no separate linter; nvim-lint was retired in PLAN_013.
**Markdown has no formatter, deliberately**: neither prettier nor mdformat is
installed (`:Format` on a `.md` only trims trailing whitespace). Adding one is a
decision for the owner, not a default.

## External tools the installer asks for

`pnpm` and `node` (plugin builds and npm-based servers), `ripgrep` and `fd`
(telescope search), `luarocks`, a C toolchain (tree-sitter parsers), `git`,
`curl`, and `lua`. `--skip-packages` assumes the image already has them.

## Where to change it

Add or remove a plugin in `lua/plugin_specs.lua`, refresh the pin with
`scripts/update-plugin-lock.sh`, update this file, and run
`bash tests/smoke/run.sh` and `bash scripts/boot-check.sh`.
