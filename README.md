# Splitter

[![CI](https://github.com/LudaLunizz/Splitter/actions/workflows/ci.yml/badge.svg)](https://github.com/LudaLunizz/Splitter/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/LudaLunizz/Splitter?include_prereleases&sort=semver)](https://github.com/LudaLunizz/Splitter/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Splitter is BananaSplit's own set of virtual cables, packaged separately
from BananaSplit. It gives every BananaSplit channel a cable of its own:
the six input strips and the five buses. With it, BananaSplit for Windows
doesn't need VB-Audio's cables any more.

A strip's cable takes sound from apps into the strip, and the cable's number
is the strip's number:

| Cable | Apps play into (playback device) | BananaSplit records (recording device) |
| --- | --- | --- |
| 1 | `Splitter 1` | `Splitter 1 Output` → strip 1 |
| 2 | `Splitter 2` | `Splitter 2 Output` → strip 2 |
| 3 | `Splitter 3` | `Splitter 3 Output` → strip 3 |
| 4 | `Splitter 4` | `Splitter 4 Output` → strip 4 |
| 5 | `Splitter 5` | `Splitter 5 Output` → strip 5 |
| 6 | `Splitter 6` | `Splitter 6 Output` → strip 6 |

A bus's cable works the other way round: it makes the bus's mix a
microphone that apps can record, and the cable is named after the bus:

| Cable | BananaSplit plays into (playback device) | Apps record (recording device) |
| --- | --- | --- |
| 7 | bus A1 → `Splitter A1 Input` | `Splitter A1` |
| 8 | bus A2 → `Splitter A2 Input` | `Splitter A2` |
| 9 | bus A3 → `Splitter A3 Input` | `Splitter A3` |
| 10 | bus B1 → `Splitter B1 Input` | `Splitter B1` |
| 11 | bus B2 → `Splitter B2 Input` | `Splitter B2` |

In both tables, the device you pick in other apps is the one with the short
name. Windows shows each device with the device name after it, for example
`Splitter 3 (Splitter Cables)` or `Splitter B1 (Splitter Cables)`.

Status: **Windows only, version 0.2.0, test-signed.** It is on the
[Releases](https://github.com/LudaLunizz/Splitter/releases) page, and it
installs only on a PC in test-signing mode (see
[Signing](#signing-why-this-build-only-runs-in-test-mode)). Linux already
gets its cables from PipeWire (BananaSplit makes them itself), and macOS
isn't supported yet.

## Using it with BananaSplit

BananaSplit for Windows (2.8.3 and later) finds the cables by their names.
When a channel's virtual cable is switched on in its menu:

- strip N records `Splitter N Output`, and its menu says `Splitter N`, the
  device to pick as the app's output;
- bus B1 (say) plays into `Splitter B1 Input`, and its menu says
  `Splitter B1`, the device to pick as the app's microphone.

The strips and B1, B2 have their cables switched on to begin with; A1 to A3
are the speakers and headsets, so theirs are off. Without Splitter,
BananaSplit falls back to VB-Audio cables, as before, and it uses VB-Audio
cables for any channel whose Splitter cable is missing (for example,
switched off in the Windows sound settings).

BananaSplit never follows the Windows default device into a Splitter cable.
If the default output is `Splitter 1`, A1 still plays on the real speakers,
because playing into the cable that strip 1 records would feed back. In the
same way, if the default input is `Splitter B1`, a strip on the default
input records the real microphone.

## How a cable works

`windows/driver` is a WaveRT audio driver (PortCls and KMDF). It is a fork
of Microsoft's
[SimpleAudioSample](https://github.com/microsoft/Windows-driver-samples/tree/main/audio/simpleaudiosample),
which is under the MS-PL licence. It has twenty-two endpoints: a render and
a capture endpoint for each cable.

- **Data path:** the render endpoint of cable N converts what is played
  into it to 32-bit float and pushes it into ring N. The capture endpoint of
  the same cable pulls it out again, so the two halves of a cable may use
  different sample formats. Each ring holds 0.68 s (256 KiB, so 2.75 MiB
  for the eleven cables). (`Source/Utilities/cablering.*`)
- **Clock:** both halves are clocked by the performance counter at exactly
  48 kHz, so they never drift apart. Both move the cable on the driver's
  1 ms timer, whatever packet size their apps use and whether they are
  event-driven or poll, and the reader keeps a 20 ms margin behind the
  writer, which covers the timer jitter.
  - A packet counts as done once the position has moved past its end, so
    packets that aren't a whole number of milliseconds (512 frames is
    10.67 ms) stay in step with the audio. Packets shorter than 1 ms are
    refused.
  - The cable's latency is about 30 ms.
  - If nothing plays into a cable, it records silence.
  - If the recorder falls far behind, it skips ahead rather than playing
    old sound late.

  These rules are plain arithmetic in `Source/Utilities/cablerule.h`, and
  `tests/cablerule_test.cpp` tests them on any computer.
- **Formats:** 48 kHz stereo, in 16-bit, 24-bit (the default) or 32-bit
  float. NaN and infinity become silence. 16-bit and 24-bit audio comes
  out exactly as it went in, sample for sample.
- **Copy-protected content:** it plays as silence. The driver doesn't claim
  DRM support.
- **Names:** the INF writes each endpoint's name, in the device's own
  registry key, under the name GUID of its topology connector pin
  (`MediaCategories`). Those GUIDs are in `Source/Inc/endpoints.h`. The
  recording half of a bus cable has a microphone connector, so Windows shows
  it as a microphone; the recording half of a strip cable is a line in.

From the sample, Splitter removed the sine-tone generator, the dumping of
playback to `.wav` files, and the mic-array topology.

## Names, and VB-Audio

Splitter contains no VB-Audio code: it is Microsoft's MS-PL sample plus
code of its own. Its names stay clear of VB-Audio's products and device
names ("VB-CABLE", "CABLE Input", "CABLE Output", "VB-Audio Virtual Cable",
"Voicemeeter"):

- the cables are called `Splitter …`, and none of them contains "CABLE",
  "VB" or "Voicemeeter";
- the device is called "Splitter Cables". Version 0.1.0 called it "Splitter
  Virtual Cables", which came close to VB-Audio's driver name "VB-Audio
  Virtual Cable" and to "Virtual Audio Cable", the registered trademark of
  another product (Eugene Muzychenko's VAC), whose owner allows the words
  only as a common term, not as the name of someone else's product. So
  Splitter's texts call its cables "virtual cables", never "virtual audio
  cables".

The bus names A1 … B2 are BananaSplit's own bus names. VBAN, which
BananaSplit also speaks, is VB-Audio's protocol, and its specification lets
anyone implement it ("VBAN Protocol is public and free"). BananaSplit uses
only the PCM audio part, which that licence covers.

## Building

Run `pwsh -File windows/build.ps1` on Windows. It needs:

- Visual Studio 2022 or later, with the C++ desktop workload and the
  Spectre-mitigated libraries;
- `nuget`.

The Windows Driver Kit comes from NuGet (`driver/packages.config`), so you
don't need to install it.

The script does the following:

1. builds the driver and checks the INF with InfVerif;
2. makes the catalog;
3. signs the driver and the catalog with a new self-signed test
   certificate;
4. puts the result in `windows/dist/splitter-<version>-windows-x64.zip`,
   together with the installer and the licences.

On GitHub, every push to `main` and every pull request runs
`.github/workflows/ci.yml`:
`tests/cablerule_test.cpp` and `tests/inf_check.py` on Linux, and
`build.ps1` on Windows, which keeps the test-signed zip for 14 days as the
run's artifact.

To release, push a tag `v<version>` (`v0.2.0`, the version in `VERSION`).
It runs `.github/workflows/release.yml`, which builds the package and
writes `SHA256SUMS.txt` but doesn't publish them. When it has finished, run
`./release.sh v0.2.0`. It checks the files and publishes them under your
own GitHub account (`gh`), not GitHub's bot, as a pre-release, because the
build is test-signed. BananaSplit's "Splitter download page" button opens
this repository's releases, so Splitter is released here, not in
BananaSplit's repository.

The version is in `VERSION`. It must also be set in `Splitter.inx`,
`Splitter.rc` and `Directory.Build.props`, and the build checks that all
three match.

## Installing

Unzip the package and run `install.cmd`. Running it again updates the
driver. Running `uninstall.cmd` removes everything again. The package's
`README.txt` explains both.

If 0.1.0 is installed, run `uninstall.cmd` first (this package's or
0.1.0's: both remove it). 0.2.0 renamed the device ("Splitter Virtual
Cables" became "Splitter Cables"), and Windows may keep the old name on the
endpoints it already knows, which BananaSplit doesn't recognise. So
`install.cmd` stops when it finds 0.1.0 or its cables, and says so.

Splitter runs on x64 PCs only. Windows on ARM can't load an x64 driver, so
`install.cmd` stops on an ARM PC and says why.

## Signing: why this build only runs in test mode

Windows 10 and 11 load a kernel driver only if Microsoft has signed it.

- **Test build:** the package that `build.ps1` makes is signed with a test
  certificate. It loads only on a PC in test-signing mode (`bcdedit /set
  testsigning on`, then a restart; Secure Boot must be off).
  - `install.cmd` checks for that and explains what to do.
  - Use this build for development and trying it out, not for everyone's
    PC. Some games' anti-cheat refuses to run in test mode.
- **Public build:** a release that installs on any PC needs Microsoft's
  attestation signature. To get it, the project registers in the Partner
  Center Hardware Developer Program, which needs an EV code-signing
  certificate. From then on, each release goes as follows:
  1. the driver goes up as a signed CAB;
  2. Microsoft signs it;
  3. the signed `splitter.sys` and `splitter.cat` replace the ones in the
     package;
  4. `splitter-test.cer` is left out.

  Nothing in the code or the INF has to change for this.

## Not tested yet

Version 0.2.0 has not been run on a real PC yet. What has been checked:

- CI builds it with Visual Studio and the WDK on GitHub's Windows runner,
  and InfVerif and Inf2Cat pass with no errors or warnings;
- every driver source file type-checks with clang against the real WDK and
  SDK headers (Release and Debug, Windows 10 2004 and the newest target),
  with no new warnings;
- `tests/inf_check.py` checks that the INF, the endpoint GUIDs and the
  filter tables agree for all eleven cables;
- `tests/cablerule_test.cpp` passes.

Still to check on a real PC in test mode:

- all twenty-two endpoints appear with their names, and the bus cables'
  recording halves show as microphones;
- audio passes through each cable in all three formats;
- an app in exclusive mode, event-driven with 512-frame packets, and one
  that polls;
- the latency;
- running for a long time without glitches;
- install, update (0.2.0 over 0.2.0) and uninstall, and that BananaSplit
  recognises all eleven cables afterwards;
- Driver Verifier.

## Contributing

Issues and pull requests are welcome. Please run
`windows/tests/cablerule_test.cpp` and `windows/tests/inf_check.py` (and
`windows/build.ps1`, if you are on Windows) before opening a pull request;
CI runs all three.

## Licence

The licence is MIT (`LICENSE`). Files derived from Microsoft's sample keep
Microsoft's copyright notice and are also under the Microsoft Public License
(`windows/driver/LICENSE-MS-PL.txt`).
