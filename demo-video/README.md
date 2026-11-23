# IronFit demo video (Remotion)

2:00, 30 fps, H.264. Chapters: member, coach, administrator. Two formats from the same code: 1920x1080 (`Demo`) and 1080x1920 (`DemoVertical`).

```bash
npm install
npm run studio            # live preview
npm run render            # out/demo-2min.mp4
npm run render:vertical   # out/demo-2min-vertical.mp4
npm run audio             # regenerate the music and sound effects
```

- **Text, colors, durations, audio paths, demo data:** `src/config.ts`. Keep durations multiples of 15 frames (1 beat at 120 BPM). If the total length changes, the music needs regenerating: `DUR`, `BREAKS` and `section` in `scripts/generate-audio.mjs`.
- **Scenes:** `src/scenes/` (one file each). **Shared motion:** `src/lib/anim.ts`. **Brand tokens:** `src/theme.ts`.
- **Music and effects:** replace the files in `public/audio`. The current ones are synthesized by `scripts/generate-audio.mjs`, with no third-party samples.
- **Logo layers:** `python scripts/split-logo.py ../app/assets/images/ironfit_logo.png` (needs Pillow and NumPy).
- **Voiceover:** see `voiceover.md`.

The phone screens are rebuilt in React from the Flutter screens; names and figures are demo data. There are no store badges because the app is not published on a store.

Licenses: Remotion is free for individuals and small teams, paid for larger companies (remotion.dev/license). Fonts: Archivo and Roboto (SIL Open Font License). Icons: Lucide (ISC).

Finished videos: `video/ironfit-demo-2min.mp4` and `video/ironfit-demo-2min-vertical.mp4` (compressed copies; full-quality renders go to `out/`, which is not versioned). `public/audio/music.wav` is not versioned either: `npm install` generates it when missing. If you use your own track, remove that line from `.gitignore` so it is committed.
