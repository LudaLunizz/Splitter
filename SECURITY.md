# Security policy

## Reporting a vulnerability

Please report it **privately**, not in a public issue.

Go to the **Security** tab of this repository, choose **Report a vulnerability**, and fill in the form. Only you and the maintainer can see the report.

Please include:

- what happens and why you think it is a security problem,
- the steps to reproduce it (the program or calls that trigger it, and the Windows version and build),
- the Splitter version (the zip's name, or the driver version in Device Manager),
- a crash dump or the bug check code, if Windows stopped with a blue screen.

You will get an acknowledgement as soon as I see the report. For a verified problem I aim to have a fix released within about 90 days, and I will tell you if it will take longer. If you want to be credited in the release notes, say so.

## Supported versions

Only the latest release gets security fixes. Please check that the problem is still there in the latest release before you report it.

## What is in scope

Splitter is a kernel-mode audio driver, so a bug in it can crash or compromise the whole PC. In scope:

- the driver (`windows/driver/`): anything a program without administrator rights can do through the audio endpoints or the driver's interfaces to crash Windows, read or write memory it should not, or raise its privileges;
- the INF and the install and uninstall scripts (`windows/install/install.ps1` and `uninstall.ps1`, which do the work, and the `install.cmd` and `uninstall.cmd` that start them with administrator rights);
- the release workflow and the files attached to a release (the zip and `SHA256SUMS.txt`).

## What is not a vulnerability by itself

The releases are **test-signed**: they only load on a PC in test-signing mode with Secure Boot off, and the README says so. That this mode lowers the protection of the PC is a known limit of test builds, not a vulnerability in Splitter. A way to make Windows load the test-signed driver **without** test-signing mode, or a problem in how `install.ps1` and `uninstall.ps1` trust and remove the test certificate, **is** in scope.

## Disclosure

Please give me the time above before you publish details. When a fix is released I will publish a GitHub security advisory that names the affected versions.
