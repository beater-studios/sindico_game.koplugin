# Changelog

## [1.1.1]

- Fewer repeated cards: a card you have not seen yet in the game is three times as likely to be drawn. In the second term, repeats go from about a quarter of the cards to about one in nine, and the difficulty stays about the same. A game in progress gets this too.

## [1.1.0]

- A new look for every screen. The home screen shows the game in progress, the gallery is a collection of the endings found and the ones still locked, each with the icon of how it is reached, the minutes are a page of a minutes book, an ending shows the numbers of the game, and how to play shows examples.
- What a decision led to shows in large type, on a screen of its own after the tap, or as a note on top of the next card: you choose in the new Settings screen.
- The date, the time and the battery in the corner of every screen, updated with each tap. They can be turned off in Settings.
- Buttons and headings have only the first letter in capitals.
- The game is also in English and Spanish, following the language of KOReader (English for any other language). The jokes were adapted for each language, and the building stays in Brazil. A game in progress follows a change of language, minutes included.
- On devices with keys, the Back key goes back one screen and closes the game from the home screen.
- If the game cannot open, a notice shows up instead of KOReader closing, and the screen rotation goes back to what it was.
- The screen flashes to clear what e-ink leaves behind after nine updates in a row, in the lists too, and when the device wakes up.
- A saved game that no longer fits (from a version with other cards, or a damaged file) is dropped without losing the records and the gallery. Games in progress from 1.0.x carry on.
- Reviewed card texts: jokes that were hard to get, vague one-liners, repeated lines and lines in the wrong character's voice were rewritten.
- The sleep screen cover has a new look, in the style of the other Beater Studios games.
- Portraits are saved at 600 px and fill the room the question leaves in the card, so they show larger and stay sharp on big screens.
- Touched up portraits. The frame sits on the edge with nothing showing outside it, the clothes show where the arms meet the chest, items reach the bottom of the frame instead of floating, and the floating key and pencil are gone. Faces: the nose shows above mustaches and beards, the hairline no longer runs past the hair, earrings hang from the ears, stubble stays on the face and the forehead lines that looked like a second pair of brows are gone. Hair: the bald sides grow above the ears, Pedro's spiky hair fills his headphones, the ponytail and long hair have clean outlines, combed hair follows its curve and Dona Carmem's white hair stands out from her face. Clothes: open collars, t-shirts and dresses show the neck, dresses have buttons and the necklace sits under the chin, aprons and Renata's uniform stand out from the outlines and the background. The hats close against their brims, the headphones are gray against the hair and Almirante's collar sits around his neck.

## [1.0.2]

- With the game open, the sleep screen shows the O Síndico cover instead of the book cover.

## [1.0.1]

- Winning all 5 terms now counts 5 completed terms on the ending screen and in the record, not 4.
- The days of a game stop at 720 per term, and the month shown never goes past 24.
- A choice can set its own `days`. Kleber's "Tirar uns dias" now takes 30 days, as intended.
- The gallery no longer counts the `no_cards` safety ending, which never shows up in play, so it can now be completed.
- Endings reached through a choice show the whole building, and the `good` field of the endings now works.
- With no eligible cards left, the engine never repeats the accounts meeting nor the other `at_day` cards.
- The validator rejects unknown keys, values that are not whole numbers, an invalid `resolve`, an election card with only one side and a character without a portrait.

## [1.0.0]

First public version.

- 266 cards in 8 decks, 18 characters, 15 arcs with scheduled consequences and 25 endings.
- Four meters, terms with residents' meetings and elections, the game minutes and a gallery of endings.
- Progress saved after every decision.
- About screen with the version, authorship and licenses.
- Always in portrait: opened in landscape, the game turns the screen and restores the rotation on closing.
