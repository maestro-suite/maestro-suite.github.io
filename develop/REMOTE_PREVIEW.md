# Remote Preview (Development Only)

Use this workflow to preview the website when the repo is on a remote machine and you connect from macOS over SSH.

## Scenario

- Local machine: macOS
- Jump host: `mcnode43`
- Target server: `10.178.48.3`
- Site root on target: `/home/cheny0y/maestro-workspace/maestro-project-page`

## 1) Open SSH tunnel from macOS

Run on your Mac terminal:

```bash
ssh -J mcnode43 -L 8000:127.0.0.1:8000 10.178.48.3
```

This forwards your local `127.0.0.1:8000` to the target server `127.0.0.1:8000`.

## 2) Start local web server on the target

In that SSH session:

```bash
cd /home/cheny0y/maestro-workspace/maestro-project-page
python3 -m http.server 8000
```

## 3) Open in browser on macOS

Open:

- `http://127.0.0.1:8000`

## If port 8000 is busy

Use another port, e.g. `8765`, on both sides:

```bash
ssh -J mcnode43 -L 8765:127.0.0.1:8765 10.178.48.3
```

Then on target:

```bash
cd /home/cheny0y/maestro-workspace/maestro-project-page
python3 -m http.server 8765
```

Open:

- `http://127.0.0.1:8765`

## One-liner option

From macOS, run server directly through SSH:

```bash
ssh -J mcnode43 -L 8000:127.0.0.1:8000 10.178.48.3 \
  'cd /home/cheny0y/maestro-workspace/maestro-project-page && python3 -m http.server 8000'
```
