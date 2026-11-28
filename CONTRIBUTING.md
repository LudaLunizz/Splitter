# Contributing

Issues and pull requests are welcome. This file is the setup and the exact
commands; the [README](README.md) explains how a cable works and how a release
is made.

## Setup

| Directory | What |
|---|---|
| `windows/driver/` | the driver (a fork of Microsoft's SimpleAudioSample), the INF and the WDK packages |
| `windows/tests/` | `cablerule_test.cpp` (ring and formats), `inf_check.py` (INF and C++ tables agree) and `install_scripts_test.ps1` (the install scripts, with stand-ins for Windows) |
| `windows/build.ps1` | build, InfVerif, catalog, test signing and the zip |

Building the driver needs Windows with Visual Studio 2022 or later (C++ desktop
workload and the Spectre-mitigated libraries) and `nuget`; the WDK comes from
NuGet. The first two tests run on any system with a C++17 compiler and Python 3;
the third needs PowerShell 7 (`pwsh`), on Linux too.

## Before you open a pull request

These are what CI runs (`.github/workflows/ci.yml`):

```sh
cd windows
c++ -std=c++17 -O2 -Wall -Wextra -Werror -o /tmp/cablerule_test tests/cablerule_test.cpp && /tmp/cablerule_test
python3 tests/inf_check.py
pwsh -File build.ps1        # on Windows only
```

CI does not run the install-script test yet, so run it yourself when your change
touches `windows/install/`:

```sh
pwsh -NoProfile -File windows/tests/install_scripts_test.ps1
```

Driver code that CI cannot run for real (audio through a cable, latency, long
runs, Driver Verifier) is listed under "Not tested yet" in the README; say in
the pull request whether you tried your change on a real PC in test mode.

## Conventions

- **The version is in `VERSION`** and must also be set in `Splitter.inx`,
  `Splitter.rc` and `Directory.Build.props`; the build checks that they match.
- **A change to the cables changes three places**: the INF, the endpoint GUIDs
  and the filter tables. `inf_check.py` checks that they agree.
- **Files derived from Microsoft's sample keep Microsoft's copyright notice**
  (MS-PL, see `windows/driver/LICENSE-MS-PL.txt`).
- **GitHub Actions are pinned to a full commit SHA** with the version in a
  comment; Dependabot proposes updates. The WDK and SDK versions are updated
  by hand, `packages.config` and `Directory.Build.props` together.

## Issues and pull requests

Open an issue first for anything beyond a typo, saying what you want and why.
Work on a branch named `<issue number>-short-name`, and start the pull request
description with `Closes #<number>`. Wait for CI to be green; the maintainer
merges with a rebase, so the history stays linear. Security problems go to
**Security → Report a vulnerability**, not to a public issue (see
[SECURITY.md](SECURITY.md)).

Developed with help from Claude Code; every change is reviewed, tested in CI and
released by the maintainer.

## Releases

Releases are made by the maintainer: a version bump (see above), a tag
`v<version>` on main, the package built by `.github/workflows/release.yml`, and
`./release.sh v<version>` to publish it as a pre-release under the maintainer's
account (the build is test-signed).
