# GAME RULES

> Decisions that cannot be changed without explicit owner approval.
> Last Updated: 2026-08-24 | Version: 0.2.0

---

## NON-NEGOTIABLE RULES

These rules define what the game fundamentally is. Changing them changes the game.

### Core
1. **Offline-first.** The game must function without any internet connection. No features may require a server.
2. **Top-down 2D gameplay.** The main game view is top-down. No 3D, no side-scrolling.
3. **Player manually controls their main ship.** The player always personally navigates their primary vessel during active play.
4. **No punishment for closing the app.** Player must not lose progress, ship, or cargo solely because they closed the application or it went to background.

### Controls
5. **Primary control method is phone tilt.** Tilt forward = throttle. Tilt backward = brake. Tilt left/right = steering.
6. **Navigation compass arrow is a guide only.** The arrow shows direction and distance to destination. It does not steer the ship automatically.
7. **No autopilot on new routes.** First passage on any route is always manual. Automation is only available on Known Routes.

### Travel Modes
8. **Manual Voyage is the primary gameplay.** Personal ship control, exploration, discovery, and contract delivery during active play.
9. **Known Route automation is secondary.** After a route has been manually traveled once, it may be automated for fleet or future player travel. Automation does not apply to unexplored routes.
10. **Save during voyage.** On app exit or background during Manual Voyage, the current voyage state (position, cargo, Fuel, Hull, route, elapsed time) is saved. Player can continue on next launch.

### Risk and Reward
11. **Speed affects reward.** Faster delivery = higher contract reward.
12. **High speed increases damage risk.** Speed is a conscious tradeoff, not a free advantage.
13. **Damage has real gameplay consequences.** Damaged components must meaningfully reduce ship capability.
14. **Fuel / Supplies limits range.** Longer routes require more resources. Refueling available at ports.

### Economy
15. **Economy must make sense.** Prices, costs, and rewards must be internally consistent and balanced.
16. **Progression must open new opportunities.** Upgrades and development must unlock meaningfully better gameplay, not just numbers.

### Monetization
17. **Ads must not interrupt active ship control.** No ads during sailing, navigation, or combat.
18. **Monetization must not destroy free gameplay.** A player spending no money must be able to progress through all core content.
19. **No pay-to-win.** Paid items are cosmetic or convenience, not gameplay advantages.

---

## CURRENTLY FLEXIBLE / TBD

These aspects are not yet decided. AI must not invent values for them without owner decision.

- Exact Fuel / Supplies consumption formula
- Port fee specifics
- Exact damage formulas (how much does hull damage reduce speed?)
- Contract reward formula (exact time-bonus calculation)
- Maximum offline progress cap
- Full resource/goods catalog
- Regional resource distribution
- Pirate encounter mechanics (frequency, behavior, combat or avoidance?)
- Protection mechanic (defense ships, hired guards?)
- Storm mechanics
- Exact employee bonus values per role
- Port level progression path (which buildings, in what order?)
- Company level milestones
- Reputation system specifics (how earned, how spent?)
- Achievement list
- Starter Pack contents
- Whether "Premium" and "No Ads" are the same product or separate
- Custom Company Logo mechanic (upload image? in-app designer?)
- Maximum fleet size cap
- Multiplayer (explicitly out of scope for now -- TBD long-term)
- Exact automated route risk formula
- Exact automated route duration formula
- Exact speed bonus formula for urgent contracts
- Fleet auto-route income formula
