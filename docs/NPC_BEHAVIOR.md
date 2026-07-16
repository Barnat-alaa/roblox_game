# NPC behaviour spec — who does what, exactly

_Created 2026-07-16 (owner request: "determine the behaviour and tasks of each
NPC one by one"). This is the contract the code implements; change the spec
first, then the code. Every character's job is listed with its full state
machine, and the OWNER can personally do every service action — staff are the
automation you watch when you're busy cooking._

## Rig policy (owner rule, 2026-07-16)

Staff and customers use ONLY rigs proven to walk: native HumanoidRootPart +
Motor6D skeleton, validated at load by `AssetLibraryService` (rigs failing the
gate fall back to the procedural chibi and are reported in the boot log). The
old waiter kit (154539270) slid/teleported → **permanently rejected**.
Waiter/Cleaner currently borrow walking customer bases and wear a
**role-coloured uniform apron** (waiter navy, cleaner green) + name bubble.

## The player (café owner) — can do EVERY job

| Action | How | Reward |
|---|---|---|
| Cook batches | stove/oven prompt → pick recipe → collect | stock + fresh bonus + mastery |
| Brew manually | coffee machine prompt, timing bar | quality bonus coins |
| **Take an order** | `E` on the ordering customer (front of queue) | serves from stock instantly, **+2 Buzz** "personal service" |
| **Clean a table** | `E` on a dirty plate | **+1 Buzz** (same as Pia) |
| **Collect tips** | `E` on the tip left at a table | coins |
| Build/decorate | Build mode | Décor (S4) |

Staff do the same jobs automatically — slower and without the personal-service
bonus — so an ACTIVE owner always out-earns an idle one, but nothing breaks
when you sleep (§35).

## Customer (walk-in NPC)

States: `STREET → DOOR → QUEUE → ORDER → WAIT → DINE → EXIT`
1. Spawns on the street (rate driven by Buzz), pathfinds through the front
   door to the queue (3 slots inside; the line steps forward on each serve).
2. At the front: shows the want-bubble "🗨️ {icon} {dish}".
3. Served when: counter stock has it (auto within ~2s) · the OWNER takes the
   order (`E`, +2 Buzz) · Mia rescues an overdue manual order · a fresh batch
   lands. Patience: 120 s at the window, 180 s total → "😠 Too slow…" walkout,
   −Buzz.
4. Dining: walks to a free chair (chairs auto-face their table), sits STILL
   (walk anim stops), the meal arrives via the staff pipeline below, eats
   (~7 s), may drop a collectible tip, leaves the EMPTY plate.
5. Exits through the door and despawns. If no chair: quick standing bite.

## Mia · Barista (brown apron, barista rig)

**Job: DRINKS.** Idles behind the counter.
- When a customer's meal is a Coffee/Tea dish: walks to the **coffee machine**,
  "☕ Preparing…" (1.6 s), then "**{icon} {dish} ✓**" and the plate appears —
  the waiter takes it from there.
- Rescue role: any manual order waiting past `staffServeAfterSeconds` gets
  auto-served ("☕ Coming right up!").

## Sam · Cook (white apron, chef rig)

**Job: FOOD.** Idles by the kitchen row.
- When the meal is any non-drink dish: walks to the **oven / prep station**,
  "🍳 Preparing…" (1.6 s), then "**{icon} {dish} ✓**" + plate.
- If one preparer is busy, the other covers; if both are busy > 6 s the plate
  appears at the station directly (theater never blocks a customer).

## Noah · Waiter (navy apron, walking-NPC rig)

**Job: CARRY PLATES.** Idles mid-room.
- When a prepared plate exists: walks to it ("🍽️ Coming through!"), carries it
  visibly in front of him, sets it **on the table in front of the diner**,
  returns home. Never teleports: PathfindingService routes around furniture
  (teleport remains only as a last-resort stuck recovery).

## Pia · Cleaner (green apron, walking rig)

**Job: WASH UP.** Idles near the kitchen.
- Dirty-plate queue: walks to the emptied plate ("🧹 On it!", +1 Buzz), CARRIES
  it back to the kitchen, "🧼 Washing…" (1.4 s), plate gone.
- Between jobs she sweeps: occasionally walks to a random floor spot, "🧹",
  and returns — she always looks employed.
- Failsafe: any plate nobody clears despawns after 180 s.

## Shared rules

- All staff walks use `NpcNav` (pathfinding, per-leg deadlines, teleport as
  final recovery only). All grant paths (coins/Buzz/XP) live in
  KitchenService/OrderService/EconomyService — staff and prompts are
  POST-PAYMENT THEATER and can never dupe rewards.
- Busy-flags serialize each staff member; every claim wait is bounded (≤6 s)
  and every stage has a graceful skip, so no customer can deadlock on staff.
- Later (Phase 6): hiring/wages; staff you haven't hired simply leave the
  matching job to the owner.
