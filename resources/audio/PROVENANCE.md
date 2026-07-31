# Audio provenance and commercial-use boundary

All WAV files under this directory are original procedural output produced by
`tools/generate_audio.py` for Project Rest Two.

- The generator uses mathematical oscillators, envelopes, and seeded noise.
- It does not read, sample, remix, or transform third-party recordings.
- It does not intentionally reproduce a named song, recording, or sound pack.
- `manifest.json` records the generator version, parameters, per-file seed, and
  SHA-256 digest needed to audit or reproduce every delivered asset.
- These assets are intended to be shipped with this project, including in a
  commercial game build.

This provenance record substantially reduces the licensing ambiguity common to
downloaded “royalty-free” assets, but it is not a legal opinion or a guarantee
against every possible third-party claim. The project owner should retain this
file and `manifest.json` with release records and perform normal trademark,
copyright, and platform-policy review before commercial release.

Regenerate the canonical assets from the repository root:

```powershell
python tools/generate_audio.py
```
