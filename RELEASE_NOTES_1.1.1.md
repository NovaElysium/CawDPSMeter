# Caw DPS Meter 1.1.1

Released September 10, 2026. This maintenance release adds a side-by-side
player comparison and polishes the new detail and hover views.

Player details now include a **Compare** button. It lists only other players
with the same class and shows both totals, ability values, contribution shares
and the difference between the two players. Damage from pets owned by either
player stays attached to that player's total and is labelled by source where
the ability list contains it.

The comparison view takes over the detail window while it is open, so two large
dialogs do not cover one another. Closing it restores the player, segment,
selected spell and search state that opened the comparison. The selector menus
are compact and the **Talents** and **Compare** buttons have separate slots.

The comparison table has clearer spacing around its headings and divider. Hover
breakdown text is vertically centered in each bar. Spell icons use the expanded
local database together with the client's spellbook and available runtime APIs,
so more combat-log abilities resolve without a question-mark icon.

Under **Settings > pfUI**, **Keep Caw behind inventory windows** provides a
manual fallback for other bag addons that do not expose a frame Caw can detect.
It is disabled by default and applies per character; disabling it restores the
normal foreground layer.

No additional combat-log commands or server data are required for comparison;
it reads the combat data already stored by Caw. A `/reload` after replacing the
addon files is sufficient for existing installations.

Validation: 281 combat/data regressions, 158 UI checks, 25 release-UI checks
and 38 threat-alert checks pass with the mocked Vanilla client APIs. The public
archive excludes the local maintainer overlay and any saved variables.
