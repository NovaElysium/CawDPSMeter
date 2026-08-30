# tools

Maintainer scripts. Not shipped with the addon.

## commit-update.ps1

Run after extracting a colleague's ZIP over the addon folder. It restores the
`.toc` metadata lines the ZIP overwrites, syncs the version from the `## Title`
line, shows the diff, then commits and pushes after you confirm.

```powershell
.\tools\commit-update.ps1 -Message "rc50: fixed CC segment bug"
```
