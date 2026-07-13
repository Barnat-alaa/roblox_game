# Next actions

Ordered. Items marked **[you]** need your account/machine; the rest I can do once
MCP or the repo is connected.

## 1. Install the toolchain **[you]**
1. Install Rokit from <https://github.com/rojo-rbx/rokit/releases> (Windows installer).
2. Reopen your terminal, then:
   ```sh
   cd C:\Users\barna\Desktop\roblox
   rokit install
   ```
3. If it reports a version as unavailable, run:
   ```sh
   rokit add rojo-rbx/rojo UpliftGames/wally JohnnyMorganz/StyLua Kampfkarren/selene JohnnyMorganz/luau-lsp
   ```
4. Verify: `rojo --version` and `stylua --version`.
→ **Send me:** those two version lines.

## 2. Build & open in Studio **[you]**
```sh
rojo build --output SocialCafe.rbxlx
```
Open `SocialCafe.rbxlx` in Studio (or use `rojo serve` + the Rojo Studio plugin → Connect).
→ **Send me:** the Output panel contents after pressing **Play** (copy any red errors verbatim).

## 3. Connect Studio ↔ Claude Code over MCP **[you]**
Studio → Assistant panel → ⋯ → **Manage MCP Servers** → enable **Studio as MCP server** →
**Quick connect** → **Claude Code** → toggle on → restart Studio + Claude Code.
→ **Send me:** "green, 1 client." Then I can inspect the DataModel and drive playtests directly.

## 4. First playtest checklist (what "working" looks like)
- [ ] You spawn on a plot; a street of 6 greybox cafés is visible.
- [ ] HUD shows coins (150), reputation (0), level 1.
- [ ] Within ~8s an order banner + green **Serve** button appears.
- [ ] Serve → toast `+N 🪙`, coins increase.
- [ ] **Build** → catalogue of owned items → tap floor to place (green/red preview) → item appears.
- [ ] **Shop** → Buy an item → it shows up in Build.
- [ ] Rejoin (Studio: stop + Play again) → placed items persist **only if** DataStore API is enabled on a published place; in Studio it's in-memory per session (expected).

## 5. Publish the Dev experience **[you]** (needed for real persistence)
Enable **Studio Access to API Services** (Game Settings → Security) and publish the place,
so DataStore works. Then re-test persistence across rejoins.

## 6. GitHub **[you]**
Create the private repo, then I'll give you the exact `git remote add origin … && git push` commands.

---
### Backlog I pick up next (no account needed)
- Visible walking customer NPC + seat/counter routing (Day 3).
- Manual-cook timing minigame → `manualCook=true` bonus (Day 3).
- Café-visit interaction + a lighting/atmosphere pass (Day 5).
- Mobile control tuning + `test.project.json` + TestEZ runner wiring (Day 6).
