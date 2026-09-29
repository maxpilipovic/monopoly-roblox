# Debt, Bankruptcy and Winning — Design

Milestone 4, part 2 of 3 (after buildings/mortgages, before trading). Agreed in conversation on 2026-09-28.

## Goal

A player who can't afford a payment must raise the cash by selling buildings and mortgaging, or go bankrupt. A bankrupt player's assets go to whoever they owed (or are auctioned if they owed the bank). The last player standing wins. A results screen follows, then everyone returns to the lobby. Official Monopoly rules apply, except for the choices recorded below.

## Decisions

| Topic | Decision |
|---|---|
| Debt model | **Debt queue.** A payment the payer can't afford is not taken. It becomes a debt (an IOU) and the game pauses on the debtor. Balances never go negative. The creditor is paid only when the debt is paid. |
| Raising cash | While in debt the debtor may **sell buildings** and **mortgage** (and, in part 3, trade). Building and unmortgaging are blocked. |
| Paying / going bankrupt | One main button: **Pay $X** once cash covers the debt, otherwise **Go bankrupt** (two clicks to confirm). A player may go bankrupt whenever their cash is short, even with assets left. |
| Bankrupt to the bank | Buildings return to the bank, jail cards return to their decks, and each property is **auctioned** in turn to the remaining players (sold unmortgaged). |
| Bankrupt to a player | Buildings are sold to the bank at half price. All the debtor's cash, every property (mortgages kept) and jail cards go to the creditor. The creditor pays 10% interest on each mortgaged property received. |
| Game end | Last player standing wins. If the last solvent human goes bankrupt, the game ends at once and the solvent player with the highest net worth wins. |
| Results | "X wins!" screen with standings by net worth and a **Back to lobby** button (any player's press returns everyone). Automatic return to the lobby after 15 s. |
| Bots | Sell the most expensive buildings first (keeping sets even), then mortgage unbuilt property cheapest first, pay once they can, go bankrupt when nothing is left to sell. |

## Rules

### Charging

Every payment a player owes goes through one engine function, `charge(payer, creditor, amount, reason)` (creditor nil = bank):
- rent, tax, card payments ("Pay", "Repairs", each player's share of "PayEachPlayer" and "CollectFromEachPlayer"), the forced jail fine after three failed doubles, and mortgage interest on inherited property.
- If the payer's cash covers the amount, it is paid at once, the same as today.
- Otherwise a debt `{ debtor, creditor, amount, reason }` is appended to `state.debts` and a `DebtOwed` event is emitted. Nothing is paid.

Voluntary spending (buying, bidding, building, unmortgaging, the voluntary jail fine) is unchanged: it is refused when the player can't afford it.

"PayEachPlayer" charges the drawer once per other player, in seat order, so a short drawer may pay some players and owe others. "CollectFromEachPlayer" charges each other player, so several players can end up in debt to the drawer at once.

A forced jail fine that becomes a debt still releases the player, and they move as normal. Anything owed where they land joins the queue behind it.

### The Debt phase

- After every accepted action, if `state.debts` is not empty and the phase is not already `Debt` or `Auction`, the engine saves the current phase in `state.resumePhase` and switches to `Debt`.
- The acting player in `Debt` is the debtor of the first debt (`state.debts[1]`), who may not be the current player.
- The debtor may do only these:
  - `SellBuilding` and `Mortgage`, under the usual `PropertyRules` checks;
  - `PayDebt`: legal when their cash is at least the amount. It pays the creditor, removes the debt and emits `DebtPaid`;
  - `Bankrupt`: legal only when their cash is less than the amount.
- When the last debt is settled, the phase returns to `state.resumePhase` (Roll or EndTurn), unless the current player went bankrupt (see below).
- Debts are settled strictly in order. If several players owe the drawer of "CollectFromEachPlayer", the game pauses on each in seat order before the drawer's turn continues.

### Going bankrupt

When the debtor of debt D goes bankrupt:

1. They are marked `bankrupt`, and a `WentBankrupt { player, creditor }` event is emitted. Every other debt they owe is dropped from the queue.
2. **If the creditor is a player:**
   - (If the creditor has meanwhile gone bankrupt, treat the debt as owed to the bank.)
   - Every building is sold back to the bank at half the house price. A hotel is five house prices at half each, and the buildings return to the bank supply. The cash goes to the debtor.
   - All of the debtor's cash moves to the creditor (`Paid`, reason "Bankruptcy").
   - Each property changes owner to the creditor and stays mortgaged if it was.
   - For each mortgaged property received, the creditor is charged the 10% interest (`unmortgageCost − mortgageValue`) payable to the bank. This goes through `charge`, so a creditor who can't pay it goes into debt to the bank.
   - Get Out of Jail Free cards move to the creditor.
3. **If the creditor is the bank:**
   - The debtor's buildings return to the bank supply, and their cash is removed.
   - Their jail cards go to the bottom of their decks.
   - Their properties are released (unowned, unmortgaged). Their positions, in board order, go into `state.auctionQueue`.
4. **Game-over check** (before any auctions start). The game ends when either:
   - one or fewer non-bankrupt players remain; or
   - the bankrupt player was human and no non-bankrupt human remains.

   Then `phase = "GameOver"`, `state.winner` is set, and `GameOver { winner }` is emitted. The winner is the only one left, otherwise the non-bankrupt player with the highest net worth (ties go to the earliest seat). The auction queue is discarded.
5. **Otherwise, continue:**
   - if the auction queue is not empty, start the next auction;
   - else if debts remain, the next debt (phase stays `Debt`);
   - else if the bankrupt player was the current player, end their turn (the next non-bankrupt player's `Roll`);
   - else return to `state.resumePhase`.

### Bankruptcy auctions

- They use the existing auction flow and bidder order (starting from the current player, skipping bankrupt players).
- The winner gets the property unmortgaged. If nobody bids it stays with the bank.
- When an auction ends and more positions are queued, the next one starts. When the queue is empty, play continues as in step 5, without the auction part.
- An ordinary Decline auction still ends with `finishMove` as today.

### Net worth

Net worth = cash + for each owned property (its mortgage value if mortgaged, else its price) + each building at the full house price (a hotel counts as 5).

## Snapshot and protocol

- `Snapshot.phase` can be `"Debt"`.
- `Snapshot.debt: { debtor, creditor?, amount, reason }?` holds the first open debt.
- `Snapshot.winner: string?`.
- `PlayerView.netWorth: number`.
- New actions: `{ type = "PayDebt" }`, `{ type = "Bankrupt" }`.
- New lobby request: `{ type = "ReturnToLobby" }`, accepted only while the phase is `GameOver`.
- New events, each with a log line:
  - `DebtOwed` — "Ana owes Bot 2 $340 in rent"
  - `DebtPaid`
  - `WentBankrupt` — "Ana went bankrupt to Bot 2" / "…to the bank"
  - `GameOver` — "Bot 2 wins!"

## HUD

- **Debtor:**
  - a red status line: "You owe Bot 2 $2000. You have $300."
  - the Properties panel opens automatically, with only Sell and Mortgage row buttons;
  - the main button is "Pay $2000" when affordable, else "Go bankrupt". The first click turns it into "Confirm bankruptcy?", and a second click sends `Bankrupt`. The confirm state resets on the next update.
- **Everyone else:** "Waiting for Bot 2 to raise $340…"
- **The player list** shows "Bankrupt" for bankrupt players. Their tokens already fade.
- **Results screen** (phase `GameOver`):
  - "Bot 2 wins!" plus a ranked list of name and net worth, bankrupt players last;
  - a Back to lobby button.
- **Server:** on entering `GameOver`, GameService schedules a 15 s return to the lobby, which clears the session (if that same session is still running) and broadcasts. `ReturnToLobby` does the same at once.

## Testing

- **Engine specs:**
  - charge pays or queues;
  - the Debt phase and resume;
  - PayDebt / Bankrupt legality;
  - blocked actions in Debt;
  - PayEachPlayer / CollectFromEachPlayer debts in seat order;
  - forced jail fine as a debt;
  - bankruptcy to a player (buildings, cash, properties, mortgages, interest debt, jail cards);
  - bankruptcy to the bank (supply, decks, auction queue, resume);
  - the game-over rules and the winner by net worth.
- **Bot spec:** sells before mortgaging, the most expensive building first, keeps sets even, pays when able, goes bankrupt otherwise.
- **HudModel / EventText specs:** debt buttons and status lines, the confirm step, the results rows, the new log lines.
- **Simulation:** an all-bot game played with a seeded dice roller must reach `GameOver` with a winner within a bounded number of actions.
- **Playtest in Studio:** a human enters debt, mortgages, pays; a human goes bankrupt; the results screen appears and returns to the lobby.

## Out of scope

- Trading, including trading while in debt (part 3).
- Turn timers and time limits (milestone 5).
- A creditor choosing to unmortgage inherited property immediately instead of paying the 10% (they can unmortgage later as normal).
