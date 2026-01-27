# Release Checklist

Before each release:

- [ ] Update version in `Core.lua`
- [ ] Update `CHANGELOG.md`
- [ ] Update `Systems/WhatsNew.lua` changelog table
- [ ] Commit with message: `chore(release): bump version to X.Y.Z`
- [ ] Create and push tag: `git tag vX.Y.Z && git push origin vX.Y.Z`

## Version Tagging Rules

Follow [Semantic Versioning](https://semver.org/):

| Type | When to use | Example |
|------|-------------|---------|
| **Major** (X.0.0) | Breaking changes, major UI overhauls, saved variable resets | 2.0.0 → 3.0.0 |
| **Minor** (X.Y.0) | New features, new modules, significant enhancements | 3.1.0 → 3.2.0 |
| **Patch** (X.Y.Z) | Bug fixes, small tweaks, spell data updates | 3.1.5 → 3.1.6 |

## Tag Format

Always prefix with `v`: `v3.1.6`

## Quick Release Commands

```bash
# After committing the version bump:
git tag v3.1.6
git push origin v3.1.6
```
