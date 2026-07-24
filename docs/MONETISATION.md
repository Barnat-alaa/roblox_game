# Monetisation — the A8 plan (prices, products, presentation)

_Created 2026-07-24. The rails-clean monetisation for Social Café City. Every
number is a **proposed price for owner sign-off** — chosen so nothing valuable is
sold too cheap and nothing minor is overpriced. **You create the products in the
Creator Dashboard; I wire them up.** Design rules from `GAMEPLAY_DIRECTION.md` §5
and `CORE_LOOP_SPEC.md` §3c._

## The non-negotiable rules (what keeps this fair + policy-safe)
- **Everything buyable with Robux is also earnable with coins/levels.** Robux only
  skips the grind — never buys power you can't earn.
- **No loot boxes / no gacha / no paid random boxes.** Bundles have fixed contents.
- **No pay-to-win.** Boosts are temporary and modest; VIP perks are convenience +
  cosmetic, never exclusive power.
- Prices below assume the player buys Robux at ~R$80 ≈ US$1.

## How the buy button works (the "usual template")
Each product card has a **Robux button** that calls Roblox's **native purchase
prompt** (`MarketplaceService:PromptProductPurchase` for consumables,
`PromptGamePassPurchase` for passes). That prompt **is** the standard template —
it shows the **product's uploaded image + the R$ price + Buy/Cancel**. So the
"image the player clicks to buy" is the icon you upload with each product in the
Dashboard; our in-game card shows the same icon + a one-line "what you get".

## Presentation — beautiful + addictive (without being scummy)
A dedicated **Shop → "Robux" tab** (or its own dock button), laid out in sections
so the eye lands on value:
- **Cards** use the existing `Components` style: item image, bold name, a short
  benefit line, and a chunky Robux button. Locked/owned states reuse the shop's
  patterns.
- **A "BEST VALUE" ribbon** on VIP and the biggest bundle (anchoring).
- **Owned passes** show a green "OWNED" chip instead of a price (no nagging).
- **Boost timers** show a live "2× Coins — 43:12 left" pill on the HUD when active
  (the reward is visible, which is what makes it feel good).
- **Honest framing only** — real "what you get", no fake countdowns, no "only 3
  left". The pull is the value and the visible boost, not manufactured urgency.

---

## The catalogue + prices (for your sign-off)

### A. Developer Products — consumable, repeatable
| Product | What you get | Also earnable? | **Price** |
| --- | --- | --- | ---: |
| **Emergency Restock** | Top every *low* ingredient back to a comfortable level | Yes — buy at the market | **R$25** |
| **Barista Bundle** | +250 coffee beans, +150 milk, +200 sugar, +150 tea leaves | Yes — market | **R$49** |
| **Kitchen Bundle** | +200 flour, +150 eggs, +120 butter, +120 of each savoury | Yes — market | **R$49** |
| **Full Pantry Refill** | Top **every** ingredient to a strong level | Yes — market (tedious) | **R$99** |
| **2× Coins — 1 hour** | Double all coin income for 60 min | — (pure accelerator) | **R$59** |
| **2× Reputation — 1 hour** | Double reputation for 60 min | — | **R$59** |
| **Instant Delivery** | Skip the market trip — a chosen bundle arrives now | Yes — walk to market | **R$19** |

### B. Staff accelerators — Dev Products (also fully grindable with coins)
| Product | What you get | Coin path | **Price** |
| --- | --- | --- | ---: |
| **Instant Hire** (per locked role) | Hire Cook / Cleaner / future staff now | Hire with coins in the Staff panel (A7) | **R$99** |
| **Instant Max Upgrade** | Take one staffer straight to level 10 | Upgrade with coins, level by level | **R$249** |

### C. Game Passes — one-time, permanent
| Pass | What you get | **Price** |
| --- | --- | ---: |
| **VIP Membership** ⭐ | +50% daily login reward · larger ingredient storage · **8h→12h** offline cap · faster walk · unique name colour · a VIP badge on your sign | **R$399** |
| **Auto-Collect** | Finished batches drop straight onto the counter — no walking to collect | **R$149** |
| **Founder's Pack** (limited-time-of-launch, not FOMO-priced) | A cosmetic café theme + a starter coin boost + a Founder badge | **R$199** |

### Why these prices (the "not too cheap / not too dear" logic)
- **Minor conveniences** (Instant Delivery R$19, Emergency Restock R$25) are
  impulse-cheap — they save a walk, nothing more.
- **Repeatable value** (bundles R$49, refill R$99, boosts R$59) sits in the R$50–100
  "one coffee" band — enough to feel deliberate, cheap enough to repeat.
- **Big permanent value is priced up**: **VIP R$399** and **Instant Max R$249** are
  the flagships — they're worth a lot (permanent perks / skipping a long grind), so
  pricing them low would both undersell them *and* feel pay-to-win. High price =
  honest signal of value + keeps the grind meaningful for everyone else.
- Nothing here exceeds ~R$400, so no single purchase feels predatory.

---

## Engineering (what I build once you have the product IDs)
- **`MonetizationService`** implements `MarketplaceService.ProcessReceipt`, which
  **must be idempotent** (`docs/SECURITY.md`): key on `receiptInfo.PurchaseId`,
  record a `grantedReceipts` set on the save, grant **once**, return
  `PurchaseGranted` **only after** the grant is saved, `NotProcessedYet` otherwise.
- **`Config/Products`** — a table mapping each `productId`/`gamePassId` → its reward
  (grant amounts server-side, never client-sent). Placeholder IDs until you paste
  the real ones.
- **`PlayerData.grantedReceipts`** (top-level, self-heals via `reconcile`) + any
  boost timers (`PlayerData.boosts`), VIP flag from `UserOwnsGamePassAsync`.
- **Client shop UI** — the cards + native purchase prompts described above.

## What you do (create the products — ~10 min)
1. **Creator Dashboard → your experience → Monetization → Developer Products** →
   *Create Developer Product* for each row in tables A & B: name, upload an **icon**
   (the image players click), set the **R$ price** above. Copy each **Product ID**.
2. **Monetization → Passes** → create the game passes in table C the same way; copy
   each **Pass ID**.
3. Paste the IDs to me (or into `Config/Products`) and I wire the grants + the shop
   cards + the idempotent receipt handler, then we test a purchase in Studio.

_Assets I'll need from you: an icon per product (or tell me to reuse existing art /
generate placeholders). Everything else I build._
