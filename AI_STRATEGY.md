# How the Computer players use spells

This is the plain-English version of `scripts/ai_spells.gd`. If you change one,
change the other.

## The one idea: everything is priced in dollars

Each time a bot could cast something, it puts a dollar value on every spell it
could cast right now, at every level it can reach. It casts the best one if
that value clears a bar; otherwise it keeps the card. After the cast resolves
it looks again, up to 4 casts per turn phase.

Every cast also writes a grey line in the game log saying why, for example:

> (Player 3's reasoning: Taxes at Level 2, worth about $410: Player 1 pays $280, 1/3 of their money.)

### What counts as value

- **Money in** counts in full.
- **Money an opponent loses** counts too, but less than money the bot gains.
  The bot splits its "harm" across the opponents still in the game: hurting
  one rival in a 2-player game is worth as much as gaining the money yourself,
  but hurting one of three opponents is worth a third of that.
  - It counts **1.5x** against the **leader** (highest net worth: cash, plus
    properties, plus houses).
  - It counts **0.6x** against anyone already worth less than half of what the
    bot is.
  - So when a spell lets it pick a victim, it usually goes after the leader.
- **Properties** are worth more in sets:
  - A partial set gets a bump of up to 1.6x its price.
  - A complete set is worth 2.5x (rent doubles and houses can go up).
  - Railroads scale 1x / 1.3x / 1.7x / 2.2x for 1 to 4 owned; utilities 1x / 1.4x.
  - Stealing a property is worth what the bot gains plus a share of what the
    victim loses.
- **Buying** a property is worth its set value minus the price, plus 30% of
  the price for future rent. It's worth a bonus if it stops an opponent from
  completing a set.
- **Squares on the board**, for movement spells:
  - An opponent's property costs its current rent (counted with the harm
    bonus, since the money goes to a rival).
  - A tax square costs the tax.
  - Free Parking is worth the pot.
  - An unowned property it can afford is worth its buy value.
  - Magic Forest is worth $50; the Spell Shop $20 if it has money to spend.
  - Passing Go is worth $200 each time.
  - Jail is worth **-$50 early** (no buying), but **+$40 once someone has rent
    of $300 or more** (sitting in Jail dodges it).
- **Cards** are worth about $60 each, more for reaction cards (see below).

### The bar a spell must clear

| Situation | Minimum value |
|---|---|
| Own turn, fewer than 5 cards | $70 |
| Own turn, 5 or 6 cards | $40 |
| Own turn, 7+ cards | $15 (use them or lose them) |
| Cards that return to the hand (Sanity Grinding, Step Forward) | $5 |
| Reacting to a roll or a spell | $50, or the card's insurance value if higher |
| Countering | the spell would cost the bot $120+ |

**Patience with swingy spells.** Taxes, Migraine, Far-Reaching Empire,
Line of Fire, Sinkhole and Snatch Purse also have to reach half of what they
usually pay (30% with 5+ cards). So a bot won't fire Taxes Level 3 at a player
holding $60.

### Levels and Attunement

The bot scores each level separately and picks the most valuable one it can
reach. If a higher level is out of reach, it may **burn up to 2 other cards of
the same color** for Attunement. It only does this when the extra value beats
the worth of the burned cards plus $40 each.

Manastone, Overflowing Bounty and Natural Magician are priced by **what the
extra Attunement unlocks**: "+1 Red lets my Taxes go from Level 1 to Level 2,
worth $150 more". The bot casts them first, then the better spell.

## When the bot thinks

1. **Its turn, before rolling.** Movement spells only make sense now. It
   averages the outcome of all 36 dice rolls with and without the spell:
   Unstable Portal, Hasty Exit Level 1, Step Forward, Siren's Song, Master Plan,
   Pilgrimage, Unclaimed Wilderness. Plain money spells also go off now, so the
   cash is there if it lands on something to buy.
2. **Its own roll, while the piece is walking.** It sees where it's about to
   land and compares that with where each roll spell would put it:
   - Adrenaline, Rocket Boost, Hasty Exit Level 2.
   - Divine Protection, Escape Into Custody.
   - Escape Plan, King's Escape Tunnel.
   - Veto, Dodge, Go For the Kill.

   It also uses Counterfeit Currency / Misplaced Payment if it's about to pay
   rent, and Haggling if it's about to buy.
3. **Its turn, after the roll.** Turn spells again, with the roll known
   (Critical Hit's doubles bonus, Haggling before building houses).
4. **Someone else's roll.** Price Gouging if they're about to land on its
   property. Seize the Opportunity (pays off on high dice). Knockout Punch or
   Bribe the Guards Level 2 to cancel a roll heading somewhere good for them,
   but never one heading to the bot's own property.
5. **A spell on the stack.** It estimates what the spell will do to it (money
   taken, properties stolen, houses burned, Jail and so on). If that's $120 or
   more, it counters with the cheapest counter that fits: Counterbalance or
   Deny Rights at the matching level, Spell Mastery, and Spell Mastery Level 2
   when it can, to steal the card. It defends its own spells the same way when
   they're countered. Counterfeit Currency shields it from a spell charging it
   money.
6. **Raise Money mode.** Before mortgaging, it casts whichever spell brings in
   the most cash right away (Taxes, Smite, Steal From the Future...).

Bots react the way you do: they **pause** the window, cast, and the cast opens
a fresh window that everyone (you included) can answer. At most one bot reacts
at a time, and each bot answers a given roll or spell only once.

## Choosing targets

| Spell | Target |
|---|---|
| "An opponent pays you" (Cult of Terminus, Critical Hit, Taxes, Migraine, Far-Reaching Empire, Art of the Deal...) | Whoever gives the most value: amount x harm bonus, capped at what they could actually raise. Usually the leader, or the richest for Taxes. |
| Sinkhole | The opponent whose square holds the most opponents. |
| Line of Fire | The side with the most opponent properties. |
| Threaten | The opponent's house-free property the bot would most like if they hand it over instead of paying. |
| Annexation / Market Manipulation / Offer You Can't Refuse | The property it gains most from. It gives back the properties that cost it least and help the opponent least. |
| Burn to the Ground | The opponent property where losing houses drops rent the most. |
| Impossible Architecture | Its own property where the new houses add the most rent, if it can keep $150 after paying. |
| Reclaimed by Nature | Opponents' mortgaged properties they'd miss most. |
| Royal Aid | Its own priciest mortgaged properties. |
| Promised Land | Level 3: the unowned property it wants most. Level 2: the side with the best average. |
| Cramped Cell | The opponent it collects most from (never itself). |
| Snatch Purse / Anti-Magic Law | The opponent with the most cards. |
| Lethargy / Fated Ending | The leader. On Fated Ending Level 2, it zeroes the die that leaves them worse off. |
| Manastone | The color whose extra Attunement unlocks the most value. |
| Word of Binding | The opponent property (or color) with the scariest rent. |
| Landmine / Toll Road / Ensnaring Roots | Squares a few steps ahead of the opponents, where they're likeliest to land or pass. |
| Stabilized Portal | Catches opponents where they're likeliest to land; sends them to the bot's highest-rent property. |
| Master Plan | Picks the dice for the best square (doubles if it's in Jail). |
| Dodge | Rerolls the die with the better expected result, then rerolls the other only if that's better on average. |

## Buying and discarding cards

- **Magic Forest:** discards its lowest-rated card.
- **Spell Shop:** buys the card it rates highest, if that's worth at least $30
  more than the price and it still has $250 left over afterwards.

A card's rating is the best value it would have right now at a level the bot
could reach, with one more Attunement. Reaction cards have a fixed insurance
value, since they're worth holding even when there's nothing to answer:
- Spell Mastery $130; Counterbalance $110; Deny Rights $100.
- Counterfeit Currency, Haggling and Seize the Opportunity $90.
- Divine Protection and Escape Plan $80.
- Adrenaline and most other roll cards $60–70.

## Known limits

- It looks one move ahead. It doesn't plan combinations across turns, except
  Attunement boosts within the same turn.
- It reads the board, not people: it doesn't guess what's in your hand or what
  you'll cast next.
- Spells it doesn't understand score $0, so it never casts them.
- Trades and houses still use the older bot rules (they ignore spells).
- "Take Player's Turn" stand-ins (online, for a disconnected player) never cast.

## Tuning

All the numbers above are constants at the top of `scripts/ai_spells.gd`
(`TURN_CAST_MIN`, `COUNTER_MIN`, `BURN_MARGIN`, `CARD_WORTH`, `HELD_WORTH`...).
The per-spell rules are in `evaluate()`, one `match` branch per spell.
