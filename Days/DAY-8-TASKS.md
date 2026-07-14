# Day 8 — Code Review + Tasks

## ✅ Code review (current state)

**What's solid:**
- `TimerService` — clean. Good additions: `elapsed` min-clamp, reward min-clamp, `startTimes` guard, and `PlayerRemoving` cleanup. No leaks.
- `EggService` — weighted roll is correct, coins charged before rolling, duplicate refund is a nice touch.
- Folder-driven `Stages`/`Gates` design means adding obbies needs no code. Keep this pattern.

**🔴 The one big problem — nothing saves.**
`Main.server.lua` creates `Coins = 0` every join, and `Inventory` is rebuilt fresh each session. So a player grinds coins, buys a Legendary penguin… leaves… and it's all gone. Right now the entire egg system has no lasting reward. **This is Day 8.**

**🟡 Smaller fixes (2 min):**
- `TeleportService` has debug spam: `warn("Leaved Stage")` and `warn("Finished")`. Delete them or switch to `print` — warns clutter the output and look like errors.
- `TeleportService` reads `workspace.Stages` / uses per-stage `WaitForChild` at load — fine, just make sure Stages exists before the script runs.
- Cosmetics don't *do* anything yet — buying a "Frost Trail" adds a value but no trail appears. That's Day 9 (equip system), not today.

---

## 🎯 Day 8 focus: Save progress (DataStore)

The hero feature. Protects coins + unlocked eggs across sessions, and it's a genuinely great devlog video ("I almost lost everyone's progress").

### 🎮 Build
- [ ] Enable **Studio Access to API Services** (Game Settings → Security) so DataStores work in Studio
- [ ] New `DataService` (ServerScriptService): on join, load saved `Coins` + `Inventory`; on leave, save them
- [ ] Make `Main.server.lua` use loaded data instead of always `0` (or fold it into DataService)
- [ ] Save on `PlayerRemoving` **and** `game:BindToClose` (so nothing is lost on shutdown)
- [ ] Add a session-lock / retry so data can't be overwritten or corrupted
- [ ] Test: earn coins → buy egg → leave → rejoin → coins + unlocks still there

### 🎬 Film (Day 8 Short)
- [ ] **Hook:** "I almost lost everyone's progress in my Roblox game." (show coins resetting to 0)
- [ ] **Payoff:** rejoin and everything's still there — coins + the penguin you unlocked
- [ ] **Ask:** "What should I add next — checkpoints, or a way to equip your skins? 👇"
- [ ] **Loop + tagline:** "Day 8 of building games until I'm a Top 100 Roblox developer."

### 📣 After posting
- [ ] Pin the checkpoints-vs-equip question
- [ ] Reply to every comment in the first hour, each ending in a question

---

## 🔜 Teed up for later (don't do today)
- **Day 9 — Equip system:** actually attach trails/skins from your Inventory so cosmetics do something.
- **Day 10 — Checkpoints:** so "brutal" Obby #2 doesn't restart you on every death (this is the natural community ask from Day 7).

## ✅ Definition of done
Coins and unlocked eggs survive leaving and rejoining, the two debug warns are gone, and a Day 8 Short is posted asking checkpoints-vs-equip.
