# BananaSplit side of Splitter

`bananasplit-changes.patch` holds the changes made to BananaSplit (the
`windows/` app, its READMEs and its CI) so it uses Splitter cables: strip N
records `Splitter N Output`, VB-Audio stays the fallback, `@default` never
follows Windows into a Splitter cable, and CI jobs build this driver.

The patch is against BananaSplit `main` at 7bf7a2d (v2.8.0). It also adds
CI jobs and a release workflow that expect Splitter in a `splitter/` folder
of that repository. To apply it there:

    git apply --3way bananasplit-changes.patch
