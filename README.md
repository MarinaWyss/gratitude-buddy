# Gratitude Buddy

A small macOS menu-bar companion. Roughly once an hour, one of three buddies slides up in the
bottom-right corner, floating above whatever you're working on, and asks two things:

1. **What's here right now?** Tap a few feeling words, or type your own.
2. **Anything to be grateful for, right now?** Something small is enough. "Nothing today" is a fine answer.

Then it says thanks and slides away.

<p align="center"><img src="docs/buddies.png" width="560" alt="Skwisgaar, Toki and Appa"></p>

## The buddies

They take turns, one per check-in:

- **Toki**, a fluffy black cat
- **Skwisgaar**, a sleek black cat
- **Appa**, a cream golden retriever

Each has three expressions. They look calm while greeting you, curious while you answer, and content
once you're done. **Meet the buddies** in the menu shows all three side by side, and **Check in with**
lets you summon one by name.

<p align="center"><img src="docs/card.png" width="376" alt="The check-in card"></p>

About one check-in in three also carries a short reflection on the feelings step, along the lines of
*"Remember, it's later than you think"* or *"Today is all we ever really have."* A gentle memento mori,
in a gratitude register rather than a grim one.

## Privacy

Everything stays on your Mac. Each completed check-in is appended to a plain Markdown file at
`~/Library/Application Support/Gratitude Buddy/journal.md`, which you own and can edit or delete.
Nothing is sent anywhere, and dismissing a check-in stores nothing. An entry looks like this:

```markdown
## Friday 19 Sep 2026, 14:02
- Feeling: calm, tired
- Grateful for: the light coming through the window
```

## Install

Needs the Xcode command-line tools on macOS 14 or later. No Xcode project required.

```bash
./build.sh
cp -R "build/Gratitude Buddy.app" /Applications/
open "/Applications/Gratitude Buddy.app"
```

Then click the paw in the menu bar and turn on **Open at login**. If you rebuild later, copy the new
build into Applications again, or the login item keeps launching the old one.

## The menu (the paw in your menu bar)

- **Next check-in around …** shows when it will appear next.
- **Check in now** brings a buddy up immediately.
- **Snooze 15 minutes** and **Pause until tomorrow** (resumes at 9 am).
- **Meet the buddies** and **Check in with** Toki, Skwisgaar or Appa.
- **Open journal** opens the Markdown file.
- **Soft sound** toggles the quiet pop on arrival.
- **Open at login** registers it as a login item.

## Behaviour details

- The interval is random between 50 and 70 minutes, so it never feels like a metronome.
- "Not now" brings it back in 30 minutes instead of a full hour.
- Esc dismisses. The panel never steals focus from the app you're in, but you can type into it.
- If the Mac was asleep past the scheduled time, it waits five minutes after wake.
- If you've been away from the keyboard for more than five minutes, it waits until you're back.
- If it sits ignored for 15 minutes it slides away on its own.
- Drag the card anywhere by its background.
- The card is always light, whatever your system appearance, because the illustrations are drawn for white.

## Changing the art

The buddies are PNGs in `Resources/buddies/`, one per character and mood:
`toki-neutral.png`, `toki-curious.png`, `toki-happy.png`, and likewise for `skwisgaar` and `appa`.
Replace a file and rebuild to change the art. A missing mood falls back to neutral, and a missing
character falls back to a simple drawn version.

To make a new one from an illustration on a plain white background:

```bash
./cutout.sh my-drawing.png Resources/buddies/toki-curious.png dark
```

It lifts the subject out with macOS's built-in subject detection, trims it, and scales it for the app.
Pass `dark` for the black cats so the white fringe on soft fur edges is removed too. The app icon is
rendered from Toki's neutral image at build time.

## Tweaking the words and timing

- Feeling words, greetings, and the reflection lines are in `Sources/CheckInModel.swift`. The chance of a
  reflection appearing is next to the list.
- Card copy is in `Sources/BuddyView.swift`.
- Timing is in `Sources/Scheduler.swift`.
- `./preview.sh` renders every buddy in every mood, plus each step of the card, into `build/preview/`,
  so you can check a change without waiting for a pop-up.
- To test the real thing quickly:

```bash
BUDDY_INTERVAL_SECONDS=15 "/Applications/Gratitude Buddy.app/Contents/MacOS/Gratitude Buddy"
```

- To open straight to the meet card:

```bash
"/Applications/Gratitude Buddy.app/Contents/MacOS/Gratitude Buddy" --meet
```
