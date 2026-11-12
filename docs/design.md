# O Síndico: design and tools

How the game works inside, for anyone who wants to understand the code or write cards. To install and play, see the [README](../README.md). An original Beater Studios card decision game: the player is the newly elected building manager (síndico) of a Brazilian apartment building and answers one request at a time. `sindico_game` is the plugin identifier, chosen to make clear it is a game. The game is written in Portuguese and translated into English and Spanish (see Languages): code, file names, card ids, flags and keys are in English.

## Languages

The language follows KOReader's: the first two letters of its language setting (`pt_BR` is `pt`), and English for any language the game does not have (`Content.language_from`).

- **Portuguese is the source.** The decks, endings, characters and help in `data/` are written in Portuguese and hold everything the engine reads (effects, flags, requirements).
- **English and Spanish are layers** in `data/i18n/<language>/`: `decks/<deck>.lua` (keyed by card id, with `text` and each choice's `label`, `result` and `minutes`), `endings.lua` (keyed by ending id, with `title` and `text`), `characters.lua` (`name` and `role`) and `help.lua` (the same list as `data/help.lua`). `Content.load(dir, lang)` puts the layer's texts over the Portuguese ones; nothing else changes.
- **Interface texts** are in `data/i18n.lua`, in the three languages, checked by `tools/check_texts.lua` (pattern texts).
- **Translations adapt the humor.** A Brazilian expression or joke that would not land is replaced by one that gets the same laugh in that language, in the character's voice. The building stays in Brazil: prices in reais, apartment numbers, names. Forms of address are adapted (Dona Neide is Mrs. Neide and Doña Neide), and the cat is Admiral in English. Spanish is neutral Latin American.
- **The validator** checks every layer: every card, ending, character and help item exists with the same fields, `minutes` only where Portuguese has them, the same letter limits, no dashes, and Spanish never left identical to English where Portuguese differs. `luajit tools/validate.lua --only <language>/<deck>` checks one deck file while translating.
- **Buttons and headings** are in sentence case in every language: only the first letter is a capital, besides names ("Falar com Kleber", "Talk to Kleber").

## Premise

You have just been elected building manager of Edifício Primavera, a 12 storey building. Each card is a resident, an employee or a supplier with a request, and you pick one of two answers. The tone is a comedy of manners: recognizable and dry, with no cruelty, no party politics, no real people and no brands.

## Rules

- **Four meters**, from 0 to 100, starting at 50: **Moradores** (residents, `residents`: approval), **Caixa** (funds, `funds`: the building's money), **Prédio** (building, `building`: the state of the construction) and **Paciência** (patience, `patience`: your sanity).
- **Any meter at 0 ends the game**, with its own ending. A high value never loses the game: a meter very high only unlocks specific cards (full funds draw suspicion and requests for works, for example).
- **Time:** each decision moves 12 days forward, unless the card says otherwise. A term (mandate) has 720 days.
- **Meetings:** the accounts meeting on day 360 and the election on day 720. At the election, Residents must be at 50 or more for a reelection.
- **Terms:** at each reelection, the meters move a third of the way back to 50, the cards go back to the deck and negative effects get 15% stronger. Winning 5 terms leads to the manager for life ending.
- **Memory:** decisions set facts (flags) that unlock later cards and schedule consequences, sometimes months later.
- **Minutes (ata):** the record of notable decisions (the `minutes` field of the choices, about a quarter of them), with the term and month. It can be read during the game, from the card footer, and on the ending screen. It sums up the story of the game.
- **Gallery:** the endings found are kept between games, with the records. The record counts completed terms, including the last one in a win, and the days of each term stop at 720.

## Card format

The decks are in `data/decks/` as plain Lua tables, loaded in an empty environment. `data/manifest.lua` lists the deck files.

```lua
{
    id = "chickens_302",            -- unique, snake_case, in English
    char = "neide",                 -- key in data/characters.lua
    text = "O vizinho de cima está criando galinhas na varanda. Ou você resolve, ou eu resolvo.",
    left = {
        label = "Multar",           -- button label
        result = "A multa chegou. As galinhas ficaram.",  -- shown at the top of the next card
        effects = { funds = 5, residents = -5 },           -- residents, funds, building, patience
        set = { "chicken_war" },                           -- flags to set (optional)
        clear = { "x" },                                   -- flags to clear (optional)
        next = "another_card",                             -- the very next card (optional)
        schedule = { card = "egg_in_elevator", days = 60 }, -- scheduled consequence (optional)
        minutes = "Multou o criador de galinhas do 402.",  -- goes into the minutes (optional)
        ending = "ending_id",                               -- ends the game (optional)
        days = 30,                                          -- days this choice takes (optional, wins over the card's)
    },
    right = { label = "Conversar antes", result = "...", effects = { patience = -8 } },
    requires = {                    -- optional
        flags = { "a" }, not_flags = { "b" },
        min = { funds = 70 }, max = { residents = 30 },
        day_min = 100, day_max = 500, mandate_min = 2,
    },
    weight = 1,                     -- relative chance in the draw (1 by default)
    days = 12,                      -- days the decision takes (12 by default)
    chain = true,                   -- only comes through next or schedule, never in the draw
    at_day = 360,                   -- mandatory card from this day of the term on
    once_ever = true,               -- shows up only once in the whole game
}
```

A card shows up at most once per term. The election card has `resolve = "election"` on both choices.

**Text limits,** checked by the validator in letters: `text` up to 240, `label` up to 22, `result` up to 90, `minutes` up to 80, and the `text` of endings up to 420. What decides whether a text fits is the measurement with the screen font, in `check_layout.lua`.

**Characters** (`data/characters.lua`): `{ neide = { name = "Dona Neide", role = "moradora do 302" } }`, with the portrait in `assets/portraits/<id>.png`. **How to play** (`data/help.lua`): a list of `{ title = "...", text = "...", figure = "answers" }`, where `figure` (optional: `answers` or `meters`) adds an example under the step; translations only hold the texts.

**Endings** (`data/endings.lua`):

```lua
{ id = "bankruptcy", trigger = "zero:funds", title = "...", text = "...", requires = { flags = {...}, not_flags = {...} } }
```

The ending screen shows the whole building for endings without a `trigger` and for `all_mandates`, and the cracked building for the others. `good = true` or `good = false` changes that for one ending. The `no_cards` ending only counts in the gallery after it is reached.

`trigger` is one of `zero:residents`, `zero:funds`, `zero:building`, `zero:patience`, `election_lost`, `all_mandates`, `no_cards`, or none (when the ending is only reached through `ending` in a choice). For the same trigger, the first ending in the list whose requirements match wins, so the specific ones come before the generic one.

## Screens

Every screen is laid out by `ui/screen.lua` on a canvas (`ui/canvas.lua`) in the units of a 600x800 page, scaled to the real screen and centered, and painted by the one window, which finds in the canvas tap areas what was tapped. The canvas notes every text that does not fit the room it was given, and `check_layout.lua` reports them. The mockups the screens came from are made by `tools/sindico/make_mockups.py`, in the `kindle` project.

- **Home:** the building, the name, and a dark block that continues the game in progress (term, month and the four meters) or starts the first one, then the menu in a grid, with Settings.
- **Cards:** the meters on top, with arrows after each decision (one for a small change, two for 10 points or more), the card in a frame with the portrait, the name, the role and the request, the two answers and a footer with the minutes, the term as a strip of months and the menu. A long request gets a smaller portrait, so it always fits.
- **What a decision led to,** in one of two styles chosen in Settings (`result_style`):
  - **Highlighted** (the default): after the tap, a screen with the card shrunk to a summary, the answer chosen and, in large type, what it led to and the meters that changed, with **Next card** (or a swipe). The result shows where the eye already is, at the cost of a tap per decision.
  - **On top of the card:** the next card opens with a note on top, with the portrait of who you answered, your answer, what it led to and the meters that changed. No extra tap.
- **Ending:** a "new ending" badge the first time, the building (cracked for the bad endings), the title, how many endings were found, the text, the numbers of the game in three tiles and the way on.
- **Minutes:** a page of a minutes book, with a heading for each term and the month in the margin.
- **Gallery:** the endings as a collection, three to a row: the endings found as tiles with their title (the newest with a badge) that open the full text, and the others locked. Every tile has the icon of how its ending is reached: the meter at zero, a ballot box for a lost election, a crown for the full terms, cards for the cards running out and a book for an ending a story leads to (no `trigger`).
- **How to play:** numbered steps, two of them with an example (the answer buttons and the meters), from the `figure` of each item in `data/help.lua`.
- **Settings:** the result style, with a small drawing of each, the status strip on or off (`show_status`) and the language, which follows KOReader.
- **Status strip:** the date, the time (in 12 hours when KOReader is set so) and the battery in the bottom right corner of every screen, read again on each tap and swipe; only the strip is updated, outside the count of updates, and there is no timer.
- **Buttons and headings** are in sentence case in every language: only the first letter is a capital, besides names. Choice labels are held as plain phrases in the cards, and the screen only makes sure the first letter is a capital (`ui/sentence_case.lua`, with `letters.lua` for accented capitals).
- **Starting over** asks first, on a dialog over the faded home screen, and says that the gallery and records stay.
- Always in portrait (`portrait.lua`). Opened in landscape, the game turns the screen and gives the rotation back on closing, also when opening fails; rotation requests during the game are ignored. An opening that fails shows a notice, and the error goes to the KOReader log. A screen that fails to paint is logged and leaves the taps working.
- **E-ink updates:** each layout is a kind in the `refresh.lua` counter, with a limit of 8: home (with the dialog), play (a card and the result of a decision share it, so playing does not flash at each tap), ending, the paged screens and settings. Changing layout flashes the screen; a decision or a page turn updates without a flash, and the ninth update in a row flashes. A reelection and waking up the device flash too.
- **Back key,** on devices with keys: from a card, the settings or the dialog to the home screen, from a result to the next card, from a paged screen to where it was opened, from an ending to the home screen, and from the home screen it closes the game. KOReader's `Close` event only closes the window.
- **Sleep screen:** if the device sleeps with the game open and the KOReader sleep screen is set to the book cover, `assets/screensaver.png` shows up instead. It works by wrapping KOReader's `Screensaver.setup`: KOReader chooses the image as usual, and the game only swaps it when its screen is the full-screen window on top. No setting is written, so closing the game brings the book cover back. Powering off, restarting or any other mode changes nothing. The image is 1200x1600, twice 600x800, to stay sharp on larger screens; on 600x800 screens KOReader halves it.

## Structure

```
sindico_game.koplugin/
  _meta.lua, main.lua          KOReader registration
  sindico_game/
    engine.lua                 rules and reading back saves, independent of KOReader
    content.lua                loads data/
    ui/screen.lua              every screen
    ui/canvas.lua              layout in page units, tap areas and the texts that do not fit
    ui/sentence_case.lua       sentence case for the choice labels
    screensaver.lua            game cover on the sleep screen
    portrait.lua               portrait while open, rotation given back on close
    refresh.lua                chooses between updates without a flash and full ones
    saved_state.lua            defaults, lists and protected restore for saves
    letters.lua                UTF-8 letters: split, accents and case
  data/i18n.lua                interface texts in the three languages
  data/i18n/<language>/        English and Spanish texts of the cards, endings, characters and help
  data/
    manifest.lua               list of decks
    characters.lua, endings.lua, help.lua
    decks/*.lua                cards
  assets/                      portraits, SVG icons, the building and the sleep screen cover
  tools/, tests/, docs/        development, outside the published package
```

`portrait.lua`, `refresh.lua`, `saved_state.lua`, `letters.lua`, `screensaver.lua`, `tools/package_lib.sh`, `tools/data_check.lua`, the `run_*.sh`, `check_all_sizes.sh`, `fuzz.lua` and the `check_*.lua` of `tools/koreader` other than `check_layout.lua`, and the two workflows are shared by the Beater Studios plugins and copied unchanged: each starts with a `Pattern` comment, and a change goes to all plugins at once. What is only O Síndico's in `tools/koreader` is `check_layout.lua`, `fuzz_ui.lua` and `render_screens.lua`.

## Saved state

Everything lives in `koreader/settings/sindico_game.lua`, written with `flush` after every decision:

| Key | Contents |
|---|---|
| `game` | the game in progress: `version`, `meters`, `day`, `mandate`, `decisions`, `current` (the card on screen), `used` and `used_ever` (cards seen in this term and in the whole game), `flags`, `queue` (scheduled cards and their day), `minutes` (term, month, card and side of each entry), `last` (the card, side and meter changes of the last decision) and `last_char` |
| `stats` | the records and the gallery: games, decisions, best terms, best days, how many times each ending was seen and the newest ending found (`newest_ending`, for the gallery badge) |
| `result_style` | where the result of a decision shows: `highlight` (a screen of its own, the default) or `note` (on top of the next card) |
| `show_status` | whether the date, time and battery show in the corner (`true` by default) |

The minutes and the last decision keep the card and the side, not the text, so a game in progress follows a change of language; saves before 1.1.0 kept the Portuguese text, which `Engine:restore` keeps as it was. The saved game is a copy of the engine state, so later moves never change what was handed to the settings. `Engine:restore` reads it back checking every part: invalid meters (a meter at zero included), day or term drop the game, cards that left the content are removed from the used cards and the queue, the minutes and the last result are read item by item, and a current card that left is drawn again. It runs inside `SavedState.restore`, so a save that slips through the checks is dropped and the screen still opens. A dropped game leaves the save, and the records stay. `Engine.restore_stats` reads the records field by field, so a field added later gets its default in an old save. A finished game leaves the save, so Continue never reopens an ending. `version` goes up only when a field changes meaning; games saved by 1.0.x have none and count as version 1. `tests/saves/<version>.lua` holds real saves of published versions, and `tests/state_spec.lua` and `check_layout.lua` open each of them.

## Tools

- `sh tools/check.sh`: every check that runs without KOReader, the same in CI: `tools/validate.lua`, the tests, `tools/simulate.lua 1000` and the package. The release runs `sh tools/check.sh release`, which does the same.
- `luajit tools/check_texts.lua strings`: the interface texts in `data/i18n.lua` have the same keys and markers in the three languages, no dash and no brand of e-reader, and every text the code asks for exists.
- `luajit tools/validate.lua`: checks the hand-written data and its translations with `tools/data_check.lua`: unknown keys (a typo such as `min_day` would be ignored by the engine), whole numbers, text limits in letters, references in both directions (cards, endings, characters and flags), reachability, the election cards, a generic ending for each trigger, the characters, the help and the portraits. It loads the data through the game's own `content.lua`.
- `luajit tools/simulate.lua [games]`: plays thousands of games with random and careful choices and shows how long they last, the endings reached and the cards never seen.
- `luajit tests/engine_spec.lua`: engine tests (effects, draws, chains, scheduled cards, requirements, elections, terms, minutes, records and sentence case).
- `luajit tests/state_spec.lua`: saving and restoring, content that left, damaged saves, old records and the saves of published versions in `tests/saves/`.
- `sh tools/package.sh`: builds `dist/sindico_game.koplugin.zip` and its checksum with the steps of `tools/package_lib.sh`. Requires `LICENSE`, `NOTICE` and the cover, stops if a file the code loads is missing from the package, and the same files always give the same zip, byte for byte.
- With `KOREADER_DIR` pointing to a desktop KOReader (the folder with `luajit` and `reader.lua`; on a Mac, `KOReader.app/Contents/koreader`), from the plugin folder:
  - `tools/koreader/run_emulator.sh` opens the game in a 600x800 window, with the virtual keyboard on and its settings in `.ko-home`.
  - `tools/koreader/check_all_sizes.sh` runs `check_layout.lua` at four screen sizes, in the three languages: every card, label (as shown, in sentence case), result, ending and character measured with the screen fonts, the fixed-width interface texts at their longest values, 14 games played through the screen in each language, the gallery turning to its second page, the version on the About screen, a game resumed in a new screen, the refresh modes, the Back key and the `Close` event, and every save in `tests/saves/` and a damaged one opened through the screen.
  - `tools/koreader/run_headless.sh tools/koreader/check_rotation.lua` opens the game with KOReader in landscape and checks portrait, the ignored rotation and the rotation given back, also when opening fails.
  - `tools/koreader/run_headless.sh tools/koreader/fuzz_ui.lua` sends random taps, holds and swipes to the home screen, a card, an ending, the gallery, the minutes, how to play and About, in each language, with a paint after each, deciding by a swipe one step in three on a card. An error prints the command that repeats it (`SEED`, `ACTIONS`, `ONLY`).
  - `tools/koreader/run_headless.sh tools/koreader/check_screensaver.lua` checks when the game cover replaces the sleep screen image.
  - With `OUTPUT_DIR`, the scripts save screenshots; `OUTPUT_DIR=docs/screenshots tools/koreader/run_headless.sh tools/koreader/render_screens.lua` makes the English README ones (also used by the brand art), and `SCREENS_LANG=pt OUTPUT_DIR=docs/screenshots/pt ...` the Portuguese ones.
- `python3 -I tools/make_art.py` draws the portraits and the building in `assets/`. Needs Pillow. It holds the art as drawing code, so it is under the content license (`NOTICE`). The icons are hand-written SVG, in `assets/icons/`.
- `KOREADER_DIR=<desktop KOReader> python3 -I tools/make_brand_art.py` draws the icon, the README banner and the GitHub social preview (`docs/social-preview.png`) from the README screenshots, in the same style as the other Beater Studios plugins. Run `render_screens.lua` first. Needs Pillow. With `screensaver` as argument it draws `assets/screensaver.png` instead, in the same style.

The emulator does not show what is specific to e-ink, nor the device speed: the final check is on a real device.

## Content

266 cards in 8 decks (`assembly`, `residents`, `repairs`, `money`, `front_desk`, `arcs`, `meters`, `veteran`), 18 characters, 15 arcs with scheduled consequences and 25 endings, 24 of which count in the gallery.

With 5,000 simulated games, a random player lasts about 38 decisions (median) and seldom gets past the first term; a player who looks after the meters usually reaches the 4th or 5th term and wins them all in about 11% of the games. The `no_cards` ending is only a safety net and does not show up in practice.

## Characters

Each character has a voice of their own, kept in every card and result. The humor comes from that voice meeting an ordinary building problem, and it should be clear on a first read: a concrete detail beats a clever closing line.

| Character | Voice |
|---|---|
| Seu Osmar, accountant | Anxious and exact: amounts to the cent, percentages, "calculei", fear said out loud, "o senhor". |
| Márcia, deputy manager | Corporate jargon (benchmark, roadmap, alinhados, case), polite ambition, keeps a note of everything you refuse. |
| Seu Valdir, caretaker | Practical and modest, fixes with whatever is at hand (a popsicle stick, a nylon stocking, a bucket), "o senhor". |
| Dona Neide, 302 | Gossip and surveillance, her notebook, knows everyone's business and threatens to use it. |
| Dona Carmem, former manager | "No meu tempo" and "meu filho", her 1998 notebook, keys to everything, wants the post back. |
| Kleber, day doorman | Honest without a filter: tells residents and visitors exactly what he thinks, "o senhor". |
| Pri, night doorwoman | Calm and dry, exact times after midnight, "já vi coisa pior". |
| Seu Ademir, 601 | Numbered rules and times to the minute, formal complaints in two copies. |
| Pedrinho, 507 | Short words and fragments; "tá" is the whole answer. |
| Nelson, elevator technician | "Isso é normal", always, with a quote for an upgrade. |
| Dr. Rogério, 801 | Legal register, invented laws and precedents, notifies everything. |
| Rafael, 902 | "Meu querido", friendly schemes with a cut for himself. |
| Tia Lurdes, 105 | "Meu bem", sweet pressure, offers cake before you answer. |
| Capitã Renata, firefighters | Deadlines, "não é pedido", writes everything down. |
| Professora Yara, 404 | Dignity, art and her brooch; protests in music. |
| Beto, Sunday barbecue | "Chefe", meat as diplomacy, the smoke is part of the experience. |
| Jéssica, 1204 | Followers, content and partnerships, everything is a video. |
| Almirante, the cat | Never speaks: the cards describe him, and he always wins. |

Residents without a card of their own (Dona Lúcia of the 903, the chickens of the 402, the 701 and his ladders) come back across cards; keep their details consistent.

## Writing cards

- `at_day` cards fire in a row once one variant is used, because the engine only marks that specific card. Variants of the same meeting use a flag of their own, set at the accounts meeting and cleared at the election.
- When no eligible card is left, the engine releases the common cards already used in the term again, but never the `at_day` ones.
- The `schedule` queue is emptied at a reelection. Cards that open arcs have `day_max` and `once_ever`, so the outcome fits in the term.
- `clear` runs before `resolve_election`. For the defeat ending to depend on a flag, clear the flag in a card of the next term, not at the election.
- Choices that lead to a special ending have bad effects on purpose, otherwise the careful player would prefer them.

## License

The code is under GPL-3.0, version 3 only. The content (cards, characters, story and art: `data/`, `assets/`, `docs/screenshots/`, `docs/brand/`, `docs/social-preview.png` and `tools/make_art.py`) is under CC BY-NC-SA 4.0. Details in `NOTICE`.

## How to release a version

1. Update `version` in `_meta.lua` and add the version section to `CHANGELOG.md`, as `## [1.2.3]`.
2. Run `sh tools/check.sh`, the emulator checks (`check_all_sizes.sh`, `check_rotation.lua`, `fuzz_ui.lua` and `check_screensaver.lua`) and test on a device.
3. If the version changes the save format or the cards, save a game with the published version in the emulator and keep it as `tests/saves/<published version>.lua`.
4. Publish the `v1.2.3` release on GitHub, creating the tag with it, after the push. The `release.yml` workflow checks the tag against `_meta.lua`, runs `tools/check.sh release`, builds the package and attaches every zip in `dist/` with its checksum. If the release notes are empty, it fills them with the `CHANGELOG.md` section. If it fails because of the code, delete the release and the tag (`gh release delete v1.2.3 --cleanup-tag`), fix it on `main` and publish again.
