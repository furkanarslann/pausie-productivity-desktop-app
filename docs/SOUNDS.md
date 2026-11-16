# Sounds

The music bundled in Pausie (`Pausie/Resources/Sounds`) was written for Pausie and synthesized from
scratch by [`Tools/BreakMusic/compose.swift`](../Tools/BreakMusic/compose.swift): no samples, loops or
third-party recordings, so there is no license or royalty to track. Rebuild the files with
`Tools/BreakMusic/render.sh` (needs `ffmpeg`).

| File | Name in Settings | Feel | Key, tempo | Instruments |
| --- | --- | --- | --- | --- |
| `morning-marimba.m4a` | Morning Marimba | Bright marimba hook, like a friendly phone alarm | C major, 118 BPM | marimba, plucked chords, bass, shaker, kick, clap |
| `ukulele-bounce.m4a` | Ukulele Bounce | Island strum with a kalimba tune | G major, 124 BPM | ukulele-style strum, kalimba, bass, shaker, kick, clap |
| `rise-and-shine.m4a` | Rise & Shine | Builds up from bell arpeggios to a full beat | D major, 116 BPM | bells, marimba, pulsing bass, kick, clap, hats |
| `happy-groove.m4a` | Happy Groove | Laid-back swing with a plucked lead | F major, 108 BPM | electric piano, plucked lead, bass, kick, clap, hats |

Every track is 55 s, starts on its hook, ends on a held chord with a 4 s fade, and is normalized to
−18 LUFS with a −3 dB true peak (AAC 128 kbps), so all sounds play at a similar level. They stay in the
midrange (little energy above 4 kHz, soft percussion) so they wake you up without grating.

Until 2026-11-16 (D20) the music was four public-domain classical recordings from Wikimedia Commons
(Satie, Schumann, Bach, Chopin). A setting that still names one of them now plays Morning Marimba.

The macOS chimes (Glass, Hero, Ping, Purr, Submarine, Tink, Bottle, Blow) are not bundled: the app plays
the system's own sounds from `/System/Library/Sounds`.
