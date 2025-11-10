jlee_xmas
========

Simple Christmas tree looting and box system for QBCore servers.

Features
- Lootable tree props with per-tree cooldowns and server-side anti-dupe logic
- Trade-in Christmas Coins for boxes
- Box opening with server-validated progress and configurable reward pools
- Distance-limited tree-looted notifications to reduce broadcast spam

Requirements
- QBCore framework (qb-core)
- qb-inventory (recommended for proper item visuals, optional)
- Ensure your server runs the resource and lists it in server.cfg (start jlee_xmas)

Installation
1. Place the resource folder on your server resources folder and name it `jlee_xmas`.
2. Add `start jlee_xmas` to server.cfg and restart the server (or use `start jlee_xmas` in console).
3. Configure Config.lua (see below) and restart the resource.


Add these entries to QBCore.Shared.Items (example Lua format):


 ['christmas_coin'] = {['name'] = 'christmas_coin', ['label'] = 'Christmas Coin', ['weight'] = 50, ['type'] = 'item', ['image'] = 'christmas_coin.png', ['unique'] = false, ['useable'] = false, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'A festive coin used to trade for mystery boxes.'},

['christmas_box_small'] = {['name'] = 'christmas_box_small', ['label'] = 'Small Christmas Box', ['weight'] = 500, ['type'] = 'item', ['image'] = 'christmasbox.png', ['unique'] = false, ['useable'] = false, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'A small Christmas box containing a few surprises.'},

['christmas_box_medium'] = {['name'] = 'christmas_box_medium', ['label'] = 'Medium Christmas Box', ['weight'] = 1000, ['type'] = 'item', ['image'] = 'christmasbox.png', ['unique'] = false, ['useable'] = false, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'A medium Christmas box containing better rewards.'},

['christmas_box_large'] = {['name'] = 'christmas_box_large', ['label'] = 'Large Christmas Box', ['weight'] = 2000, ['type'] = 'item', ['image'] = 'christmasbox.png', ['unique'] = false, ['useable'] = false, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'A large Christmas box with top-tier rewards.'},

Add Images from images folder to qb-inventory




Support & Customization
- You can change reward pools, cooldowns, distances, and the open duration in Config.lua.
- To reduce network usage further, consider increasing PositionUpdateInterval or lowering BroadcastRadius.

License
- Use and modify as you wish for your server. No warranty.

