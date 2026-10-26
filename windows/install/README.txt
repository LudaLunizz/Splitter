Splitter @VERSION@ for Windows - BananaSplit's own virtual cables, one per channel
==================================================================================

Splitter adds eleven virtual cables to Windows, one for each BananaSplit
channel.

The six input strips. The cable of strip N (1 to 6) is:

  "Splitter N"          a playback device. Choose it as an app's output
                        (Discord, a browser, OBS, a game) to send that app
                        to BananaSplit.
  "Splitter N Output"   a recording device. BananaSplit's input strip N
                        records it, so whatever plays into "Splitter N"
                        arrives on strip N.

The five buses (A1, A2, A3, B1, B2). The cable of bus B1, say, is:

  "Splitter B1"         a recording device. Choose it as an app's
                        microphone (Discord, OBS, a call) and the app hears
                        bus B1's mix.
  "Splitter B1 Input"   a playback device. BananaSplit's bus B1 plays into
                        it.

In BananaSplit, each channel's menu switches its cable on or off. The
strips and B1, B2 have theirs on to begin with; A1 to A3 play on your
speakers or headset, and have theirs off.

All cables run at 48 kHz stereo. The sample format (16-bit, 24-bit or
32-bit float) can be set per device under Sound settings > device >
Properties > Advanced. Each cable adds about 30 ms of delay.


Install
-------
Double-click install.cmd and allow it to make changes. It installs the
driver and creates the eleven cables. Running it again updates the driver.

THIS IS A TEST BUILD unless this folder has no splitter-test.cer file. A
test build is signed with a test certificate, not by Microsoft, and Windows
only loads it in test-signing mode:

  1. In an administrator Command Prompt:  bcdedit /set testsigning on
     (Secure Boot must be off for this; some games' anti-cheat refuse to
     run in test mode.)
  2. Restart the PC.
  3. Run install.cmd.

To leave test mode later: bcdedit /set testsigning off, and restart.


Remove
------
Double-click uninstall.cmd. It removes the cables and the driver.
"uninstall.cmd -RemoveCertificate" also removes the test certificate.


Licence
-------
MIT (LICENSE.txt). Parts of the driver come from Microsoft's
SimpleAudioSample (Windows-driver-samples) under the Microsoft Public
License (LICENSE-MS-PL.txt).

The source code is at https://github.com/LudaLunizz/Splitter
