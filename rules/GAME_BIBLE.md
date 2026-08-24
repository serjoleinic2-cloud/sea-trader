# GAME BIBLE -- Sea Trader

> Source of Truth for game design. Do not modify without explicit owner decision.
> Last Updated: 2026-08-24 | Version: 0.2.0

---

## Core Fantasy

You are a lone captain of a small cargo ship on a procedurally generated sea. You start with nothing and build a trading empire -- from a single creaking sloop to a full fleet and your own company. Every voyage is manual, every delivery is personal, every coin earned is yours.

---

## Core Gameplay Loop

```
Explore sea -- Discover port -- Accept contract -- Navigate manually -- Deliver cargo
     ^                                                                      |
     |                                                                      v
  Upgrade -- Repair -- Earn money + XP + Reputation -- Known Route automation
```

**Urgency mechanic:** Nearby ports offer urgent deliveries. Earlier delivery = higher reward. But high speed increases damage risk.

---

## Long-term Progression

```
Single ship captain
    -- Explore world -- Discover ports -- Learn routes
    -- Upgrade ship
    -- Discover new regions
    -- Known routes enable automation
    -- Build own port
    -- Found trading company
    -- Hire employees
    -- Expand fleet
    -- Take major contracts
    -- Dominate trade routes
```

**Central progression loop:** Personal ship -- Exploration -- Known routes -- Automation -- Fleet -- Company -- Trading network.

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
- **Exploration:** World is not fully visible at start. Player gradually reveals ports, resources, routes, dangers.

---

## Two Travel Modes

### A. Manual Voyage (Primary Gameplay)

Player personally controls their ship.

**Controls:**
- Tilt forward -- throttle / accelerate
- Tilt backward -- brake / decelerate
- Tilt left -- turn left
- Tilt right -- turn right

**During manual voyage player can:**
- Explore the world
- Discover new ports
- Choose their route freely
- Earn speed bonus on urgent contracts
- Encounter hazards (storms, pirates)
- Take damage
- Consume Fuel / Supplies
- Find new opportunities

Manual voyage is the core interactive gameplay. It is never automated.

### B. Automated / Known Route

After a route between two ports has been manually traveled once, it becomes a **Known Route**.

**Known Route properties:**
- Requires time to complete
- Consumes Fuel / Supplies
- May have risk (damage, extra costs, delays)
- May yield lower reward than manual voyage
- Does NOT require player to keep the app open
- Does NOT work on unexplored routes

**Example:**
```
First voyage: HOME --[manual]--> B  (route discovered)
Known route:  HOME <--[auto]--> B   (both directions)
```

Player gradually builds their own trading network by exploring and establishing known routes.

---

## Route Discovery

**Rule:** First passage on any new route is ALWAYS manual.

After successful arrival, the route becomes known in both directions.

**Example network growth:**
```
HOME --[manual]--> B
HOME <--[known]--> B

B --[manual]--> C
B <--[known]--> C

Network: HOME -- B -- C
```

Alternative connections may appear later:
```
A --[manual]--> C
B --[manual]--> D
C --[manual]--> E
```

Not all routes are known from the start. Discovery is part of progression.

---

## Navigation

- **Control method:** Tilt phone to control ship
  - Tilt forward -- throttle / accelerate
  - Tilt backward -- brake / decelerate
  - Tilt left -- turn left
  - Tilt right -- turn right
- **Compass arrow:** On-screen helper arrow shows direction + distance to destination
- **No autopilot** for player's main ship during active manual gameplay
- **Camera:** Follows ship during voyage. Manual map pan is secondary.
- Player manually navigates between ports on new/unexplored routes

---

## Fuel / Supplies

**Confirmed concept:** Fuel / Supplies is a range/resource stat.

**Purpose:** Limits voyage distance. Required for both manual and automated routes.

**Example ship state:**
```
Cargo: 8/10
Fuel: 72/100
Hull: 84/100
```

**Usage:**
- Manual voyage consumes Fuel / Supplies
- Automated routes consume Fuel / Supplies
- Longer routes require more Fuel / Supplies
- Ports provide refueling

**Upgrades** may increase Fuel / Supplies capacity.

**Exact consumption formula:** TBD. Not decided yet.

---

## Intermediary Ports

Long routes may pass through multiple ports.

**Example:** A -- B -- C -- D

**Intermediary ports allow:**
- Refueling
- Repair
- Trading (buy/sell)
- Cargo swap
- New contracts
- Continuing a long expedition

This enables long expedition routes without requiring one continuous uninterrupted voyage.

---

## Ships

- Player starts with a small cargo ship
- Ships have distinct components: hull, engine, steering, cargo hold
- Ships have physical momentum and feel -- not instant response
- Ships visually tilt/lean on turns
- **Upgrades:** speed, maneuverability, cargo capacity, protection, hull strength, Fuel / Supplies capacity
- Additional ships purchasable for fleet (managed by hired captains)

---

## Speed and Risk

**For manual urgent contracts:**
- Faster delivery = higher potential reward
- Higher speed = higher Fuel / Supplies consumption
- Higher speed = higher damage risk (collision, hazards)
- Speed is a conscious tradeoff

**Exact speed/reward formula:** TBD.

---

## Ports

- Discovered by physically sailing to them
- Each port has buildings: docks, warehouses, workshops, others (TBD)
- Port buildings can be damaged
- Damaged buildings require money/resources to repair
- **Port development:** Player can develop their own home port
  - Build/upgrade buildings
  - Expand trade network
- **Refueling:** Ports provide Fuel / Supplies replenishment

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
  - Large contracts (available via Company -- TBD)
- Contract reward = base + time bonus -- damage penalty (TBD exact formula)
- Contracts visible at port before accepting

---

## Economy

- **Income:** Cargo trading, contract rewards, TBD other sources
- **Expenses:** Fuel / Supplies, repair costs, port fees (TBD), company expenses
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

## Risk Levels

Routes and zones may have different risk levels:

| Level | Description |
|-------|-------------|
| LOW RISK | Almost safe, minimal pirate chance |
| MEDIUM RISK | Probability of pirate encounter |
| HIGH RISK | Elevated pirate/damage risk |

**Exact probabilities and combat mechanics:** TBD.

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
- Hired captains run automated trade routes on **Known Routes** only
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
| Known Routes | Automated travel, fleet operations |

---

## Achievements

- TBD full list
- Based on: deliveries, distance sailed, money earned, contracts completed, fleet size, reputation, ports discovered, routes established

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
- **Save during voyage:** Player progress is saved on app exit/background. Ship state, position, cargo, Fuel, Hull, voyage status are preserved. Player can continue the voyage on next launch.
- **No punishment for closing app:** Ship does NOT sink, cargo is NOT lost just because player closed the app.
- Offline progress calculated on next launch:
  - Fleet auto-routes generate income (on Known Routes only)
  - Company expenses deducted
  - Market prices drift
- Maximum offline progress cap: TBD (suggested 24 hours)
- Save system stores last session timestamp

---

*TBD items are design decisions not yet made. Do not invent values for them.*
