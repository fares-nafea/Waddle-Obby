# Day 9 — Tasks

**Theme:** Finish what you started Day 8 — make the trails **actually appear on your penguin**. This is the visual payoff, and (per the analytics) exactly the kind of content that gets pushed: a colored trail streaming behind a running character is satisfying to watch, unlike a save system.

---

## 🎮 Build — Trail equip system

- [ ] **Add an "Equip" button** to each owned trail card in the Collection UI (locked cards stay locked)
- [ ] **New `EquipEvent`** RemoteEvent in `ReplicatedStorage.Events` (client asks to equip → server does it)
- [ ] **Server `EquipService`** (ServerScriptService):
  - [ ] Verify the player actually owns that trail (check their `Inventory` folder — never trust the client)
  - [ ] Attach a `Trail` to the character (two attachments on the HumanoidRootPart + a `Trail` colored from the catalog)
  - [ ] Remove any previously equipped trail first (only one at a time)
  - [ ] Save the equipped trail name (add an `Equipped` field via DataService)
- [ ] **Re-apply on respawn** — listen to `CharacterAdded` so the trail comes back after every death/teleport
- [ ] **Unequip option** — click the equipped trail again to take it off
- [ ] **Show "Equipped" state** in the UI (checkmark / highlight on the active trail)

## 🔧 Update DataService
- [ ] Add `Equipped` (string) to `defaultData()` and to load/save, so your chosen trail persists across sessions

## ✅ Playtest
- [ ] Buy/own a trail → open Collection → Equip → trail streams behind you
- [ ] Die / go through a portal → trail is still on after respawn
- [ ] Leave and rejoin → same trail auto-equips
- [ ] Equip a different one → old trail disappears, new one shows

---

## 🎬 Film (Day 9 Short) — lead with the VISUAL

- [ ] **Hook (0–2s):** the penguin sprinting with a bright **Rainbow/Aurora trail** flowing behind it — motion + color in frame one. VO: "I finally made the trails work."
- [ ] **Payoff (2–14s):** open Collection, click Equip, trail snaps on. Show 2–3 different colored trails back to back (fast cuts).
- [ ] **Callback:** "Yesterday this was broken — you asked for [color], so here it is." (credit a commenter)
- [ ] **Ask (25–33s):** "Which trail is the best? And what cosmetic should I add next — wings? a pet? 👇"
- [ ] **Loop + tag:** "Day 9 of building games until I'm a Top 100 Roblox developer."

> Keep it **30–40s** with high absolute watch time. This is your Day 7-style visual content — that's the video type that actually got tested (87 views / 31% feed). Don't make the *system* the star; make the *trails* the star.

---

## ✅ Definition of done
Clicking a trail equips it and it streams behind your penguin, survives respawn + rejoin, only one at a time, and you've filmed a visual-first Short asking what cosmetic comes next.

## 🔜 Teed up (Day 10+)
- Equip **skins** (same system, swaps character look)
- **Checkpoints** in the obbies (the long-standing community ask)
- A **pet** or **wings** cosmetic (whatever wins the Day 9 comment vote)
