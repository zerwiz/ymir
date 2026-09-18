## runtime · unversioned · 2026-09-16 — app packaging prepared under the @ymir scope (Amendment C, part one)

### Why
- **Scoped names.** `apps/odrerir` was `ymir-odrerir` and `apps/sessrumnir` was
  bare `sessrumnir`; both are now `@ymir/odrerir` and `@ymir/sessrumnir`.
- **Publishable metadata on all four apps** (hlidskjalf, hlidskjalf-mobile,
  odrerir, sessrumnir): `license`, `repository`, `publishConfig.access: public`,
  a `files` surface, and `prepublishOnly` where a build exists.
- **Measured with `npm pack --dry-run --ignore-scripts`:** hlidskjalf 1.3 MB /
  21 files, odrerir 2.3 MB / 15, sessrumnir 4.0 MB / 116, hlidskjalf-mobile
  2.0 kB / 4 (source only — it has no build script). `dist/ymir.apk` is excluded
  by `!dist/*.apk`: it took the hlidskjalf tarball from 1.3 MB to 14.5 MB, and
  npm is not an APK channel.
- **`private: true` stays until the Allfather's word** — nothing can publish by
  accident; the flip is one line per app.
- The app repos were already registered in `$YMIR_HOME/identity/projects.yaml`
  (`zerwiz/{hlidskjalf,hlidskjalf-mobile,odrerir,sessrumnir,smidja}`).
- `no-mistakes` is initialized for this repo (`no-mistakes init`): the clean-PR
  gate now has its local remote. The vendored skill copy stays — it is the
  canonical tree the skill index names.

### Files
- *(carried from the frozen CHANGELOG.md)*
