CREATE TABLE IF NOT EXISTS kollusion_spawns
(
    name       TEXT PRIMARY KEY,
    world_name TEXT    NOT NULL,
    x          INTEGER NOT NULL,
    y          INTEGER NOT NULL,
    z          INTEGER NOT NULL
);
CREATE OR REPLACE PROCEDURE upsert_kollusion_spawn(spawn_name TEXT, spawn_world_name TEXT, spawn_x INTEGER,
                                                   spawn_y INTEGER,
                                                   spawn_z INTEGER)
AS
$$
INSERT INTO kollusion_spawns (name, world_name, x, y, z)
VALUES (spawn_name, spawn_world_name, spawn_x, spawn_y, spawn_z)
ON CONFLICT (name) DO UPDATE SET world_name = EXCLUDED.world_name,
                                 x          = EXCLUDED.x,
                                 y          = EXCLUDED.y,
                                 z          = EXCLUDED.z
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_random_kollusion_spawn()
    RETURNS SETOF kollusion_spawns
AS
$$
SELECT *
FROM kollusion_spawns
ORDER BY RANDOM()
LIMIT 1
$$
    LANGUAGE sql;

DROP TABLE server_tips;
CREATE UNLOGGED TABLE server_tips
(
    game_mode_name TEXT NOT NULL,
    tip_title      TEXT PRIMARY KEY,
    tip_message    TEXT NOT NULL
);
INSERT INTO server_tips (game_mode_name, tip_title, tip_message)
VALUES ('potpissers', 'piglin combat logger',
        'attacks with and consumes the player''s resources to survive. is constantly using /logout to escape'),
       ('potpissers', 'bow-boosting',
        'the bow''s legacy self-shooting mechanic has been re-introduced. punch is enabled, and uses the movement cooldown'),
       ('potpissers', 'splash potion changes',
        'potion throwing has been reverted to mimic pre-1.9, splash buffs that land due to this buff are nerfed to compensate (self splash-buffing only works when thrown directly upwards)'),
       ('potpissers', 'netherite armor pvp knockback nerf',
        'netherite armor''s knockback reduction has been disabled in pvp'),
       ('potpissers', 'netherite armor pvp toughness nerf',
        'netherite armor is equal to diamond armor in pvp if the attack is from a netherite sword/trident/mace, or if the attack isn''t melee'),
       ('potpissers', 'netherite sword pvp nerf',
        'when attacking non-netherite players: diamond and netherite swords are equal damage. when attacking netherite players: netherite swords reduce netherite armor''s protection level to diamond'),
       ('potpissers', 'slow-falling debuff nerf',
        'extended splash slow-falling''s duration has been reduced to 16 seconds'),

       ('potpissers-commands', '/party', 'network-wide parties for communication'),
       ('potpissers-commands', '/logout', 'starts a safe logout timer, avoiding the combat logger spawning'),
       ('potpissers-commands', '/helpop', 'alert-messages staff'),
       ('potpissers-commands', '/chat', 'changes your current chat channel'),

       ('cubecore', 'faction fight protection',
        'depending on the fight, cleaning is only possible if the cleaner''s numbers are greater than one side of the fight. use /f anticlean (off, on, allies)'),
       ('cubecore', 'cubecore looting',
        'looting buffs dropped xp from mobs. vanilla looting''s effect on mob drops is negated unless the mob is from an outpost (overworld spawn, nether spawn, end spawn)'),
       ('cubecore', 'villager ai',
        'vanilla villager ai is gutted (purpur). there are public villagers at spawn'),
       ('cubecore', 'villager mending',
        'the librarian villager''s mending trade is disabled, and has been swapped with 25% soul speed, 37.5% swift sneak, 37.5% wind burst'),
       ('cubecore', 'netherite gear repair',
        'the villager mending trade is disabled. repair netherite gear by crafting a netherite repair brick (one diamond, one gold, one nether brick) and using the anvil'),
       ('cubecore', 'trident rebalance (pvp)',
        'against players that are in water (not rain!), the trident''s impaling enchant has been given sharpness damage. resulting in trident + impaling doing slightly more damage than a netherite sword + sharpness if the target is in water'),
       ('cubecore', 'totem of undying nerf',
        'OFF-HANDED totems will not proc if the death is the result of a player melee attack, or an archer ranged attack. main-handed totems will work normally'),
       ('cubecore', 'mace rebalance (pvp)',
        'against players, the mace''s breach enchantment has been given sharpness damage. additionally, for crits vs players, the mace''s base damage has been increased. resulting in mace + breach doing slightly more damage than netherite + sharpness for crits'),
       ('cubecore', 'knockback enchantments',
        'knockback/punch are enabled, and use the movement cooldown'),
       ('cubecore', 'team friendly fire',
        'toggle faction friendly fire with /faction ff'),
       ('cubecore', 'pvp classes',
        'equip prot-limit leather/gold/chain/iron armor for archer/bard/rogue/warrior, respectively'),
       ('cubecore', 'miner class',
        'equip protection 0 iron armor'),
       ('cubecore', 'golden apple cooldown',
        'golden apples and enchanted golden apples have a cooldown, but they also can be spammed for a stacked cooldown + combat-tag and glowing debuff'),
       ('cubecore', 'honey bottle rebalance',
        'honey bottles have been given a cooldown. additionally, honey bottles remove slowness if no poison is present and weakness if no poison/slowness are present. honey bottles/golden apples can be spam-consumed for a stacked cooldown + combat-tag + glowing debuff'),
       ('cubecore', 'pvp class elytra use',
        'classes can swap their chestplate to elytra without losing their class status'),
       ('cubecore', 'trident riptide buff',
        'holding a riptide-enchanted trident changes your client''s weather to rain'),
       ('cubecore', 'chorus fruit cooldown',
        'chorus fruits use the movement cooldown, spam-consuming them allows for consecutive teleports with stacking cooldown + combat-tag + glowing debuff'),
       ('cubecore', 'enchantment table changes',
        'the fire aspect book enchant has been swapped for 25% soul speed, 37.5% swift sneak, 37.5% wind burst. the fire aspect sword enchant has been reduced'),
       ('cubecore', 'spawners',
        'non-warzone spawners aren''t able to be fully destroyed'),
       ('cubecore', 'custom recipes',
        'there are recipes for heavy core, elytra, totem, grapple, trident, smithing template, netherite repair brick, enchanted totem, reverted enchanted golden apple, antidote honey, antidote milk and a few more things at spawn'),
       ('cubecore', 'cubecore exp bottles',
        'exp bottle xp has been buffed to match the looting enchantment exp increase'),

--        ('cubecore-commands', '/faction', ''),
       ('cubecore-commands', '/stuck', 'starts a timer that will teleport you out of player-claimed land'),
       ('cubecore-commands', '/hcflives', 'checks your currently available hcf-lives'),
       ('cubecore-commands', '/hcfrevive', 'revives deathbanned player using your hcf-lives, if available'),

       ('cubecore_classes_items', 'class items', 'right click to activate, hold item or attack players to accelerate cooldown + activate hold effects if item has them'),
       ('cubecore_classes_items', 'sugar', 'speed. miner @ 150 diamonds + all other classes'),
       ('cubecore_classes_items', 'feather', 'jump boost. spam right-click to stack jump boost level in exchange for opple/totem cooldown. doesn''t get hold cooldown boost. miner @ 200 diamonds + all other classes'),
       ('cubecore_classes_items', 'phantom membrane', 'slow-falling hold + levitation active. same spam mechanic as feather. doesn''t get hold cooldown boost. miner @ 200 diamonds + all other classes'),
       ('cubecore_classes_items', 'ender eye', 'invisibility. miner below y16, above y16 @ 50 diamonds + all other classes'),
       ('cubecore_classes_items', 'blaze powder', 'strength. bard/warrior'),
       ('cubecore_classes_items', 'iron ingot', 'resistance. bard/warrior'),
       ('cubecore_classes_items', 'ghast tear', 'regen. bard/warrior'),
       ('cubecore_classes_items', 'glistering melon slice', 'health boost hold + instant health active. bard/warrior'),
       ('cubecore_classes_items', 'magma cream', 'fire resistance. bard/warrior/miner below y16, above y16 @ 100 diamonds'),
       ('cubecore_classes_items', 'pufferfish', 'water-breathing. bard/warrior/miner below y16, above y16 @ 100 diamonds'),
       ('cubecore_classes_items', 'gold ingot', 'bard/warrior/miner: can use raw gold, upgrades @ 300 diamonds'),
       ('cubecore_classes_items', 'wheat', 'exhaustion removal hold + saturation active. bard/warrior/miner @ 250 diamonds'),
       ('cubecore_classes_items', 'fermented spider eye', 'slowness. all classes except miner'),
       ('cubecore_classes_items', 'bowl', 'hunger. all classes except miner'),
       ('cubecore_classes_items', 'ink sac', 'weakness. bard/warrior/tag archer'),
       ('cubecore_classes_items', 'spider eye', 'poison. warrior/rogue^/damage archer'),
       ('cubecore_classes_items', 'rabbit''s foot', 'slow-falling debuff. warrior/rogue^/damage archer'),
       ('cubecore_classes_items', 'coal', 'wither. warrior/rogue^/damage archer'),
       ('cubecore_classes_items', 'charcoal', 'miner''s fatigue. bard/warrior/miner @ 300 diamonds'),

       ('cubecore_classes', 'tag archer', '- armor bonus
                    - passive speed 1 + extra speed on hit
                    - class items: use /classitems
                    - attacks tag enemies, resulting in increased melee damage on hit for teammates
                    - projectile damage affected by strength/weakness
                    - harmful projectiles pass through teammates, buff arrows pass through enemies
                    - sweep attacks enabled on players
                    - slowness/weakness debuffs pass through teammates'),
       ('cubecore_classes', 'tag rogue', '- armor bonus
                    - passive speed 1 + extra speed on hit
                    - class items: use /classitems
                    - melee attacks tag enemies, resulting in increased melee damage on hit for teammates
                    - sweep attacks enabled on players
                    - harmful projectiles pass through teammates'),
       ('cubecore_classes', 'bard', '- armor bonus
                    - aoe class items: use /classitems
                    - buff effects negated on enemies, slowness/weakness effects negated on allies
                    - slowness/weakness arrows pass through teammates, beneficial arrows pass through enemies""", "warrior", """
                    - armor bonus
                    - class items: use /classitems
                    - debuff effects negated on teammates
                    - debuff arrows pass through teammates""", "damage archer", """
                    - armor bonus
                    - passive speed 1 + extra speed on hit
                    - class items: use /classitems
                    - attack damage is boosted by continuously attacking
                    - projectile damage affected by strength/weakness
                    - harmful projectiles pass through teammates
                    - sweep attacks enabled on players
                    - gold swords can true damage back-stab enemies'),
       ('cubecore_classes', 'damage rogue', '- armor bonus
                    - passive speed 1 + extra speed on hit
                    - class items: use /classitems
                    - melee attack damage is boosted by continuously attacking
                    - sweep attacks enabled on players
                    - harmful projectiles pass through teammates
                    - gold swords can true-damage back-stab enemies'),
       ('cubecore_classes', 'miner', '- passive haste 1, holding gold gives haste 2, activating gold gives haste 3
                    - class items: use /classitems
                    - mining past diamond ore thresholds upgrades your miner class'' abilities: use /classitems
                    - 50 ores mined: passive invisibility below y 16. 100 ores mined: passive fire resistance + water-breathing below y 16. 150 ores mined: passive speed 1 + sugar class item unlocked. 200 ores mined: feather/membrane class items unlocked. 250 ores mined: wheat class item unlocked + passive saturation below y 16, 300 ores mined: upgraded haste + miner''s fatigue class item unlocked. 350 ores mined: glow ink sac class item unlocked'),

       ('cubecore_recipes', 'potpissers recipes',
        'all custom recipes are shapeless, just slam the ingredients into the crafting window'),
       ('cubecore_recipes', 'recipe: grapple', '- 1.)
                                               1 fishing rod, 4 iron blocks, 4 copper blocks:
                                               ⬜️ 🟧️ ⬜️
                                               🟧️ 🎣 🟧️
                                               ⬜️ 🟧️ ⬜️
                                               - 2.)
                                               1 fishing rod, 8 iron blocks
                                               ⬜️ ⬜️ ⬜️
                                               ⬜️ 🎣 ⬜️
                                               ⬜️ ⬜️ ⬜️'),
       ('cubecore_recipes', 'recipe: enchanted golden apple', '1 apple, 8 gold blocks
                                                              🟨️ 🟨️ 🟨️️
                                                              🟨️️ 🍎 🟨️️
                                                              🟨️️ 🟨️️ 🟨️️'),
       ('cubecore_recipes', 'recipe: totem of undying', '3 emerald blocks, 4 gold ingots
                                                        🟩️️️️️️ 🟩️️️️ 🟩️️️️️️️
                                                        🟡️️️️ 🟡️️️️ 🟡️️️️
                                                        ❌️️️️ 🟡️️️️ ❌️️️️'),
       ('cubecore_recipes', 'recipe: cubecore reverted opple', '1 enchanted golden apple, 8 emerald blocks
                                                      🟩️ 🟩️ 🟩️
                                                      🟩️ 🍊 🟩️
                                                      🟩️ 🟩️ 🟩️'),
       ('cubecore_recipes', 'recipe: cubecore opple totem', '1 totem of undying, 8 gold blocks
                                                   🟨️️ 🟨️️ 🟨️️
                                                   🟨️️ 🗿 🟨️️
                                                   🟨️️ 🟨️️ 🟨️️'),
       ('cubecore_recipes', 'recipe: elytra', '4 diamond blocks, 4 phantom membrane, 1 popped chorus fruit
                                              👻 🟦️️ 👻
                                              🟦️ 🍍 🟦️
                                              👻 🟦️ 👻'),
       ('cubecore_recipes', 'recipe: trident',
        '4 diamond blocks, 2 prismarine shards, 1 prismarine crystal, 1 nautilus shell, 1 ink sac
        🟦️️ ❄️ 🟦️
        🪨️ 🐚 🪨️
        🟦️ 🫟 🟦️'),
       ('cubecore_recipes', 'recipe: antidote honey', '- 1.)
                                                      1 honey bottle, 8 lapis lazuli
                                                      🔹 🔹 🔹
                                                      🔹 🍯 🔹
                                                      🔹 🔹 🔹
                                                      - 2.)
                                                      1 honey bottle, 8 coal
                                                      ▪️ ▪️ ▪️
                                                      ▪️ 🍯 ▪️
                                                      ▪️ ▪️ ▪️
                                                      - 3.)
                                                      1 honey bottle, 4 lapis lazuli, 4 coal
                                                      🔹 ▪️ 🔹
                                                      ▪️ 🍯️ ▪️
                                                      🔹️ ▪️ 🔹️'),
       ('cubecore_recipes', 'recipe: antidote milk', '- 1.)
                                                     1 milk bucket, 8 lapis lazuli blocks
                                                     🟦️ 🟦️ 🟦️
                                                     🟦️ 🍯 🟦️
                                                     🟦️ 🟦️ 🟦️
                                                     - 2.)
                                                     1 milk bucket, 8 coal blocks
                                                     ⬛️ ⬛️ ⬛️
                                                     ⬛️ 🍯 ⬛️
                                                     ⬛️ ⬛️ ⬛️
                                                     - 3.)
                                                     1 milk bucket, 4 lapis lazuli blocks, 4 coal blocks
                                                     🟦️ ⬛️ 🟦️
                                                     ⬛️ 🍯️ ⬛️
                                                     🟦️ ⬛️ 🟦️'),
       ('cubecore_recipes', 'recipe: emerald/emerald block',
        '- 1.)
        1 diamond/block, 1 iron ingot/block, 1 copper ingot/block, respectively
        ❌️ ❌️ ❌️
        🟦️️ ⬜️️ 🟧️️️
        ❌️ ❌️ ❌️
        - 2.)
        2 gold ingots/blocks, respectively
        ❌️ ❌️ ❌️
        🟨️️ 🟨️️ ❌️
        ❌️ ❌️ ❌️'),
       ('cubecore_recipes', 'recipe: coal block', -- TODO -> potpissers recipes. this + opple (?) at least
        '9 charcoal
        ▪️️ ▪️️ ▪️️
        ▪️️ ▪️️ ▪️️
        ▪️️ ▪️️ ▪️️'),
       ('cubecore_recipes', 'recipe: netherite upgrade smithing template',
        '7 diamonds, 1 netherrack
        💎️️ ❌️️️ 💎️️
        💎️️ 🟫️️ 💎️️
        💎️ 💎️ 💎️️'),
       ('cubecore_recipes', 'recipe: heart of the sea',
        '8 diamond blocks, 1 nautilus shell
        🟦️️️ 🟦️️️️ 🟦️️️
        🟦️️️ 🐚️️ 🟦️️
        🟦️️ 🟦️️️ 🟦️️️'),
       ('cubecore_recipes', 'recipe: netherite repair brick',
        '1 gold ingot, 1 nether brick, one diamond
        ❌️️️️️️ ❌️️️️️️️ ❌️️️️️️
        🟡️️️ 👞️️ 💎️️
        ❌️️️️️ ❌️️️️️️ ❌️️️️️'),
       ('cubecore_recipes', 'recipe: heavy core',
        '2 diamond blocks, 2 netherite ingots, 4 iron blocks, 1 copper block
        🟦️️️️️️️ ⬜️️️️️️️️ 🟦️️️️️️️
        ⬜️️️️ 🟧️️️️️ ⬜️️️
        ⚫️️️️️ ⬜️️️️️️ ⚫️️️️️'),

       ('kollusion', 'kollusion enchanted repair buff',
        'crafting menu repairing passes the least common enchantments to the result item. (repairing two ff4 boots together doesn''t remove the ff4)'),
       ('kollusion', 'kollusion elytras', 'found elytras break very quickly'),
       ('kollusion', 'kollusion splash 2s',
        'splash instant health 2s aren''t exempt from the standard potpissers splash potion nerf. (they are 85% effective unless thrown directly upwards)'),
       ('kollusion', 'kollusion instant health + golden apple buff',
        'instant health potions and golden apples has been buffed to 1.6 minecraft''s levels, +50%'),
       ('kollusion', 'kollusion speed potions/other rare consumables',
        'speed potions and other brewable potions/rare consumables all share the same cooldown'),

       ('kollusion-commands', '/mzspawn', 'when used from within spawn, teleports you into the world'),
       ('kollusion-commands', '/mzlives', 'checks your currently available mz-lives'),
       ('kollusion-commands', '/mzrevive', 'removes active alt-ban from player using your mz-lives, if available');
CREATE OR REPLACE FUNCTION get_tips()
    RETURNS TABLE
            (
                game_mode_name TEXT,
                tip_title      TEXT,
                tip_message    TEXT
            )
AS
$$
SELECT *
FROM server_tips;
$$ LANGUAGE sql;