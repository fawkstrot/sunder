# Typography

Sunder's font controls live under **Chat → Appearance → Typography**. This behavior is implemented for the current WoW Forever client; native visual results still require an in-game check.

## The cascade

With **Inherit Ellesmere font** enabled (default), every Sunder font role first uses Ellesmere's global font. This works with Ellesmere's core alone: the Blizzard Skin child addon and the Sunder skin do not have to be enabled. The font path does not have to be registered in LibSharedMedia.

Without an available Ellesmere font, or with inheritance switched off, the role's saved Sunder font wins. An empty role uses **Sunder fallback font**, followed by the native game font if the selected media is missing. A rejected font file falls back safely rather than leaving the font unset. Font choices are resolved at display time; inheritance never rewrites the saved fallback choices. **Use Sunder fallback** clears a role's explicit face. Existing settings remain intact.

Inheritance covers the typeface. Sunder retains role-specific sizes, outlines, spacing and shadows; it does not indiscriminately apply one text size across differently sized controls. Native alphabet members remain available for Korean, Chinese and Cyrillic. Font-family faces and their Roman members are both synchronized so copied labels and measurements agree.

## Surfaces

- Messages, archives, samples and native Combat Log use the existing shared message font objects.
- Headers, tabs, people lists, cards and notification text use the shared header policy. Unlinked Whispers headers still use the same cascade while retaining their existing size/outline choices.
- Sunder context menus, nested menus and Sunder-origin native chat/link menus use the context-menu role. Blizzard retains menu actions, fitting and pooling.
- Supporting text covers Sunder settings, news, copy/search windows, movement help and Sunder tooltips. Tooltips restore the previous font when hidden. Settings rebuilds are scoped to Sunder; unrelated addons and global GameFont objects are not restyled.
- Accessible native overhead chat bubbles have their own font, size and outline controls, plus an opt-out. Bubble visibility/channel CVars are unchanged. This styles text only, not bubble art.

## Ellesmere custom bubbles

When Ellesmere's custom bubble renderer is enabled, it owns its bubbles. Sunder shows **Ellesmere bubble font**, **Ellesmere bubble size**, and **Ellesmere bubble outline** controls on the same Typography page. These are deliberate edits to that renderer's existing active-profile settings through its capability-checked API; there is no duplicate saved copy. Select **EUI Global Font** to inherit Ellesmere's global face or select its explicit bubble override. Native Sunder bubble preferences remain saved and resume when that renderer is disabled or absent. Native controls are disabled while custom bubbles are active, avoiding two misleading active sets.

Restricted instance bubbles cannot safely be styled by this feature. Sunder skips instance/forbidden frames; it does not read message contents, replace protected bubbles or change which channels display them. Other addons' independent replacement bubble renderers are not claimed as supported.

## Runtime ownership and refresh

`Fonts.lua` owns face resolution, font families, scoped menu/tooltip adapters, native bubble lifecycle and optional custom-bubble controls. `Ellesmere.lua` supplies the optional global font independently of skin activation. Appearance owns the settings schema and exposes one owner per setting.

Changes to Sunder settings, Ellesmere font-cache invalidation, late Ellesmere loads, entering the world and newly registered SharedMedia fonts refresh the cascade. Refresh notifications coalesce onto the next frame. Ellesmere bubble activation/profile refresh also reevaluates ownership. No font polling runs per frame.

Native bubbles use chat events, two coalesced creation passes and a single show hook per observed bubble. Each enumeration is capped at 64 bubbles and descendant inspection at three levels. Weak tables track pooled bubbles and original font state; disabling styling restores only labels still carrying Sunder's font. Forbidden access is guarded and no bubble text is read. There is no native event registration, editor focus, recipient creation, history mutation or input action as a side effect of choosing a font.

Role font objects are reused by role and half-pixel size (6–100 px). Menu descriptions receive scoped initializers; native pool reset owns release. Tooltip snapshots restore only while Sunder still owns the applied font. UI-tree traversal is restricted to explicitly owned Sunder trees and capped at eight levels. Vendored libraries are unchanged.

## Validation

The focused `work/test_fonts.py` regression runs the actual Fonts/Ellesmere implementation through the standard CLI. It covers an absent/late/erroring provider, unregistered external paths, saved role/base/native fallback, a rejected external font, untouched saved preferences, multilingual family members, family-level face consistency, role sizes, live refresh, nested menus/pool reuse, tooltip restoration and foreign-owner preservation, bubble reuse/disable/restricted access/external ownership, explicit delegated bubble settings, bounded scheduling and no idle frame driver. Geometry/settings fixtures use a typography adapter; their existing behavior assertions remain intact. The full suite also covers renderer readback, layout, archives, input, item protection and the existing Fishing work.

Pending live checks after the user reloads safely:

1. Change Ellesmere's global font with its Sunder skin off; check messages, Combat Log, headers, people lists, menus, supporting windows and tooltips.
2. Turn inheritance off and choose distinct Sunder message/menu/bubble fallback fonts. Change sizes/outlines; check narrow windows, wrapping and retained readback.
3. Disable Ellesmere for a reload and verify the saved Sunder choices remain effective. Re-enable and verify inheritance resumes without replacing those choices.
4. Check native bubbles outside instances, repeated pooled appearances and opt-out restoration. Verify restricted/instance bubbles remain native. No agent-generated messages are sent for this check.
5. With Ellesmere custom bubbles active, change their font/size/outline from Sunder; verify their existing settings and bubble layout update. Disable custom bubbles and check Sunder fallback resumes.
6. Reopen menus/submenus and then an unrelated native menu; check fitting, hover/disabled colors and normal native styling. Move from Sunder tooltips to unrelated tooltips. Check multilingual text where available.

Automated results, deployment receipt and actual user observations are tracked separately in CONTEXT.md. No mock test establishes protected-client behavior or visual quality in the running game.
