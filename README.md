# maestro-project-page

Official project page for MAESTRO: benchmark results, methodology, visualizations, and resources.

## Asset Sync

Sync benchmark assets from the source repo:

```bash
make sync SOURCE_REPO=/path/to/mas-benchmark
```

Source repo aliases: `config/source_repos.txt`  
Asset manifest: `config/assets_manifest.txt`

Manifest entries support:
- `relative/source/path`
- `relative/source/path => repo/destination/path`
- `alias:relative/source/path => repo/destination/path`

Examples:
- `mas:docs/imgs/maestro-logo.png => static/images/docs/imgs/maestro-logo.png`
- `obs:mas_traces/tree-of-thoughts/data/game_of_24_benchmark.csv => data/raw/agent-observability/tree-of-thoughts/game_of_24_benchmark.csv`

## Development Preview

For remote SSH preview (including jump-host setup), see:

- `develop/REMOTE_PREVIEW.md`

## Optional UI: More Works Dropdown

The floating `More Works` dropdown is intentionally disabled for now to avoid showing template placeholders.

- Location: `index.html` near the top of `<body>`, under `<!-- More Works Dropdown (disabled...) -->`
- To re-enable: uncomment that full HTML block.
- Before enabling: replace placeholder links/titles with real project/paper entries.

## Reproduce Reference Plots

Generate the Tavily on/off latency-cost reference plot (from `mas-benchmark`):

```bash
scripts/run_reference_tavily_diff.sh
```

Generate the Tavily on/off accuracy-delta reference plot (from `agent-observability`) directly into website assets:

```bash
scripts/run_reference_tavily_accuracy_delta.sh
```

If needed, override source repo path:

```bash
SOURCE_REPO=/path/to/agent-observability scripts/run_reference_tavily_accuracy_delta.sh
```

## Repo Policy

- Commit website code, template assets, and publish-ready figures.
- Do not commit raw/intermediate data artifacts under `data/raw/` (ignored via `.gitignore`).
- Keep reproducibility scripts in `scripts/` so figures can be regenerated from source repos.
