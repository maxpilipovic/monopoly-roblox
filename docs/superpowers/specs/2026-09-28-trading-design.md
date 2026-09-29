# Trading — Design

Milestone 4, part 3 of 3 (after buildings/mortgages and debt/bankruptcy). Agreed in conversation on 2026-09-28.

## Goal

On their turn, a player can offer another player a trade of properties, cash and Get Out of Jail Free cards. The receiver accepts or declines. A trade can also be used to raise cash while in debt. Bots judge the offers they receive. Official Monopoly rules apply, except for the choices recorded below.

## Decisions

| Topic | Decision |
|---|---|
| When | Only the player whose move it is may propose: the current player in **Roll** or **EndTurn**, or the debtor at the head of the queue in **Debt**. Never during BuyDecision, Auction or GameOver. |
| Responses | The receiver may only **accept** or **decline** — no counter-offers. The proposer may send another offer after a decline. |
| Spam limit | At most **3 offers per player per turn** (counted whether accepted or declined; reset when the turn ends). |
| Bots | Bots **answer** offers but never propose. |
| Rules location | A pure shared module, `TradeRules`, validates offers for both the engine and the HUD, so the trade window never lets you send an offer the server would refuse. |
| UI | A **Trade** button beside Properties opens a trade window: pick a player, then two columns ("You give" / "You get") with deed toggles, a cash stepper and a jail-card stepper. Untradable deeds are greyed out with a reason. The receiver sees a summary with Accept / Decline. |

## Rules

### An offer

```
offer = {
	to = <player id>,
	give = { properties = { positions }, cash = n, jailCards = n }, -- from the proposer
	get  = { properties = { positions }, cash = n, jailCards = n }, -- from the receiver
}
```

An offer is legal when all of these hold (checked when it is proposed, and again when it is accepted):
- `to` is another player who is not bankrupt;
- at least one thing changes hands (some property, cash above 0, or a jail card on either side);
- every position in `give.properties` is owned by the proposer, and every position in `get.properties` by the receiver, with no position listed twice;
- no traded Property has buildings anywhere in its color set ("sell the buildings in this set first"). Railroads and utilities never have buildings;
- cash amounts are whole numbers ≥ 0, and each side has at least the cash it gives;
- jail-card counts are whole numbers ≥ 0, and each side holds at least as many as it gives;
- the proposer has offers left this turn.

Malformed offers (wrong types, NaN, fractions, negative numbers, unknown players, non-purchasable positions) are refused without changing anything.

### The Trade phase

- When a legal offer is proposed, a `TradeProposed` event is emitted. `state.trade` holds the offer, its proposer and the phase to return to (Roll, EndTurn or Debt). The phase becomes `Trade`, and the proposer's offer count goes up by one.
- In `Trade` the acting player is the receiver. The only actions allowed are `AcceptTrade` and `DeclineTrade`, and only from the receiver.
- **Decline:** emits `TradeDeclined`. The phase returns to the saved phase and `state.trade` is cleared.
- **Accept:** the offer is re-validated. If it is no longer legal, the accept is refused with the reason, the offer stays open and the receiver can decline instead. If it is legal:
  1. properties change owner in both directions, keeping their mortgage state;
  2. cash moves in both directions (`Paid`, reason "Trade");
  3. jail cards move from the front of each side's held list;
  4. the receiver of each mortgaged property is charged 10% interest (`unmortgageCost − mortgageValue`) to the bank through `charge`, so someone who can't pay goes into debt;
  5. `TradeAccepted` is emitted, the phase returns to the saved phase, and `state.trade` is cleared.

  The engine's existing after-action hook then switches to `Debt` if the interest created a debt. If the saved phase was already `Debt`, play simply continues in it: the debtor may now be able to pay.

### Bot answers

A bot values each side of an offer from its own point of view:
- **cash:** face value;
- **a jail card:** $50;
- **a property:** its price, or `price − unmortgageCost` if it is mortgaged;
  - **double** for a Property the bot receives that leaves it owning the whole color set after the trade;
  - **double** for a Property the bot gives away that leaves the proposer owning the whole color set after the trade.

The bot **accepts** when `valueReceived ≥ 1.1 × valueGiven` and, if it gives cash, it keeps at least `Bot.CASH_RESERVE` afterwards. Otherwise it **declines**. An offer where the bot gives nothing is always accepted.

## Snapshot and protocol

- `Snapshot.phase` can be `"Trade"`.
- `Snapshot.trade: { from, to, give, get }?` holds the open offer (arrays of positions, cash, jail-card counts).
- `Snapshot.tradeOffersLeft: number` is the offers the acting player has left this turn.
- New actions:
  - `{ type = "ProposeTrade", offer = <offer> }`
  - `{ type = "AcceptTrade" }`
  - `{ type = "DeclineTrade" }`
- New events and log lines:
  - `TradeProposed` → "Max offered Bot 2 $100 for Boardwalk". Items are listed with " + ", and an empty side reads "nothing".
  - `TradeAccepted` → "Bot 2 accepted the trade"
  - `TradeDeclined` → "Bot 2 declined the trade"
- GameSession fallbacks gain `DeclineTrade`, so a bot with no plan never stalls a trade.

## HUD

- **Trade button:** shown when the local player may propose (acting, in Roll/EndTurn/Debt, offers left, at least one other player still in). It sits beside Properties in the action bar.
- **Trade window:**
  - **Partner picker:** one button per other non-bankrupt player.
  - **Two columns:**
    - "You give": your deeds, cash and jail cards;
    - "You get": the partner's deeds, cash and jail cards.
    - **Deed rows** toggle on and off. Untradable deeds show greyed out with their reason.
    - **Cash** has −/+ buttons in $10, $50 and $100 steps, clamped to 0 and to what that side has.
    - **Jail cards** have a −/+ stepper, clamped to what that side holds.
  - **Send offer** is enabled only when `TradeRules` accepts the offer. Otherwise it shows the reason. **Cancel** closes the window.
- **Waiting:** while your offer is open, everyone sees "Waiting for Bot 2 to answer Max's offer".
- **Receiver:** the status line reads "Max offers you a trade", and a panel shows "You give: …" and "You get: …" with **Accept** / **Decline** buttons.
- The builder state (partner and selections) lives only in the client until **Send offer** is pressed. It is cleared when the window closes or the offer is sent.

## Testing

- **TradeRules spec:**
  - each legality rule and each refusal reason;
  - garbage offers;
  - the building-in-set rule for streets, and that railroads and utilities are always fine.
- **Trade engine spec:**
  - propose, then accept or decline, from Roll, EndTurn and Debt;
  - properties, cash and jail cards move correctly;
  - mortgaged property interest is charged, including into debt;
  - re-validation on accept;
  - the 3-offer limit and its reset at end of turn;
  - only the receiver may answer;
  - no proposals in BuyDecision, Auction or Trade itself, or from a non-debtor during Debt.
- **Bot spec:**
  - accepts a fair-plus offer and declines a lowball;
  - demands a premium for completing your set, and values completing its own;
  - keeps its cash reserve;
  - accepts gifts.
- **HudModel / EventText specs:** the Trade button's visibility, the receiver's buttons and summary, the status lines, the log lines.
- **Playtest in Studio:** a human builds and sends an offer to a bot (accepted and declined cases), and trades out of a debt.

## Out of scope

- Bots proposing trades; counter-offers; trades between two humans on a non-turn (only the acting player proposes).
- Trading buildings (they must be sold first, as in the official rules).
- Turn timer / time limits (milestone 5).
