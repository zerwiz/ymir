## smidja · unversioned · 2026-09-17 — the smithy's dependency names the package npm will actually serve

### Why
- **`@zerwiz/smidja` is published and not served.** npm accepted it twice (0.1.0,
  then 0.1.1): the tarball and the version document existed, the package document
  never did, and a republish of 0.1.0 was refused as *"previously published"*. The
  name answers `404`, the website `403`, while `@zerwiz/hlidskjalf`,
  `@zerwiz/odrerir` and `@zerwiz/sessrumnir` resolve normally and always have.
- **A second free name failed identically.** `@zerwiz/smidja-factory` was published
  and shows the same shape — version served, package document withheld. Two names,
  one behaviour, while packages published yesterday serve fine: the withholding is
  npm's, not the name's, and the CLI does not report it.
- **The distro depends on the name that can resolve.** `optionalDependencies` now
  names `@zerwiz/smidja-factory`, so the moment npm serves that package the smithy
  arrives with the rest. Being optional, it is skipped silently until then — the
  plan's phase-5 row is what says so out loud.
- **`@zerwiz/ymir` 0.1.7** — the version published once this lands.

### Files
- *(carried from the frozen CHANGELOG.md)*
