# Install lokex-cli GitHub Action

Install [`lokex-cli`](https://github.com/bodrovis/lokex-cli) in GitHub Actions workflows on Linux and Windows runners.

## Features

- Supports Linux and Windows
- Installs `latest`, `0.2.0`, or `v0.2.0`
- Optionally adds the install directory to `PATH`
- Exposes `install-dir` and `bin-path` outputs
- Uses pinned upstream installer scripts with checksum verification

## Inputs

| Name | Description | Required | Default |
|---|---|---:|---|
| `repo` | GitHub repository in `owner/name` format | No | `bodrovis/lokex-cli` |
| `bin-name` | Binary name to install | No | `lokex-cli` |
| `version` | Release version to install: `latest`, `0.2.0`, or `v0.2.0` | No | `latest` |
| `install-dir` | Install directory override | No | `""` |
| `add-to-path` | Add the install directory to `PATH` for subsequent steps | No | `true` |

## Outputs

| Name | Description |
|---|---|
| `install-dir` | Resolved install directory |
| `bin-path` | Full path to the installed binary |

## Usage

```yaml
steps:
  - uses: actions/checkout@v6

  - name: Install lokex-cli
    uses: bodrovis/install-lokex-cli@v1

  - name: Check version
    shell: bash
    run: lokex-cli version
```

## License

(c) [Elijah S. Krukowski](https://bodrovis.tech). Licensed under BSD 3-Clause