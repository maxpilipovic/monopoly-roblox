# Roadmap

What's next, in the order agreed on 2026-10-02. Tick items off as they land.

1. [x] **Merge the UI branch.** The UI overhaul, move pacing, side-view camera, current-player-only deed card and the jail announcement go to `main`.

2. [ ] **Blender models.** Token pieces, houses, hotels, dice, a jail cell, and a go-to-jail animation.
   - Set up Blender with the blender-mcp add-on and add the server to Claude Code.
   - Pipeline test: one model from Blender into Roblox end to end, before designing the rest.

3. [ ] **Phone layout.** On a portrait phone the trade window is clipped and the side panels collide. Needed before a mobile release.

4. [ ] **Sounds.** Dice, token hops, card flip, purchase, your-turn chime. Needs audio assets from the Creator Store or uploaded.

5. [ ] **Small follow-ups.** The minor items in `docs/superpowers/plans/2026-10-01-ui-overhaul.followups.txt` (and the earlier `*.followups.txt` files).

6. [ ] **Before publishing.** A two-client multiplayer test (never done), and a decision on the Classic map's Monopoly names, which risk a takedown.

## Before publishing (added 2026-10-19)

- **Robux chests:** create the Silver (49), Gold (149) and Diamond (399) Developer Products in the Creator Dashboard and paste their ids into `src/shared/Store/Products.luau`. Until then the chests only test-open in Studio. Doing this from a script needs the API key to have the *Developer Products* API system with write access; the current key only has Assets.
- **Server size:** set the server size to 25 in the Creator Dashboard (Places → Configure → Server size). It can't be set from code. Roblox opens new servers as they fill, so thousands of players spread across many 25-player servers.
- **Ranked at scale:** ranked matchmaking only matches within a server. With 25-player servers, add a cross-server queue (MemoryStoreService) that teleports each match to a reserved server. This needs a published game to test.
- **DataStores:** turn on Studio access to API services (Game Settings → Security) and test saving and loading before launch.
- **Two-client test** and the **Classic map names** decision (from item 6 above).
