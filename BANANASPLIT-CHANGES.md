# BananaSplit side of Splitter

BananaSplit's app side of Splitter is in BananaSplit itself, from 2.8.3 on
(`windows/src/win/route.rs`, `chanmenu.rs`, `cables.rs`): strip N records
`Splitter N Output`, bus B1 plays into `Splitter B1 Input`, VB-Audio stays
the fallback, `@default` never follows Windows into a Splitter cable, and
Menu › Virtual cables… shows which Splitter cables are installed. It finds
the cables by the names in `windows/driver/Source/Main/Splitter.inx`, so
those names must not change without BananaSplit changing too.

The window's "Splitter download page" button opens this repository's
releases (`SPLITTER_PAGE` in `route.rs`). If the repository moves or is
renamed, that link must change too.

`bananasplit-changes.patch`, the app-side patch against 2.8.0 that this
file used to describe, is in this repository's history (commit 12f6620).
