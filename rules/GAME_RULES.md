# GAME RULES

> Decisions that cannot be changed without explicit owner approval.
> Last Updated: 2026-09-05 | Version: 0.3.0

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

### World Permanence
11. **World Seed is permanent.** The World Seed is generated once at new game creation and is never changed or regenerated on load. The same seed always produces the same world.
12. **World ≠ Player Knowledge.** The existence of a port in the world does not mean the player knows about it. Discovery state is Player Knowledge and is stored separately from world generation data.
13. **Discovered Port ≠ Known Route.** Knowing a port exists does not grant access to automated travel. A Known Route requires at least one manual passage to that port.
14. **Known Routes are bidirectional.** Manually sailing A→B creates a Known Route for both A→B and B→A, unless a specific exception is established later.
15. **Segment-based route knowledge.** Knowing A→B and B→C does not automatically create a Known Route A→C. Routes are established per segment. Chaining of segments for navigation or automation is a separate system (TBD rules).

### Risk and Reward
16. **Speed affects reward.** Faster delivery = higher contract reward.
17. **High speed increases damage risk.** Speed is a conscious tradeoff, not a free advantage.
18. **Damage has real gameplay consequences.** Damaged components must meaningfully reduce ship capability.
19. **Fuel / Supplies limits range.** Longer routes require more resources. Refueling available at ports.

### Economy
20. **Economy must make sense.** Prices, costs, and rewards must be internally consistent and balanced.
21. **Progression must open new opportunities.** Upgrades and development must unlock meaningfully better gameplay, not just numbers.

### Monetization
22. **Ads must not interrupt active ship control.** No ads during sailing, navigation, or combat.
23. **Monetization must not destroy free gameplay.** A player spending no money must be able to progress through all core content.
24. **No pay-to-win.** Paid items are cosmetic or convenience, not gameplay advantages.

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
- Multiplayer / social trading (TBD long-term — see ARCHITECTURE.md)
- Exact automated route risk formula
- Exact automated route duration formula
- Exact speed bonus formula for urgent contracts
- Fleet auto-route income formula
- Rules for chaining Known Routes for multi-hop navigation (A→B→C)
- Discovery range for ports (how close must ship be to trigger discovery?)
- Whether automated A→B→C chain requires separate Known Route A→C or can use segments
