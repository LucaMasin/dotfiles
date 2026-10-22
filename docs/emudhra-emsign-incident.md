# eMudhra / emSign CA incident: Python remediation (for agents)

Instructions for an agent fixing a machine or project. Source and updates: <https://discuss.python.org/t/information-for-python-users-regarding-emudhra-emsign-ca-certificate-security-incident/109576>. Status as of 2026-10-22, based on both pages of the thread (the thread says it will be updated, so re-read it before relying on version numbers).

## What happened

The private keys of eight eMudhra intermediate CAs were weak (`d < 256`), so anyone can forge certificates that chain to the emSign root. The root was removed from CA bundles such as `certifi`. Clients that still trust it are open to man-in-the-middle attacks, including against `pypi.org` and `python.org`.

## Minimum safe versions

| Software | Minimum |
|---|---|
| certifi | 2026.10.19 (not 2026.10.18) |
| pip | 26.2.2 |
| uv | 0.13.4 |
| sigstore | 4.5.1 |
| pixi | 0.82.1 |
| cibuildwheel | 4.3.3 |
| OS `ca-certificates` | the distro's October 2026 security update (Debian: `20250419+deb13u1`) |

## Rules

1. **Never upgrade pip over the network with a vulnerable pip, uv, or certifi.** A plain `pip install -U pip` is the attack path. Bootstrap with the hash-pinned wheel below.
2. **Updating pip is the only fix for pip.** pip always trusts its vendored certifi in addition to the system store. Per the thread, `--cert`, `REQUESTS_CA_BUNDLE`, and distrusting the CA at OS level only add or change trust and do not remove it. `PIP_CERT` was not named in the thread; it is the environment form of `--cert`, so treat it as insufficient too (inferred, untested).
3. **Debian/Ubuntu `python3-pip` is patched to use the system CA store.** Updating `ca-certificates` fixes it; do not pip-upgrade the system pip.
4. Ask the user before running `sudo`, before editing lockfiles or dependency pins, and before touching environments you did not find yourself.
5. Do not modify environments on Python < 3.10 (pip 26.2.2 does not support them). List them in the report.
6. Report what you changed and what you skipped. Do not claim a machine is safe from version checks alone if any item below is unchecked.

## 1. System certificates

Needed first, because the secure bootstrap trusts the system store.

```bash
# Debian / Ubuntu / Raspberry Pi OS (needs sudo, ask first)
sudo apt update && sudo apt install --only-upgrade ca-certificates

# Arch / Omarchy
sudo pacman -Syu ca-certificates
```

macOS and Windows get this through OS updates.

**Known gap, Ubuntu 26.04 (checked 2026-10-22):** after the command above, `ca-certificates` stayed at `20260816ubuntu0.26.04.1`, apt offered nothing newer, and `/etc/ssl/certs` still contained `emSign_Root_CA_-_C1`, `emSign_ECC_Root_CA_-_C3`, and `emSign_Root_CA_-_G1`. The Ubuntu changelog for that version returned 404, so whether it carries the fix is unconfirmed. Treat the system store as unfixed and say so in the report (rule 6). Re-check later:

```bash
sudo apt update && sudo apt install --only-upgrade ca-certificates
dpkg -l ca-certificates
ls /etc/ssl/certs | grep -i emsign   # fixed when the emSign entries are gone
```

Keep the Python tools patched in the meantime (steps 2 and 3); that does not remove system trust.

## 2. Upgrade pip in every environment

Hash-pinned wheel (checksum is enforced by pip, so a MITM cannot substitute it):

```bash
PIP_WHEEL='pip @ https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl#sha256=fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70'

<env-python> -I -m pip install "$PIP_WHEEL"
<env-python> -I -m pip install --upgrade certifi
```

Find candidate environments (read-only), then inspect each:

```bash
find ~ -xdev -name pyvenv.cfg -not -path '*/node_modules/*' 2>/dev/null
<env-python> -I -m pip --version
<env-python> -I -c 'import certifi; print(certifi.__version__)'
```

Environments that are not plain venvs:

- **pipx:** upgrade the shared pip at `~/.local/share/pipx/shared/bin/python`, then certifi inside each venv under `~/.local/share/pipx/venvs/`.
- **venvs without pip** (for example `uv venv`): there is no pip to fix, only certifi. Using an already fixed pip: `<fixed-pip-python> -I -m pip --python <env-python> install --upgrade certifi`. Or, with a fixed uv: `uv pip install --python <env-python> 'certifi>=2026.10.19'`.
- **python.org macOS installer:** run the same two commands against `/Library/Frameworks/Python.framework/Versions/<ver>/bin/python<ver>` (and the free-threaded `PythonT.framework` build). If certifi has no RECORD file, use `--ignore-installed --no-deps certifi`.
- **New venvs:** Python 3.15.1, 3.14.9, and 3.13.17 bundle the fixed pip and certifi in `ensurepip`; upgrade CPython to get them. Python 3.12, 3.11, and 3.10 will not get a pip bump (it is not done in security releases), so their `venv` and `ensurepip` still install a vulnerable pip. Upgrade pip right after creating any venv on those versions, or use `uv venv`. Alternatively, patch the install as zware describes in the thread: put the pip 26.2.2 wheel in the `ensurepip` bundled-wheel directory and change the version string in `ensurepip/__init__.py`.

## 3. Upgrade uv

Not required if uv is not installed. Otherwise use the system trust store instead of uv's embedded one:

```bash
UV_SYSTEM_CERTS=true uv self update
uv --version   # >= 0.13.4
```

If uv came from a package manager, upgrade it there. Do not run `uv self update` on those.

## 4. Projects, CI, containers

- **uv projects:** upgrading certifi in `.venv` alone does not last. `uv run` and `uv sync` re-sync the venv to `uv.lock` and put the old version back. Fix the lock: `uv lock --upgrade-package certifi`, then `uv sync`. Do not do this in a project whose server is running without asking; `uv run` restarts or re-syncs are what revert the venv. Note that a newer uv may bump the lock `revision`.
- **Lockfiles and pins:** raise any `certifi`, `pip`, `uv`, `sigstore`, or `pixi` pin below the minimums. Dependency cooldowns delay the fix; exempt these packages or wait out the window.
- **Containers:** rebuild images to pick up system certificates. Official `python:*` Docker images are maintained downstream of CPython and may ship pip 26.2.1 (docker-library/python#1142). Expect the 3.13, 3.14, and 3.15 images to update after the CPython releases above; the maintainers said they will not update 3.11 and 3.12. In a Dockerfile, run the hash-pinned pip install from step 2 and `apt-get install --only-upgrade ca-certificates`. `ENV PIP_CERT=...` is not sufficient (rule 2).
- **CI and builds:** use cibuildwheel ≥ 4.3.3. Its Python 3.9 pip is still vulnerable, so build with uv and set a minimum version. Pin `pip>=26.2.2` where CI creates venvs.
- **Python 3.9 and older:** no fixed pip exists. Use uv ≥ 0.13.4 for installs in those environments.

## 5. Verify

For each environment touched, all of these must pass:

```bash
<env-python> -I -m pip --version                                      # >= 26.2.2 (skip for distro pip, see rule 3)
<env-python> -I -c 'import certifi; print(certifi.__version__)'      # >= 2026.10.19
uv --version                                                          # >= 0.13.4, if installed
dpkg -l ca-certificates                                               # Debian family: the October 2026 update
```

## Defense in depth (not yet released)

CPython is adding an SPKI denylist for the eight eMudhra intermediates to the `ssl` module (python/cpython#160040) and plans to backport it. Upgrade CPython when it ships. This does not replace upgrading pip and certifi.
