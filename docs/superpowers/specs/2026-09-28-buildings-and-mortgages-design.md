# Buildings and Mortgages — Design

Milestone 4, part 1 of 3 (then debt/bankruptcy/win, then trading). Agreed in conversation on 2026-09-28.

## Goal

Players can build houses and hotels, sell them back, and mortgage and unmortgage property. They do it through a HUD "Properties" panel, bots do it too, and houses and hotels appear on the board. Official Monopoly rules apply, except for the choices recorded below.

## Decisions

| Topic | Decision |
|---|---|
| When | Only on your own turn, in the **Roll** or **EndTurn** phase (before rolling or after your move is settled). Never during BuyDecision, Auction or GameOver. Allowed while in jail. |
| UI | A **Properties** button opens a panel listing your deeds grouped by color set, railroads and utilities last. Each row shows its state and only the actions legal right now, with prices. The panel is view-only when it isn't your turn. No clicking on board tiles. |
| Bots | "Simple and steady": before rolling, first unmortgage when rich, then build evenly on the cheapest full set while keeping the cash reserve. They never mortgage voluntarily. |
| Rules location | A pure shared module, `PropertyRules`, is used by both the engine (validation) and the HUD (which buttons to show), so the UI never offers an illegal action. |

## Rules

Terms:
- **Set:** all Property tiles of one color group.
- **Houses:** each property has `houses` 0–4 houses, or 5 = hotel.

- **House price** depends on the board side:
  - $50 for positions 1–9
  - $100 for 11–19
  - $150 for 21–29
  - $200 for 31–39

  A hotel costs one more house price, and the 4 houses go back to the bank.
- **Bank supply:** the bank starts with 32 houses and 12 hotels. Building takes from the supply; selling returns to it.
- **Build** on property P is legal when all of these hold:
  - you own every property in P's set;
  - nothing in the set is mortgaged;
  - P has fewer than 5 buildings;
  - P's building count equals the lowest in the set (build evenly);
  - you can afford the house price;
  - the bank has a building: for 0–3 houses → 4, it needs at least 1 house; for 4 houses → hotel, it needs at least 1 hotel.
- **Sell a building** on P is legal when:
  - you own P and it has buildings;
  - P's count equals the highest in the set (sell evenly).

  You receive half the house price. Selling a hotel turns it back into 4 houses: the hotel returns to the bank and 4 houses come out, so it needs at least 4 houses in the bank. If the bank has fewer, the sale is refused. This is a simplification: officially you would break the hotel down further.
- **Mortgage** P is legal when:
  - you own P and it is not mortgaged;
  - if P is a Property, no property in its set has any buildings.

  You receive half of P's price.
- **Unmortgage** P is legal when you own P, it is mortgaged, and you can pay the mortgage value plus 10%, rounded up. For example, $30 → $33 and $75 → $83.
- **Rent:** already correct. Mortgaged properties charge no rent. A full set doubles the base rent of its unimproved, unmortgaged properties, even if another property in the set is mortgaged. Built properties use their house rent.
- **Out of scope:**
  - auctioning houses when they run short;
  - the 10% transfer interest on mortgaged property changing hands (belongs with trading);
  - raising cash while in debt (part 2).

## Engine

- **State:** `GameState` gains `bankHouses: number` and `bankHotels: number`.
- **Actions:** each is `{ type = ..., position = number }`:
  - `Build`
  - `SellBuilding`
  - `Mortgage`
  - `Unmortgage`

  The engine validates the phase, that the actor is the current player, and the rules through `PropertyRules`. A rejected action changes nothing and returns a reason.
- **Events:** each has `player`, `position` and `amount` (money paid or received), plus `hotel: boolean` on building events:
  - `Built`
  - `BuildingSold`
  - `Mortgaged`
  - `Unmortgaged`

  Money moves as `Paid` events with reason `"Building"` or `"Mortgage"`, the same as other payments.
- **Snapshot:** gains `bankHouses` and `bankHotels`. Properties already carry `houses` and `mortgaged`.

## `PropertyRules` (shared, pure)

Works from a plain view: `properties: { [position]: { owner, houses, mortgaged } }`, `bankHouses` and `bankHotels`. The engine builds this view from `GameState`, and the HUD builds it from the snapshot. It provides:
- `housePrice(position)`, `mortgageValue(position)`, `unmortgageCost(position)`
- `canBuild(view, playerId, money, position) -> (boolean, reason?)`, and the same shape for `canSell`, `canMortgage` and `canUnmortgage`
- `setPositions(group)`, which lists a color set's positions

## Client

- **`HudModel.propertyRows(snapshot, localId)`:** a pure function returning the local player's deeds in board order, grouped by set. Each row has a name, group, houses, mortgaged, and a list of `{ label, action }` for the actions legal right now; the list is empty when it isn't the player's turn or phase.
  - Labels: `+🏠 $50`, `+🏨 $50`, `−🏠 +$25`, `−🏨 +$25`, `Mortgage +$30`, `Unmortgage $33`.
- **`HudView`:**
  - a Properties toggle button in the action bar;
  - a scrolling panel, rebuilt on every render while it's open.
- **`EventText`:** log lines for the four events.
- **`BuildingLayout.spot(position, index)`, shared:** where house `index` (1–4) or the hotel (index 5) sits on a tile's color band. The spots stay on the band and don't overlap.
- **`Buildings`, a client view:** keeps small green house parts, or one red hotel part, on each property in step with the snapshot. It creates and destroys parts; there's no animation.

## Bots

In the Roll phase, before any jail choice or rolling, the bot tries these in order:
1. Unmortgage the cheapest mortgaged property it owns if `money - cost >= 3 × CASH_RESERVE` ($450).
2. Build on the lowest-priced legal property among its full sets, if `money - housePrice >= CASH_RESERVE`.
3. Otherwise, the existing jail and roll logic.

Each call returns one action; the bot loop repeats until the bot rolls.

## Testing

- **`PropertyRules.spec`:**
  - house prices by side;
  - even building and even selling;
  - bank running out of houses or hotels;
  - selling a hotel when the bank has fewer than 4 houses;
  - mortgage blocked by buildings in the set;
  - unmortgage cost rounding;
  - not the owner, and a set that isn't complete.
- **Engine spec:**
  - each action works in Roll and EndTurn;
  - each is rejected in BuyDecision, in an auction, and on another player's turn;
  - money, bank counts and events are correct;
  - a rejected action leaves the state unchanged;
  - rent after building and after mortgaging.
- **Bot spec:**
  - unmortgage and build choices and their reserve thresholds;
  - the all-bot game must now include at least one `Built` event.
- **Other specs:** `HudModel` rows and labels, `EventText` lines, `BuildingLayout` spots, and `Snapshot` bank counts.
- **Playtest in Studio:**
  - build through the panel;
  - houses appear on the board;
  - mortgage, then unmortgage;
  - bots build.
