# Caw DPS Meter 1.1.0

Released September 8, 2026. This update brings player details, talent trees and
per-window settings, along with a revised interface for both large and minimal meters.

**September 9 hotfix (still 1.1.0):** Damage and healing tooltip percentages now
use the player's full total, including pets and totems. Pet and totem contributions
also show their percentage. Recorded totals were already correct.

**1.1.0 download updated:** optional aggro warnings are now included. If you
already installed 1.1.0, download it again and use `/reload` after replacing the files.
Under **Settings > Threat**, enable Screen glow, Warning sound, or both. Defaults
are 90% server threat and an eight-second cooldown; both effects start disabled.
Warnings trigger when your own threat rises above the threshold or you gain aggro,
using existing server data even while the meter is hidden. They do not repeat
continuously while you remain above the threshold. Use **Test warning** to preview
the enabled effects. Settings apply to your character across all Caw windows.

**Upgrading from 1.0.9:** restart the game after installing so the client loads
the new addon modules. Existing saved settings and combat recordings are kept.

Caw now has a player analysis window with Caw's dark raven
artwork, charcoal panels and muted gold accents. Left-click a player bar to open it in that
window's selected mode and segment. Browse players, completed fights and Overall,
search abilities, sort by name or contribution, and click an ability for its
recorded totals, hits, critical hits, share and average. Owned pet abilities show
their source. Missing statistics display `--`; server threat does not provide a
spell-by-spell breakdown. The Overall dataset contains completed fights.

The main meter and additional windows use near-black pfUI-style surfaces,
fine borders, muted gold highlights and raven artwork. Dropdown entries have
bright 12-pixel text; narrow mode lists use shorter labels with full-label
tooltips and keep the width of their selector. A separate footer keeps
totals clear of player bars. The background uses a solid texture and respects
the chosen opacity. Opening one dropdown closes the others; hiding a meter or
opening Settings clears its menus.
Player bar fills retain their class hue at a darker brightness, with white
names, ranks and values for contrast. This also applies to additional windows
and the appearance preview; class-coloured names remain an optional setting.

The sliders icon opens per-window settings; right-clicking a player bar or using
`/cawoptions` also opens them. General, Window, Bars, Text, Threat and pfUI
pages cover scale, dimensions, row fitting, bar height/spacing, font size,
background/bar/watermark opacity, class icons, ranks, name colours and values.
New windows start with room for five bars. Existing saved dimensions are retained.
Sliders and number fields provide precise adjustments; checkboxes control display
options. A preview follows the current settings. The window selector identifies
which meter is being edited. Spells use icons from the player's or pet's spellbook
when available, with a question mark for unknown icons. The detail pane shows
statistics relevant to the selected mode.
Copy an appearance to all open windows, restore default appearance, lock/dock a
window or choose pfUI chat switching. Settings are smaller and scaled to 85%.
The Visible bars control sets the row count without a separate five-bar preset.
Report and reset stay in the header, or in its **...** menu in narrow windows. Reset actions
require confirmation. Encounter dropdowns match the width of their selector.
Melee attacks use a sword icon in both the spell list and the detail pane.
Player, segment and spell arrows are disabled when the list fits or reaches an end.

Narrow meters automatically use a three-control header: mode, encounter and **...**.
Settings, New window, Report, Reset, Lock and Close remain available in that menu.
Encounter dropdowns give each entry the full width; short lists shrink to fit,
and longer lists have scrolling controls above and below. Full selector labels
remain available on hover. Small player bars abbreviate amounts and omit extra
rate/share columns; Threat prioritises its percentage. Names have priority over
icons in these small rows. Wider windows restore the saved display preferences.

The footer is a drag area, as is empty background. Shift-dragging a player bar
also moves its window without opening details on release. Ordinary clicks retain
their actions. Locking and pfUI docking still prevent movement; the resize grip
stays separate. Mode summaries are aligned to the right of the footer.
Large totals and rates use k/M abbreviations, such as 300k or 1.25M. The text
adapts to the available space; hover for the full total and DPS/HPS to one decimal.

Report > Whisper opens a recipient field. A player target prefills the name;
Use target updates it explicitly, or you can type another character's name.
The report and initial recipient are frozen when the dialog opens, so changing
targets, modes or fights while typing cannot redirect the report. Send submits
the header, up to five players and the total; Cancel and Escape send nothing.

Talents beside the spell search opens three talent trees within player details.
Names, icons, positions and ranks come from the owning client's talent API.
Group members running this viewer send tree details on request over Caw Sync;
regular rank sync then updates the received layout. Both clients need this new
feature. Older clients may provide point totals without tree names and icons.
The view is read-only and identifies current versus last received information;
it does not reconstruct the player's build during a selected historical fight.
Missing information is shown explicitly. No website access or fixed character
database is required in-game, and the regular calibration rank packets remain intact.

Overall no longer switches to Current when combat begins. Automatic switching is
an explicit per-window preference. An open analysis keeps its selected completed
fight even as new history entries arrive; Current is marked stale after a new
fight instead of silently mixing its data with the next encounter.

Threat calculation, reference sampling and talent sync continue. The optional
DPSLog adapter is included; a compatible native DLL is installed separately.
This addon archive does not install a DLL or modify the launcher. It includes
the intervening local server/pet/totem fixes and snapshot event cursors.
The maintainer's private group/talent-status overlay is excluded.

The interface uses the combat data available on Vanilla. Charts,
target-by-target damage data and player comparison panels remain future work.

Validation: 279 combat/data regressions, 161 UI checks, 38 alert checks and ten two-client
talent/threat sync scenarios pass against the public package. Checks include
every mode and encounter selection in main and additional windows, compact
menus, window reuse, reports, settings and pfUI layering. The ZIP is checked
for integrity and excludes the private maintainer display. Mock-data renders
were reviewed, and the maintainer confirmed the latest layout in-game.
Automated checks simulate the client; they do not cover every native UI setup.
