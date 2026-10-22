# Shop product art

Each shop listing uses its own 128×128 vector illustration. The navy-and-brass frame is shared across the catalog; the central symbol and accent color identify the item. Edit the SVG for one listing without affecting another.

`data/social/shop_catalog.json` points to each image through the product `icon` field. `systems/ui/company_shop_view.gd` displays that asset on both the product card and selected-product preview. Crew candidates continue to use the existing race-specific character art.

The store only lists mechanics that are implemented: ship boosts, crew-training booklets, field repair, home-port materials, premium time, clan harbor appearance, crew and ship/port cosmetics. All purchases use in-game coins in this offline build.
