# Next actions

Ordered. Items marked **[you]** need your account/machine; the rest Claude does via MCP/repo.

## 1. Reopen the place in Studio **[you]** — needed to resume live work
1. Double-click `C:\Users\barna\Desktop\roblox\SocialCafe.rbxlx` (rebuilt today from the repo — includes the client boot fix).
2. Wait for Studio to load, keep it open.
→ **Send me:** "Studio open" (I'll reconnect via MCP and verify).

## 2. Publish the Dev experience **[you]** — needed for real persistence
1. In Studio: **File → Publish to Roblox** → create a **new experience** named `Social Cafe DEV`, private.
2. **Home → Game Settings → Security → Enable Studio Access to API Services** → Save.
3. This makes DataStore work so saves survive rejoining.
→ **Send me:** a screenshot of Game Settings → Security, or just "published + API on".

## 3. Day 3 build (Claude, via MCP + repo — no account needed)
- Visible walking customer NPC: spawn at street → walk to counter/seat → order bubble → wait → react → leave.
- Manual coffee-brew timing minigame at the machine (`StartCooking` remote is already reserved; `manualCook=true` bonus path exists in RewardMath).
- Stuck-NPC recovery (teleport/reset).

## 4. First playtest checklist (unchanged — re-verify after Day 3)
- [ ] Spawn on a plot; street of 6 greybox cafés visible.
- [ ] HUD shows coins 150 / reputation 0 / level 1.
- [ ] Order banner + **Serve** within ~8 s; serve pays and toasts.
- [ ] **Build** → place/rotate with green/red preview; **Shop** → buy → place.
- [ ] Rejoin restores data (only after step 2 publishes the place).

## Backlog (tracked as tasks in-session)
- Day 5: onboarding flow, plaza/lighting pass, café-visit interaction.
- Day 6: mobile pass, security review (incl. zero-gap duplicate-claim race test), TestEZ runner wiring, 2-client test, analytics events.
- Day 7: private publication, content maturity, icon/thumbnail, tester access, smoke test.
