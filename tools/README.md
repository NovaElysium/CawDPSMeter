# tools

Maintainer scripts. Not shipped with the addon.

## commit-update.ps1

Run after extracting a colleague's ZIP over the addon folder. It restores the
`.toc` metadata lines the ZIP overwrites, syncs the version from the `## Title`
line, adds a `Co-authored-by` trailer for the colleague, shows the diff, then
commits and pushes after you confirm.

Set `$CoAuthorEmail` near the top of the script to his GitHub no-reply address
so he shows up as a contributor. Until then commits go through without it.

```powershell
.\tools\commit-update.ps1 -Message "rc50: fixed CC segment bug"
```
