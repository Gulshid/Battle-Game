# Phase 00 worksheet

## Vision
Name:
Elevator pitch (2 sentences):
Pillars: 1) Skill over stats  2) Readable at 6 inches  3) Fair under 150 ms ping
Anti-goals: no pay-to-win, no real-money payments, no chat in MVP

## MVP scope / cut list
| In MVP | Cut list |
|---|---|
| FFA, 4-8 players | Team modes, Capture Zone, Last Standing |
| Warrior, Archer, Mage | Assassin, loadouts, talents |
| 1 symmetric map | More maps, hazards |
| Guest login, ranked queue | Friends, parties, seasons, shop |

## Combat formulas
hits_to_kill = ceil(target_hp / damage)
TTK = (hits_to_kill - 1) * cooldown      (target 2-4 s incl. approach)
DPS = damage / cooldown
kite_window = (range - enemy_range) / (my_speed - enemy_speed)

## Playtest loop
Friday debug APK -> Discord -> 5-question form.
