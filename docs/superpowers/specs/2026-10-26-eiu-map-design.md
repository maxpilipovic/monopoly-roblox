# EIU map — design

Agreed with the owner on 2026-10-26. The owner is an EIU alum (Sigma Pi, Beta-Gamma chapter). This
document is a **baseline**: the owner will rewrite names and card jokes after seeing it in game, so
keep every name and every line of card text in data tables that are easy to edit.

## Intent

The College map today is the classic board with generic campus names (`Tiles.luau` COLLEGE_NAMES,
`Cards.luau` COLLEGE_TEXT). The trains, the bulb and tap, the scenery and the Crazy Chance deck are
all classic, so starting a College game doesn't feel like college. The owner wants a map that feels
like **Eastern Illinois University and Charleston, IL**: real campus buildings and town spots, the
bars as the railroads, frat-life humour on the cards (bailing your buddy out of jail is the kind of
joke he wants), Blender-made art, and the EIU campus around the table.

## Goals

1. ~~A new map, **EIU**, alongside Classic and College.~~ Changed by the owner on 2026-10-26 after the
   build: the **College** map *is* the EIU map (ids `college.*`, map id "College"); the generic campus
   content is gone and the picker offers only Classic and College.
2. Every tile renamed for EIU / Charleston (table below). Prices, rents, colour sets and positions
   are classic.
3. EIU text for all 16 Chance and 16 Community Chest cards (same effects as classic, like College),
   with new deck titles.
4. Its own **EIU Crazy Chance deck** (16 cards), including two new effects.
5. Blender art: new tile emblems for the hangouts and the delivery spots, new card pictures, and
   hero models for the scenery.
6. A new scene, **EIU Campus**, which is always the scenery for an EIU game.

## Non-goals

- No rule changes. Prices, rents, house costs and the classic decks' effects are untouched.
- No new sounds.
- Ranked stays on the Classic map (unchanged: `RoomSettings.ranked` fixes `map = "Classic"`).
- No changes to the generic College map or to the classic Crazy deck.

## Anti-goals (would make this a failure even if it works)

- **The experience must not need a Restricted (18+) rating.** Roblox classes "the presence of
  alcohol" as Restricted. So:
  - Bars appear **by name only** and are called **hangouts**, never bars. No drinks, bottles, beer
    mugs, kegs, drinking, being drunk, blacking out, hangovers, drinking games or fake IDs, anywhere:
    text, emblems, card art or scenery.
  - Chaos is fine: arrests, bail, parties, police breaking things up, pranks, ghosts, wrong-house
    mornings.
- **No hazing jokes** (paddles, pledge abuse). The owner's own chapter is on the board.
- **No official EIU logos, seal, wordmark art or the Billy the Panther mascot design.** Names of
  buildings and places in plain text are fine. A generic panther statue in the scenery is fine.

## Constraints

- Builds on Crazy Chance, which is uncommitted on `feat/crazy-chance` today. That work must be
  committed and merged first; EIU goes on its own branch from `main` (builder's call on the name,
  e.g. `feat/eiu-map`).
- Follow the existing per-milestone workflow and the Studio-MCP / Rojo notes in project memory
  (tests run via the RunTests attribute hook; restart Rojo after project-file node changes).
- Icons and art are Blender renders, never emoji (`Hud/Icons.luau`, `tools/blender/*.py`, exports in
  `assets/export`, uploads via `assets/upload.config.json` → `asset-ids.json`).
- Keep the 60° overhead board view; the scene must not crowd the board.

## The board (decided as a baseline; owner will edit)

| Pos | Classic | EIU |
|---|---|---|
| 0 | Go | **Move-In Day** |
| 1 | Mediterranean | Carman Hall |
| 2 | Community Chest | Care Package |
| 3 | Baltic | Thomas Hall |
| 4 | Income Tax ($200) | **Tuition Bill** |
| 5 | Reading RR | **Marty's** |
| 6 | Oriental | Taylor Hall |
| 7 | Chance | Saturday Night |
| 8 | Vermont | Lawson Hall |
| 9 | Connecticut | Pemberton Hall |
| 10 | Jail | **Coles County Jail** (Just Visiting) |
| 11 | St. Charles | Coleman Hall |
| 12 | Electric Co. | **Jimmy John's** |
| 13 | States | Lumpkin Hall |
| 14 | Virginia | Blair Hall |
| 15 | Pennsylvania RR | **Ike's** |
| 16 | St. James | Campus Pond |
| 17 | Community Chest | Care Package |
| 18 | Tennessee | Student Rec Center |
| 19 | New York | MLK Union |
| 20 | Free Parking | **Tailgate Lot** |
| 21 | Kentucky | Lake Charleston |
| 22 | Chance | Saturday Night |
| 23 | Indiana | Lincoln Log Cabin |
| 24 | Illinois | The Square |
| 25 | B&O RR | **Stu's** |
| 26 | Atlantic | Greek Court |
| 27 | Ventnor | Sorority Row |
| 28 | Water Works | **Pagliai's** |
| 29 | Marvin Gardens | **Sigma Pi House** |
| 30 | Go To Jail | **Busted on 4th St** |
| 31 | Pacific | Doudna Fine Arts |
| 32 | North Carolina | Lantz Arena |
| 33 | Community Chest | Care Package |
| 34 | Pennsylvania Ave | Booth Library |
| 35 | Short Line | **PBox** |
| 36 | Chance | Saturday Night |
| 37 | Park Place | O'Brien Field |
| 38 | Luxury Tax ($100) | **Parking Ticket** |
| 39 | Boardwalk | **Old Main** |

- Deck titles: Chance → **Saturday Night**, Community Chest → **Care Package**, Crazy →
  **Crazy Night**.
- Railroads are "hangouts" and utilities are "delivery" wherever the game names the kind (CardFace
  nouns: classic `railroad`/`utility`, college `shuttle`/`utility`; EIU `hangout`/`delivery`).
- Property colour sets keep their classic colours (readability). The board's base and centre take
  EIU blue and grey instead of the classic green (`BoardBuilder` TILE/BASE/CENTER colours become
  per map). Exact shades are the builder's call.
- "PBox" is the owner's name for a Charleston bar; the web couldn't confirm it. Use it as written.

## The cards (decided as a baseline; owner will edit)

Ids follow the College pattern: `eiu.<classic id>` for Chance and Chest, `eiu.crazy.<name>` for the
EIU crazy deck. Positions in text must match the table above. "Pass Go" becomes "pass Move-In Day".

### Saturday Night (Chance) — classic effects

| Classic id | Text |
|---|---|
| chance.dividend | Won the cornhole tournament at the tailgate. Collect $50. |
| chance.loan | Your refund check finally hits. Collect $150. |
| chance.speeding | Parking Services got you again. Pay $15. |
| chance.boardwalk | Graduation day! Advance to Old Main. |
| chance.go | Back to Move-In Day. Collect $200. |
| chance.illinois | The Panther Parade heads uptown. Advance to The Square. If you pass Move-In Day, collect $200. |
| chance.stCharles | You actually went to class. Advance to Coleman Hall. If you pass Move-In Day, collect $200. |
| chance.reading | The boys are at Marty's. Head over. If you pass Move-In Day, collect $200. |
| chance.railroad1 / railroad2 | The group chat says the party moved. Advance to the nearest hangout. If it is owned, pay the owner double. |
| chance.utility | Late-night munchies. Advance to the nearest delivery spot. If it is owned, roll and pay the owner ten times the roll. |
| chance.jailFree | Your frat brother's dad is a lawyer. Get out of Coles County Jail free. Keep this card until needed. |
| chance.back3 | Forgot your Panther Card. Go back 3 spaces. |
| chance.jail | Caught climbing the Old Main tower. Go to Coles County Jail. Do not pass Move-In Day, do not collect $200. |
| chance.repairs | The party got out of hand. Pay $25 per house and $100 per hotel. |
| chance.chairman | Elected chapter president. Pay each player $50 for the formal. |

### Care Package (Community Chest) — classic effects

| Classic id | Text |
|---|---|
| chest.taxRefund | Textbook buyback at the Union. Collect $20. |
| chest.bankError | Financial aid office error in your favor. Collect $200. |
| chest.doctor | Health Services copay. Pay $50. |
| chest.stock | Sold your old futon. Collect $50. |
| chest.go | Back to Move-In Day. Collect $200. |
| chest.jailFree | Mom's on speed dial. Get out of Coles County Jail free. Keep this card until needed. |
| chest.jail | Pulled the fire alarm in Carman Hall at 3 a.m. Go to Coles County Jail. Do not pass Move-In Day, do not collect $200. |
| chest.holiday | Summer job at Lake Charleston pays off. Collect $100. |
| chest.birthday | It's your birthday. Collect $10 from every player. |
| chest.lifeInsurance | Grandma's card had a $100 bill in it. Collect $100. |
| chest.hospital | Slept through your final in Lumpkin. Pay $100 to retake it. |
| chest.school | Lab fees due. Pay $50. |
| chest.consultancy | Tutored a freshman in Booth Library. Collect $25. |
| chest.streetRepairs | Greek Court housing fines: pay $40 per house and $115 per hotel. |
| chest.beautyContest | Second place in the Homecoming lawn display contest. Collect $10. |
| chest.inherit | Care package from home with $100 hidden in the cookies. Collect $100. |

### Crazy Night (EIU Crazy Chance deck)

On the EIU map, the crazy draws (a third of Chance draws, when Crazy Chance is on) come from this
deck instead of the classic crazy deck. Fourteen reuse existing crazy effects; two are new.

| Id | Effect | Text |
|---|---|---|
| eiu.crazy.wrongHouse | SwapWithLeader | Woke up in the wrong house after the party. Swap places with the richest player. |
| eiu.crazy.ghost | Scatter | Mary Hawkins was seen on Pemberton's 4th floor. Everyone runs to a random square. |
| eiu.crazy.oneWay | Reverse | Someone flipped the one-way signs on 4th Street. Play goes the other way round. |
| eiu.crazy.allNighter | ExtraTurn | All-nighter in Booth and you're still going. Take another turn. |
| eiu.crazy.philanthropy | RobinHood (200) | Philanthropy week: the richest player pays the poorest $200. |
| eiu.crazy.raffle | Lottery (50) | Chapter raffle! Everyone puts in $50 and one lucky player takes the pot. |
| eiu.crazy.alumni | Collect (500) | A rich Sigma Pi alum is feeling generous. Collect $500. |
| eiu.crazy.houseFund | SplitCash | House meeting: everyone's cash goes in the house fund and is split evenly. |
| eiu.crazy.composite | Heist | Your pledge class stole the rival house's composite. Take a random unbuilt property from the richest player. |
| eiu.crazy.roomSwap | SwapDeed | Room swap! Trade one of your unbuilt properties for a random one of someone else's. |
| eiu.crazy.alumniWeekend | FreeHouse (100) | Alumni weekend: they build you a free house on one of your sets. No set? Collect $100. |
| eiu.crazy.inspection | Demolition | Surprise housing inspection! Every street with buildings loses a house. |
| eiu.crazy.noiseComplaint | MassArrest | Noise complaint sweep. Charleston PD takes everyone else to Coles County Jail. |
| eiu.crazy.brothersPitchIn | Jailbreak | The brothers pool their cash. Everyone in Coles County Jail walks free. |
| eiu.crazy.bailBuddy | **BailOut (100)** — new | Your buddy got arrested trying to steal the Ike's sign. Bail him out: pay $100 for each player in jail, and they walk free. Nobody locked up? He's arrested now: a random other player goes to jail. |
| eiu.crazy.blockParty | **RaidKind (Railroad)** — new | Charleston PD breaks up the 4th Street block party. Everyone standing on a hangout goes to Coles County Jail. |

New effects (in `CrazyCards.luau`, added to `CrazyCards.KINDS`, using the existing `Ops`):

- **BailOut (amount):** for each other non-bankrupt player in jail, the drawer pays `amount` (via
  `charge`, creditor the bank, so it can bankrupt the drawer like any fee and feeds the Free Parking
  pot if that rule routes bank fees there) and that player is released. If nobody else is in jail, a
  random other player (`state.random`) is jailed with `jail`. Each jailed player is released as soon
  as their bail is charged, whether `charge` pays it on the spot or records it as a debt; an unpaid
  bail is then an ordinary debt (Debt phase, possibly bankruptcy) and the release stands. No deferred
  release in the Engine. Jailed players are handled in seat order. (Claude's call: keeps it inside
  `CrazyCards.apply`.)
- **RaidKind (tileKind):** every non-bankrupt player standing on a tile of that kind (the drawer
  included, if they're on one) goes to jail with `jail`. If nobody is, nothing happens and the event
  text says so.

Both emit events the HUD can describe (`EventText.luau`), like the other crazy effects.

## Blender art

All made in Blender through the existing pipeline (`tools/blender/*.py` scripts, FBX into
`assets/export`, renders into `assets/cards` / `assets/tiles`, uploaded, ids in `asset-ids.json`).
Style matches the existing emblems and card art.

**Tile emblems** (`EmblemLook` per map; models in `ReplicatedStorage.Assets.Emblems`):

- **Hangout** (the four hangouts): a neon "OPEN" sign or a jukebox, builder's pick. Never a drink.
- **Sub** (Jimmy John's) and **Pizza** (Pagliai's): a sub sandwich and a pizza box.
- **CarePackage** (Care Package tiles): a taped cardboard box. Saturday Night keeps the gold
  question mark.

**Card pictures** (`CardArt`, keyed per EIU card id; EIU cards may reuse classic pictures where
they fit, e.g. Signpost for advance-to cards). New pictures at least for: handcuffs/bail (jail and
bail cards), a ghost (Pemberton), the Old Main tower, a pizza box, a care package, a panther paw
print (generic, not the EIU logo). The builder may add more.

**Scene hero models:** Old Main (the turreted castle), a generic panther statue, and any other
building that procedural Kit blocks can't do justice (builder's call).

## EIU Campus scene

A new `Scenes.LIST` entry and `SceneKit/EIUCampus.luau`, like the other four.

- The table sits on the **Library Quad lawn** on an **autumn evening**: orange and red trees, brick
  paths, iron lamp posts, warm windows.
- Around it: **Old Main** as the backdrop (Blender model), the **Campus Pond** with water, the
  **panther statue**, Booth Library's gothic front, Doudna's angular glass, and **O'Brien Field**
  stadium lights in the distance. Blue and grey banners on the lamp posts (plain colours or the
  words "Eastern Illinois" in a plain font, no logo).
- Gentle moving parts like the other scenes (leaves drifting, the pond, flickering lamps). No NPCs.
- Rules: an EIU game always uses this scene. The lobby's scene picker shows "EIU Campus" locked while
  the map is EIU. EIU Campus is not offered for other maps (builder's call; easy to lift later).
  `RoomSettings.validate` enforces the pairing on the server.

## Plumbing (where things change)

- `Tiles.luau`: add the EIU name list and map, `Tiles.MAPS` gets "EIU"; `MatchSettings` MAPS and
  `mapLabel` get "EIU".
- `Cards.luau`: EIU text tables; per-map crazy deck (`buildMap` takes the crazy entries instead of
  always using CRAZY); titles for EIU.
- `CrazyCards.luau`, `Engine.luau`, `EventText.luau`: the two new effects.
- `CardFace.luau`, `CardArt.luau`: the `eiu.` prefix (today they special-case `college.`; generalise
  to a per-map lookup rather than adding a second prefix check).
- `EmblemLook.luau`, `TileEmblems.luau`: shape per map.
- `BoardBuilder.luau`: per-map board colours.
- `Scenes.luau`, `SceneBuilder.luau`, `SceneKit/EIUCampus.luau`, `RoomSettings.luau`, `LobbyHud.luau`:
  the scene and its pairing with the map.
- Tests alongside the existing ones (`BoardBuilder.spec`, `Cards.spec`, `CardFace.spec`,
  `CardArt.spec`, `CrazyChance.spec`), including a check that every EIU card's text names the tile
  its effect moves you to.

## Left to the builder

Branch name and milestone order; exact colours; emblem shapes within the rules above; which card
pictures to reuse; scene layout and lighting values; event wording for the new effects; whether to
also apply EIU names to corner tile art beyond the words (the corners keep their classic pictures).

## Decided by Claude, not the owner (owner to check)

- Repurposing nothing: EIU is a third map, College unchanged (owner confirmed).
- Which building goes on which colour set, and Old Main in Boardwalk's spot.
- Deck titles Saturday Night / Care Package / Crazy Night.
- Utilities as Jimmy John's and Pagliai's. Note: **Jimmy John's is a national trademark** (same
  takedown risk as the Classic map's names, roadmap item 6). The owner should decide before
  publishing; swapping the name is a one-line change.
- EIU Campus locked to the EIU map.
