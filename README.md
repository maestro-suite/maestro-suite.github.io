# maestro-project-page

Official project page for MAESTRO: benchmark results, methodology, visualizations, and resources.

## Asset Sync

Sync benchmark assets from the source repo:

```bash
make sync SOURCE_REPO=/home/cheny0y/git/mas-benchmark
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

## Repo Policy

- Commit website code, template assets, and publish-ready figures.
- Do not commit raw/intermediate data artifacts under `data/raw/` (ignored via `.gitignore`).
- Keep reproducibility scripts in `scripts/` so figures can be regenerated from source repos.
