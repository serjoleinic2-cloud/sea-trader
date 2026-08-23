# GAME BIBLE — Sea Trader

> Source of Truth for game design. Do not modify without explicit owner decision.
> Last Updated: 2026-08-23 | Version: 0.1.0

---

## Core Fantasy

You are a lone captain of a small cargo ship on a procedurally generated sea. You start with nothing and build a trading empire — from a single creaking sloop to a full fleet and your own company. Every voyage is manual, every delivery is personal, every coin earned is yours.

---

## Core Gameplay Loop

```
Explore sea → Discover port → Accept contract → Navigate manually → Deliver cargo
     ↑                                                                     ↓
  Upgrade ← Repair ← Earn money + XP + Reputation ←────────────────────────
```

**Urgency mechanic:** Nearby ports offer urgent deliveries. Earlier delivery = higher reward. But high speed increases damage risk.

---

## Long-term Progression

```
Single ship captain
    → Upgrade ship
    → Discover new regions
    → Build own port
    → Found trading company
    → Hire employees
    → Expand fleet
    → Take major contracts
    → Dominate trade routes
```

---

## World

- **View:** Top-down 2D
- **Sea:** Procedurally generated, deterministic seed
- **Islands:** Scattered across sea
- **Ports:** Procedurally generated, attached to islands
- **Regions:** Different areas with different resources and dangers
- **Hazards:** Pirate zones, storms (TBD specifics)
- **Discovery:** Ports are hidden until player physically reaches them
- **Destination:** Discovered ports can be set as navigation destination

---

## Ships

- Player starts with a small cargo ship
- Ships have distinct components: hull, engine, steering, cargo hold
- Ships have physical momentum and feel — not instant response
- Ships visually tilt/lean on turns
- **Upgrades:** speed, maneuverability, cargo capacity, protection, hull strength
- Additional ships purchasable for fleet (managed by hired captains)

---

## Navigation

- **Control method:** Tilt phone to control ship
  - Tilt forward → throttle / accelerate
  - Tilt backward → brake / decelerate
  - Tilt left → turn left
  - Tilt right → turn right
- **Compass arrow:** On-screen helper arrow shows direction + distance to destination
- **No autopilot** for player's main ship during active gameplay
- Player manually navigates between ports

---

## Ports

- Discovered by physically sailing to them
- Each port has buildings: docks, warehouses, workshops, others (TBD)
- Port buildings can be damaged
- Damaged buildings require money/resources to repair
- **Port development:** Player can develop their own home port
  - Build/upgrade buildings
  - Expand trade network

---

## Resources

- Multiple resource types across regions
- Supply and demand system influences prices
- Resources are region-specific (TBD which resources, which regions)
- Player transports goods between ports

---

## Contracts

- Generated per port based on supply/demand
- Types:
  - Urgent delivery (time bonus)
  - Standard cargo transport
  - Large contracts (available via Company — TBD)
- Contract reward = base + time bonus − damage penalty (TBD exact formula)
- Contracts visible at port before accepting

---

## Economy

- **Income:** Cargo trading, contract rewards, TBD other sources
- **Expenses:** Fuel (TBD), repair costs, port fees (TBD), company expenses
- **Company expenses:** Employee salaries, fleet maintenance, taxes, infrastructure
- **Market:** Prices fluctuate by supply/demand
- Development must unlock more profitable opportunities

---

## Damage

Ship components have independent damage states:

| Component | Effect when damaged |
|-----------|-------------------|
| Hull | Ship can sink if at 0 |
| Engine | Reduced speed |
| Steering | Reduced maneuverability |
| Cargo Hold | Cargo may be lost or damaged |

Port buildings also have damage states (TBD details).
Damage repaired at port for money/resources.

---

## Company

- Unlocked at later game stage
- Player creates:
  - Company name
  - Company logo
  - Company flag
- Company has ongoing fixed expenses
- Enables larger contracts and fleet management

---

## Employees

| Role | Function |
|------|---------|
| Captain | Commands fleet ships on auto-routes |
| Navigator | TBD bonus |
| Mechanic | TBD repair bonus |
| Logistics | TBD efficiency bonus |
| Trader | TBD market bonus |
| Security Guard | TBD pirate protection |
| Engineer | TBD upgrade bonus |
| Manager | TBD company efficiency |

- Each employee has a salary (fixed expense)
- Hiring employees unlocks more profitable opportunities

---

## Fleet

- Multiple ships purchasable
- Hired captains run automated trade routes
- Fleet generates income while player is offline
- Manual control of player's own ship remains the core gameplay
- Fleet managed through Company screen

---

## Progression

| Progression Type | Unlocks |
|-----------------|---------|
| Player Level (XP) | Ship upgrades, new regions |
| Port Level | Port buildings, better contracts |
| Company Level | Fleet slots, large contracts |
| Reputation | Better contract offers, discounts (TBD) |
| Achievements | TBD cosmetic/functional rewards |

---

## Achievements

- TBD full list
- Based on: deliveries, distance sailed, money earned, contracts completed, fleet size, reputation

---

## Monetization

| Product | Description |
|---------|------------|
| Premium (one-time) | Remove all ads |
| No Ads (one-time) | Alternative ad removal option (TBD if same as Premium) |
| Starter Pack | One-time discounted bundle (TBD contents) |
| Ship Skins | Cosmetic only, no gameplay advantage |
| Custom Company Logo | Cosmetic, uploaded or designed in-app (TBD) |

**Rules:**
- Ads must not interrupt active ship control
- Free gameplay must remain viable without purchases
- No pay-to-win mechanics

---

## Offline Model

- Game works fully without internet connection
- All world generation, trading, economy, progression runs locally
- Offline progress calculated on next launch:
  - Fleet auto-routes generate income
  - Company expenses deducted
  - Market prices drift
- Maximum offline progress cap: TBD (suggested 24 hours)
- Save system stores last session timestamp

---

*TBD items are design decisions not yet made. Do not invent values for them.*
