# Master Angler

Fishing quality of life addon for WoW Forever.

## Features

- Fishing set: save the worn gear and swap to it with fishing mode. The old gear returns when the mode ends.
- A swap asked in combat runs when combat ends.

## Install

```
make link WOW_DIR="/path/to/World of Warcraft/_forever_"
```

Use `make install` to copy the addon instead of a link.

## Commands

- `/masterangler` or `/masterangler help` lists all commands.
- `/masterangler savegear` stores the worn gear as the fishing set.
- `/masterangler mode` turns fishing mode on or off.

## Languages

enUS (also enGB), deDE, esES, esMX, frFR, itIT, ptBR. Other locales use enUS.
The translations were written by the agent. No native speaker reviewed them.

## Development

`make deps`, `make test`, `make lint`, `make fmt-check`, `make coverage`.
Manual checks are in `docs/manual-checklist.md`.

## License

MIT, see `LICENSE`.

## CI and release

- `.github/workflows/ci.yml` runs luacheck, stylua, busted with coverage and a package build on each pull request and each push to `main`.
- `.github/workflows/release.yml` publishes to CurseForge and GitHub on a tag `v*`.
- Before the first release, add `## X-Curse-Project-ID: <id>` to the TOC and the `CF_API_TOKEN` repository secret.
- Keep the TOC `Version` equal to the top `CHANGELOG.md` heading.
