# Sunder identity

Sunder is broad enough for messaging, quality-of-life and future optional modules. Use Sunder as the platform name and Sunder Chat where a specific module needs a name.

The master emblem is a dark, bevelled stone tablet split by a jagged amber rune fracture. Its near-black silhouette, weathered steel and localized molten light should read at minimap size. Avoid adding text, ornate flourishes, noisy detail or glow around every UI control.

- Master: `assets/branding/Sunder-master.png` (original generated artwork, preserved).
- Publishing icon: `assets/branding/Sunder-project-icon.png` (512×512 PNG).
- Addon list: `Media/Brand/SunderIcon.tga` (256×256 RGBA).
- Minimap: `Media/Brand/SunderMinimap.tga` (64×64 RGBA).
- Settings: `Media/Brand/SunderSettings.tga` (512×512 RGBA).

Run `python tools/build_icons.py` after an approved master change. Derivatives use antialiased resampling and uncompressed true-color TGA; no runtime image libraries are needed. The master was generated for this project from the owner's visual brief. Existing small action icons retain their consistent monochrome theme and original attribution.

Runtime body surfaces remain sleek and borderless with horizontal edge fades. Default amber accents can inherit Ellesmere styling; user color/font overrides take precedence. The brand emblem belongs in the launcher, addon list and settings overview, not as repeated window-title branding.
