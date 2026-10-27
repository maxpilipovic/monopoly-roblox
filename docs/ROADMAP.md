# Roadmap

## Done

- [x] **UI overhaul** merged (2026-10-02).
- [x] **Blender models:** pieces, houses, hotels, dice, emblems, card and tile art, icons.
- [x] **Sounds:** synthesised sheet plus licensed recordings, lobby music.
- [x] **Scenes, lobby revamp, progression, Crazy Chance.**
- [x] **College map = EIU** (Charleston names, decks, emblems, EIU Campus scene), merged 2026-10-26.
- [x] **College models uploaded:** hangout, sub, pizza, care package emblems and the panther statue (2026-10-26).
- [x] **Store:** Robux buys coin packs only; coins (also earned from games and challenges) or chest keys open the chests (2026-10-26).

## Release checklist (agreed 2026-10-26), in order

1. [ ] **The Monopoly name and board.** The Classic map uses Hasbro's street names (Boardwalk, Park Place…), the "Chance" and "Community Chest" deck names, and the City scene has a MONOPOLY neon sign. Give the game its own name, original Classic street names and deck names. Jimmy John's on the College board carries a smaller version of the same risk.
2. [ ] **Two-client multiplayer test** (never done): Studio → Test → Clients and Servers, 2 players. Start a game, trade, bankrupt, game over.
3. [x] **Upload the pending Blender models** (done 2026-10-26).
4. [ ] **Coin pack products:** create the Pouch (49), Bag (149), Pile (399) and Vault (999) Developer Products in the Creator Dashboard and paste their ids into `src/shared/Store/Products.luau`. Until then the packs only test-buy in Studio. Doing this from a script needs the API key to have the *Developer Products* API system with write access; the current key only has Assets.
5. [ ] **DataStores:** turn on Studio access to API services (Game Settings → Security) and test that coins, unlocks and Elo save and load.
6. [ ] **Dashboard settings:** server size 25 (Places → Configure → Server size; can't be set from code), and the content maturity questionnaire, answered honestly (no alcohol).
7. [ ] **Phone layout.** On a portrait phone the trade window is clipped and the side panels collide. Most Roblox players are on phones.

## After launch

- **Ranked at scale:** ranked matchmaking only matches within a server. Add a cross-server queue (MemoryStoreService) that teleports each match to a reserved server. Needs a published game to test.
- **Small follow-ups:** the minor items in `docs/superpowers/plans/*.followups.txt`.
