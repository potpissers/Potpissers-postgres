--TODO -> users id table (?)

CREATE TABLE IF NOT EXISTS user_referrals
(
    user_uuid UUID PRIMARY KEY,
    referrer  TEXT,
    timestamp TIMESTAMPTZ NOT NULL
);
--TODO -> ip referrals, salt definitely necessary
--TODO -> hash ips

DROP TABLE chat_ranks;
CREATE TABLE chat_ranks
(
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);
INSERT INTO chat_ranks (id, name)
VALUES (0, 'admin'),
       (1, 'mod'),
       (2, 'watcher'),

       (3, 'unverified'),
       (4, 'default'),
       (5, 'basic'),
       (6, 'gold'),
       (7, 'diamond'),
       (8, 'ruby'),
       (9, 'big dog');

DROP TABLE line_items;
CREATE TABLE line_items
(
    id             INTEGER PRIMARY KEY,
    game_mode_name TEXT    NOT NULL,
    line_item_name TEXT    NOT NULL,
    value_in_cents INTEGER NOT NULL,
    description    TEXT    NOT NULL,
    is_plural      BOOLEAN NOT NULL,
    chat_rank_id   INTEGER
);
INSERT INTO line_items (id, game_mode_name, line_item_name, value_in_cents, description, is_plural)
VALUES (0, 'hcf', 'life', 400,
        '/revive (username). removes deathban (alts aren''t affected). current revive life cost: /lives', true),
       (1, 'hcf', 'basic', 800, 'green name, basic server slot, and revive cost + deathban reduced to 80%', false),
       (2, 'hcf', 'gold', 1600, 'yellow name, gold server slot, and revive cost + deathban reduced to 60%', false),
       (3, 'hcf', 'diamond', 2400, 'aqua name, diamond server slot, and revive cost + deathban reduced to 40%', false),
       (4, 'hcf', 'ruby', 3200, 'red name, ruby server slot, and revive cost + deathban reduced to 20%', false),
       (5, 'mz', 'life', 400, '/revive (username). removes alt deathban', true),
       (6, 'mz', 'basic', 600, 'green name, basic server slot', false),
       (7, 'mz', 'gold', 1200, 'yellow name, gold server slot', false),
       (8, 'mz', 'diamond', 1800, 'aqua name, diamond server slot', false),
       (9, 'mz', 'ruby', 2400, 'red name, ruby server slot', false);

DROP TABLE server_tips;
CREATE TABLE server_tips
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

       ('cubecore_classes',
        'class items: right click to activate, hold item or attack players to accelerate cooldown + activate hold effects if item has them', '- sugar: speed. miner @ 150 diamonds + all other classes
                    - feather: jump boost. spam right-click to stack jump boost level in exchange for opple/totem cooldown. doesn''t get hold cooldown boost. miner @ 200 diamonds + all other classes
                    - phantom membrane: slow-falling hold + levitation active. same spam mechanic as feather. doesn''t get hold cooldown boost. miner @ 200 diamonds + all other classes
                    - ender eye: invisibility. miner below y16, above y16 @ 50 diamonds + all other classes

                    - blaze powder: strength. bard/warrior
                    - iron ingot: resistance. bard/warrior
                    - ghast tear: regen. bard/warrior

                    - glistering melon slice: health boost hold + instant health active. bard/warrior
                    - magma cream: fire resistance. bard/warrior/miner below y16, above y16 @ 100 diamonds
                    - pufferfish: water-breathing. bard/warrior/miner below y16, above y16 @ 100 diamonds
                    - gold ingot: bard/warrior/miner: can use raw gold, upgrades @ 300 diamonds
                    - wheat: exhaustion removal hold + saturation active. bard/warrior/miner @ 250 diamonds

                    - fermented spider eye: slowness. all classes except miner
                    - bowl: hunger. all classes except miner
                    - ink sac: weakness. bard/warrior/tag archer
                    - spider eye: poison. warrior/rogue^/damage archer
                    - rabbit''s foot. slow-falling debuff. warrior/rogue^/damage archer
                    - coal: wither. warrior/rogue^/damage archer
                    - charcoal: miner''s fatigue. bard/warrior/miner @ 300 diamonds'),
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
                    - 50 ores mined: passive invisibility below y 16. 100 ores mined: passive fire resistance + water-breathing below y 16. 150 ores mined: passive speed 1 + sugar class item unlocked. 200 ores mined: feather/membrane class items unlocked. 250 ores mined: wheat class item unlocked + passive saturation below y 16, 300 ores mined: upgraded haste + miner''s fatigue class item unlocked. 350 ores mined: glow ink sac class item unlocked');

CREATE TABLE IF NOT EXISTS successful_transactions
(
    id                    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    square_order_id       TEXT,
    transaction_hash      TEXT,
    user_uuid             UUID    NOT NULL,
    line_item_id          INTEGER NOT NULL,
    line_item_player_name TEXT    NOT NULL,
    line_item_quantity    INTEGER NOT NULL,
    amount_as_cents       INTEGER NOT NULL,
    timestamp             TIMESTAMPTZ DEFAULT NOW(),
    referrer              TEXT
);

DROP TABLE chat_types;
CREATE TABLE chat_types
(
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);
INSERT INTO chat_types (id, name)
VALUES (0, 'local'),
       (1, 'server'),
       (2, 'network'),

       (3, 'party'),
       (4, 'faction'),
       (5, 'ally'),
       (6, 'enemy'),
       (7, 'fight');

CREATE TABLE IF NOT EXISTS user_data
(
    user_uuid            UUID PRIMARY KEY,
    chat_type_id         INTEGER DEFAULT '1', -- default -> all chat
    is_all_chat_disabled BOOLEAN DEFAULT FALSE,
    java_personal_mutes  BYTEA,
    party_uuid           UUID
);

CREATE TABLE IF NOT EXISTS servers
(
    id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS online_players
(
    user_uuid UUID PRIMARY KEY,
    user_name TEXT    NOT NULL,
    server_id INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE
);

DROP TABLE attack_speeds;
CREATE TABLE attack_speeds
(
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);
INSERT INTO attack_speeds (id, name)
VALUES (0, 'vanilla'),
       (1, 'reverted vanilla'),
       (2, '7cps'),
       (3, '12cps'),
       (4, 'uncapped');

CREATE TABLE IF NOT EXISTS server_data
(
    server_id                         INTEGER PRIMARY KEY,
    attack_speed_id                   INTEGER DEFAULT 2, -- default 7cps
    death_ban_minutes                 INTEGER DEFAULT 0,
    world_border_radius               INTEGER DEFAULT 1250,
    default_kit_name                  TEXT    DEFAULT NULL,
    sharpness_limit                   INTEGER DEFAULT 0,
    power_limit                       INTEGER DEFAULT 0,
    protection_limit                  INTEGER DEFAULT 0,
    bard_regen_level                  INTEGER DEFAULT 0,
    bard_strength_level               INTEGER DEFAULT 0,
    is_weakness_enabled               BOOLEAN DEFAULT FALSE,
    is_bard_passive_debuffing_enabled BOOLEAN DEFAULT FALSE,
    dtr_freeze_timer                  INTEGER DEFAULT 0,
    dtr_max                           REAL    DEFAULT 5.5,
    dtr_max_time                      INTEGER DEFAULT 480,
    dtr_off_peak_freeze_time          INTEGER DEFAULT 480,
    dtr_peak_freeze_time              INTEGER DEFAULT 960,
    off_peak_lives_needed_as_cents    INTEGER DEFAULT 100,
    bard_radius                       INTEGER DEFAULT 15,
    rogue_radius                      INTEGER DEFAULT 5,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS player_attack_speeds
(
    user_uuid       UUID,
    server_id       INTEGER,
    attack_speed_id INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    PRIMARY KEY (user_uuid, server_id)
);

CREATE TABLE IF NOT EXISTS server_player_highest_counts
(
    id           INTEGER PRIMARY KEY,
    server_id    INTEGER     NOT NULL,
    player_count INTEGER     NOT NULL,
    timestamp    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS server_location_warps
(
    server_id  INTEGER NOT NULL,
    world_name TEXT    NOT NULL,
    x          INTEGER NOT NULL,
    y          INTEGER NOT NULL,
    z          INTEGER NOT NULL,
    name       TEXT    NOT NULL,
    PRIMARY KEY (server_id, world_name, x, y, z)
);

CREATE TABLE IF NOT EXISTS loot_tables
(
    id              INTEGER GENERATED ALWAYS AS IDENTITY UNIQUE,
    server_id       INTEGER NOT NULL,
    loot_table_name TEXT    NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    PRIMARY KEY (server_id, loot_table_name)
);

CREATE TABLE IF NOT EXISTS loot_table_entries
(
    loot_table_id INTEGER,
    entry_name    TEXT,
    entry_chance  DOUBLE PRECISION,
    FOREIGN KEY (loot_table_id) REFERENCES loot_tables (id) ON DELETE CASCADE,
    PRIMARY KEY (loot_table_id, entry_name, entry_chance)
);

CREATE TABLE IF NOT EXISTS server_loot_chests
(
    server_id     INTEGER NOT NULL,
    world_name    TEXT    NOT NULL,
    x             INTEGER NOT NULL,
    y             INTEGER NOT NULL,
    z             INTEGER NOT NULL,
    loot_table_id INTEGER NOT NULL,
    min_amount    INTEGER NOT NULL,
    loot_variance INTEGER NOT NULL,
    restock_time  INTEGER NOT NULL,
    direction     TEXT,
    block_type    TEXT    NOT NULL,
    FOREIGN KEY (loot_table_id) REFERENCES loot_tables (id),
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    PRIMARY KEY (server_id, world_name, x, y, z)
);

CREATE TABLE IF NOT EXISTS kollusion_spawns
(
    name       TEXT PRIMARY KEY,
    world_name TEXT    NOT NULL,
    x          INTEGER NOT NULL,
    y          INTEGER NOT NULL,
    z          INTEGER NOT NULL
);
-- TODO

CREATE TABLE IF NOT EXISTS playtimes
(
    user_uuid      UUID,
    server_id      INTEGER,
    minutes_played INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    PRIMARY KEY (user_uuid, server_id)
);
CREATE TABLE IF NOT EXISTS ip_exempt_uuids
(
    user_uuid UUID,
    server_id INTEGER,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    PRIMARY KEY (user_uuid, server_id)
);

CREATE TABLE IF NOT EXISTS kits
(
    id                     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kit_name               TEXT UNIQUE NOT NULL,
    bukkit_default_loadout BYTEA       NOT NULL
);
CREATE TABLE IF NOT EXISTS server_consumable_kits
(
    id                  INTEGER GENERATED ALWAYS AS IDENTITY UNIQUE NOT NULL,
    server_id           INTEGER                                     NOT NULL,
    kit_name            TEXT                                        NOT NULL,
    bukkit_kit_contents BYTEA                                       NOT NULL,
    cooldown            INTEGER,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    PRIMARY KEY (server_id, kit_name)
);
CREATE TABLE IF NOT EXISTS user_consumable_kits_history
(
    user_uuid UUID,
    kit_id    INTEGER,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_uuid, kit_id, timestamp)
);
CREATE TABLE IF NOT EXISTS user_personal_kits
(
    user_uuid      UUID,
    kit_id         INTEGER,
    bukkit_loadout BYTEA NOT NULL,
    loadout_name   TEXT  NOT NULL,
    FOREIGN KEY (kit_id) REFERENCES kits (id) ON DELETE CASCADE,
    PRIMARY KEY (user_uuid, kit_id)
);

CREATE TABLE IF NOT EXISTS user_staff_ranks
(
    user_uuid    UUID,
    server_id    INTEGER,
    chat_rank_id INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    PRIMARY KEY (user_uuid, server_id)
);

CREATE TABLE IF NOT EXISTS user_chat_mods
(
    user_uuid UUID,
    server_id INTEGER,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    PRIMARY KEY (user_uuid, server_id)
);

CREATE TABLE IF NOT EXISTS user_punishments
(
    id               INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_uuid        UUID        NOT NULL,
    server_id        INTEGER     NOT NULL,
    is_mute_else_ban BOOLEAN     NOT NULL,
    timestamp        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reason           TEXT        NOT NULL,
    expiration       TIMESTAMPTZ NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS user_current_punishments
(
    punishment_id INTEGER PRIMARY KEY,
    ip            TEXT,
    FOREIGN KEY (punishment_id) REFERENCES user_punishments (id)
);

DROP TABLE party_ranks;
CREATE TABLE party_ranks
(
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);
INSERT INTO party_ranks (id, name)
VALUES (0, 'member'),
       (1, 'officer'),
       (2, 'co-leader'),
       (3, 'leader');

CREATE TABLE IF NOT EXISTS party_invites
(
    user_uuid    UUID,
    party_uuid   UUID,
    inviter_uuid UUID    NOT NULL,
    rank_id      INTEGER NOT NULL,
    timestamp    TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_uuid, party_uuid)
);

CREATE TABLE IF NOT EXISTS party_ally_invites
(
    inviter_party_uuid UUID,
    invited_party_uuid UUID,
    inviter_user_uuid  UUID,
    timestamp          TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (inviter_party_uuid, invited_party_uuid)
);

CREATE TABLE IF NOT EXISTS current_parties_relations
(
    party_uuid         UUID,
    party_arg_uuid     UUID,
    is_ally_else_enemy BOOLEAN NOT NULL,
    PRIMARY KEY (party_uuid, party_arg_uuid)
);

CREATE TABLE IF NOT EXISTS current_parties_members
(
    user_uuid  UUID PRIMARY KEY,
    party_uuid UUID    NOT NULL,
    rank_id    INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS one_leader_per_party ON current_parties_members (party_uuid) WHERE rank_id = 4; -- party_ranks -> leader


CREATE TABLE IF NOT EXISTS factions
(
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    party_uuid UUID    NOT NULL,
    name       TEXT    NOT NULL,
    server_id  INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS faction_timestamps
(
    faction_id INTEGER,
    timestamp  TIMESTAMPTZ DEFAULT NOW(),
    reason     TEXT,
    user_uuid  UUID,
    FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE,
    PRIMARY KEY (faction_id, timestamp, reason)
);

CREATE TABLE IF NOT EXISTS current_factions_members
(
    user_uuid  UUID PRIMARY KEY,
    faction_id INTEGER NOT NULL,
    rank_id    INTEGER NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id)
);

CREATE TABLE IF NOT EXISTS faction_data
(
    faction_id          INTEGER PRIMARY KEY,
    current_minimum_dtr REAL        DEFAULT 0,
    frozen_until        TIMESTAMPTZ DEFAULT NOW(),
    balance             INTEGER     DEFAULT 0,
    home_world_name     TEXT,
    home_x              DOUBLE PRECISION,
    home_y              DOUBLE PRECISION,
    home_z              DOUBLE PRECISION,
    home_pitch          REAL,
    home_yaw            REAL,
    FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS faction_current_dtr_regen_players
(
    faction_id INTEGER,
    user_uuid  UUID,
    FOREIGN KEY (faction_id) REFERENCES factions (id),
    PRIMARY KEY (faction_id, user_uuid)
);

CREATE TABLE IF NOT EXISTS fights
(
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fight_uuid UUID    NOT NULL,
    server_id  INTEGER NOT NULL,
    UNIQUE (fight_uuid, server_id),
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_fights
(
    id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_uuid UUID    NOT NULL,
    fight_id  INTEGER NOT NULL,
    FOREIGN KEY (fight_id) REFERENCES fights (id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS user_fights_data
(
    user_fight_id   INTEGER PRIMARY KEY,
    faction_id      INTEGER,
    join_timestamp  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    leave_timestamp TIMESTAMPTZ,
    join_world      TEXT        NOT NULL,
    leave_world     TEXT,
    join_x          INTEGER     NOT NULL,
    join_y          INTEGER     NOT NULL,
    join_z          INTEGER     NOT NULL,
    leave_x         INTEGER,
    leave_y         INTEGER,
    leave_z         INTEGER,
    FOREIGN KEY (user_fight_id) REFERENCES user_fights (id) ON DELETE CASCADE,
    FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_deaths
(
    id                      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    server_id               INTEGER     NOT NULL,
    victim_user_fight_id    INTEGER,
    timestamp               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    victim_uuid             UUID        NOT NULL,
    bukkit_victim_inventory BYTEA       NOT NULL,
    death_world             TEXT        NOT NULL,
    death_x                 INTEGER     NOT NULL,
    death_y                 INTEGER     NOT NULL,
    death_z                 INTEGER     NOT NULL,
    death_message           TEXT        NOT NULL,
    killer_uuid             UUID,
    bukkit_kill_weapon      BYTEA,
    bukkit_killer_inventory BYTEA,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    FOREIGN KEY (victim_user_fight_id) REFERENCES user_fights (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS current_heroes
(
    user_uuid            UUID,
    server_id            INTEGER,
    ip                   TEXT        NOT NULL,
    expiration_timestamp TIMESTAMPTZ NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    PRIMARY KEY (user_uuid, server_id)
);
CREATE TABLE IF NOT EXISTS bandits
(
    id                   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_uuid            UUID        NOT NULL,
    server_id            INTEGER     NOT NULL,
    death_id             INTEGER     NOT NULL,
    expiration_timestamp TIMESTAMPTZ NOT NULL,
    bandit_message       TEXT        NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    FOREIGN KEY (death_id) REFERENCES user_deaths (id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS current_bandits
(
    bandit_id INTEGER PRIMARY KEY,
    ip        TEXT NOT NULL,
    FOREIGN KEY (bandit_id) REFERENCES bandits (id)
);

CREATE TABLE IF NOT EXISTS deathbans
(
    death_id   INTEGER PRIMARY KEY,
    expiration TIMESTAMPTZ NOT NULL,
    FOREIGN KEY (death_id) REFERENCES user_deaths (id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS current_deathbans
(
    deathban_id INTEGER PRIMARY KEY,
    ip          TEXT,
    FOREIGN KEY (deathban_id) REFERENCES deathbans (death_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS revives
(
    user_uuid UUID,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    server_id INTEGER NOT NULL,
    reason    TEXT    NOT NULL,
    PRIMARY KEY (user_uuid, timestamp)
);

CREATE TABLE IF NOT EXISTS arena_data
(
    id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name    TEXT UNIQUE NOT NULL,
    creator TEXT        NOT NULL
);

CREATE TABLE IF NOT EXISTS user_duels_data
(
    fight_id                  INTEGER PRIMARY KEY,
    kit_id                    INTEGER NOT NULL,
    arena_data_id             INTEGER NOT NULL,
    attack_speed_id           INTEGER NOT NULL,
    bukkit_starting_inventory BYTEA   NOT NULL,
    bukkit_ending_inventory   BYTEA   NOT NULL,
    FOREIGN KEY (fight_id) REFERENCES user_fights (id) ON DELETE CASCADE,
    FOREIGN KEY (kit_id) REFERENCES kits (id) ON DELETE CASCADE,
    FOREIGN KEY (arena_data_id) REFERENCES arena_data (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS faction_fights
(
    fight_uuid UUID,
    faction_id INTEGER,
    start_dtr  REAL NOT NULL,
    end_dtr    REAL,
    FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE,
    PRIMARY KEY (faction_id, fight_uuid)
);
CREATE TABLE IF NOT EXISTS faction_deaths
(
    death_id                     INTEGER PRIMARY KEY,
    victim_faction_id            INTEGER NOT NULL,
    victim_faction_original_dtr  REAL    NOT NULL,
    victim_faction_resulting_dtr REAL    NOT NULL,
    killer_faction_id            INTEGER,
    FOREIGN KEY (victim_faction_id) REFERENCES factions (id) ON DELETE CASCADE,
    FOREIGN KEY (killer_faction_id) REFERENCES factions (id) ON DELETE CASCADE
);

CREATE SEQUENCE IF NOT EXISTS server_arenas_sequence START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS server_arenas
(
    id        INTEGER NOT NULL DEFAULT nextval('server_arenas_sequence'),
    arena_id  INTEGER NOT NULL,
    server_id INTEGER NOT NULL,
    FOREIGN KEY (arena_id) REFERENCES arena_data (id),
    FOREIGN KEY (server_id) REFERENCES servers (id),
    PRIMARY KEY (arena_id, server_id)
);
CREATE TABLE IF NOT EXISTS server_koths
(
    id        INTEGER DEFAULT nextval('server_arenas_sequence') UNIQUE NOT NULL,
    arena_id  INTEGER,
    server_id INTEGER,
    world     TEXT                                                     NOT NULL,
    x         INTEGER                                                  NOT NULL,
    y         INTEGER                                                  NOT NULL,
    z         INTEGER                                                  NOT NULL,
    FOREIGN KEY (arena_id) REFERENCES arena_data (id) ON DELETE CASCADE,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    PRIMARY KEY (arena_id, server_id)
);

CREATE TABLE IF NOT EXISTS koths
(
    id                        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    server_koths_id           INTEGER NOT NULL,
    start_timestamp           TIMESTAMPTZ DEFAULT NOW(),

    loot_factor               INTEGER NOT NULL,
    max_timer                 INTEGER NOT NULL,
    is_movement_restricted    BOOLEAN NOT NULL,

    capping_user_uuid         UUID,
    started_capping_timestamp TIMESTAMPTZ,

    end_timestamp             TIMESTAMPTZ,
    capping_party_uuid        UUID,
    cap_message               TEXT,
    FOREIGN KEY (server_koths_id) REFERENCES server_koths (id)
);
CREATE TABLE IF NOT EXISTS koths_timestamps
(
    koth_id   INTEGER,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    reason    TEXT NOT NULL,
    FOREIGN KEY (koth_id) REFERENCES koths (id) ON DELETE CASCADE,
    PRIMARY KEY (koth_id, timestamp, reason)
);

CREATE TABLE IF NOT EXISTS user_zombies_killed
(
    user_uuid UUID,
    server_id INTEGER,
    amount    INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id),
    PRIMARY KEY (user_uuid, server_id)
);
CREATE TABLE IF NOT EXISTS user_giant_timestamps
(
    user_uuid  UUID,
    server_id  INTEGER,
    timestamp  TIMESTAMPTZ DEFAULT NOW(),
    faction_id INTEGER,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE,
    PRIMARY KEY (user_uuid, server_id, timestamp)
);
CREATE TABLE IF NOT EXISTS user_opple_timestamps
(
    user_uuid     UUID,
    server_id     INTEGER,
    timestamp     TIMESTAMPTZ DEFAULT NOW(),
    faction_id    INTEGER,
    user_fight_id INTEGER,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE,
    FOREIGN KEY (user_fight_id) REFERENCES user_fights (id) ON DELETE CASCADE,
    PRIMARY KEY (user_uuid, server_id, timestamp)
);
CREATE TABLE IF NOT EXISTS user_totem_timestamps
(
    user_uuid     UUID,
    server_id     INTEGER,
    timestamp     TIMESTAMPTZ DEFAULT NOW(),
    faction_id    INTEGER,
    user_fight_id INTEGER,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE,
    FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE,
    FOREIGN KEY (user_fight_id) REFERENCES user_fights (id) ON DELETE CASCADE,
    PRIMARY KEY (user_uuid, server_id, timestamp)
);
CREATE TABLE IF NOT EXISTS user_diamond_ores_mined
(
    user_uuid UUID,
    server_id INTEGER,
    amount    INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id),
    PRIMARY KEY (user_uuid, server_id)
);
CREATE TABLE IF NOT EXISTS user_netherite_mined
(
    user_uuid UUID,
    server_id INTEGER,
    amount    INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id),
    PRIMARY KEY (user_uuid, server_id)
); --TODO more complicated, impl
CREATE TABLE IF NOT EXISTS user_ender_pearls_farmed
(
    user_uuid UUID,
    server_id INTEGER,
    amount    INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id),
    PRIMARY KEY (user_uuid, server_id)
);
CREATE TABLE IF NOT EXISTS user_gunpowder_farmed
(
    user_uuid UUID,
    server_id INTEGER,
    amount    INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id),
    PRIMARY KEY (user_uuid, server_id)
);
CREATE TABLE IF NOT EXISTS user_experience_acquired
(
    user_uuid UUID,
    server_id INTEGER,
    amount    INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id),
    PRIMARY KEY (user_uuid, server_id)
);
CREATE TABLE IF NOT EXISTS user_potions_brewed
(
    user_uuid UUID,
    server_id INTEGER,
    amount    INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id),
    PRIMARY KEY (user_uuid, server_id)
); --TODO set metadata from water bottle to potion i guess. probably too much overhead to be worth it

CREATE TABLE IF NOT EXISTS faction_diamond_ores_mined
(
    faction_id INTEGER PRIMARY KEY,
    amount     INTEGER NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id)
);
CREATE TABLE IF NOT EXISTS faction_netherite_mined
(
    faction_id INTEGER PRIMARY KEY,
    amount     INTEGER NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id)
); --TODO -> impl
CREATE TABLE IF NOT EXISTS faction_ender_pearls_farmed
(
    faction_id INTEGER PRIMARY KEY,
    amount     INTEGER NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id)
);
CREATE TABLE IF NOT EXISTS faction_gunpowder_farmed
(
    faction_id INTEGER PRIMARY KEY,
    amount     INTEGER NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id)
);
CREATE TABLE IF NOT EXISTS faction_experience_acquired
(
    faction_id INTEGER PRIMARY KEY,
    amount     INTEGER NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id)
);
CREATE TABLE IF NOT EXISTS faction_potions_brewed
(
    faction_id INTEGER PRIMARY KEY,
    amount     INTEGER NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id)
); --TODO set metadata from water bottle to potion i guess. probably too much overhead to be worth it

CREATE TABLE IF NOT EXISTS fight_damage
(
    user_fight_id INTEGER,
    victim_uuid   UUID,
    amount        DOUBLE PRECISION NOT NULL,
    FOREIGN KEY (user_fight_id) REFERENCES user_fights (id),
    PRIMARY KEY (user_fight_id, victim_uuid)
);
CREATE TABLE IF NOT EXISTS fight_hits
(
    user_fight_id INTEGER,
    victim_uuid   UUID,
    amount        DOUBLE PRECISION NOT NULL,
    FOREIGN KEY (user_fight_id) REFERENCES user_fights (id),
    PRIMARY KEY (user_fight_id, victim_uuid)
);
CREATE TABLE IF NOT EXISTS fight_shots
(
    user_fight_id INTEGER,
    victim_uuid   UUID,
    amount        DOUBLE PRECISION NOT NULL,
    FOREIGN KEY (user_fight_id) REFERENCES user_fights (id),
    PRIMARY KEY (user_fight_id, victim_uuid)
);
CREATE TABLE IF NOT EXISTS fight_debuffs
(
    victim_fight_id INTEGER,
    killer_uuid     UUID,
    amount          DOUBLE PRECISION NOT NULL,
    FOREIGN KEY (victim_fight_id) REFERENCES user_fights (id) ON DELETE CASCADE,
    PRIMARY KEY (victim_fight_id, killer_uuid)
);
CREATE TABLE IF NOT EXISTS fight_amplified_damage
(
    fight_id    INTEGER,
    victim_uuid UUID,
    amount      DOUBLE PRECISION NOT NULL,
    FOREIGN KEY (fight_id) REFERENCES user_fights (id),
    PRIMARY KEY (fight_id, victim_uuid)
);
CREATE TABLE IF NOT EXISTS fight_negated_damage
(
    fight_id    INTEGER,
    victim_uuid UUID,
    amount      DOUBLE PRECISION NOT NULL,
    FOREIGN KEY (fight_id) REFERENCES user_fights (id),
    PRIMARY KEY (fight_id, victim_uuid)
);
CREATE TABLE IF NOT EXISTS fight_instant_health_consumed
(
    user_uuid  UUID,
    fight_uuid UUID,
    faction_id INTEGER,
    amount     DOUBLE PRECISION NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id),
    PRIMARY KEY (user_uuid, fight_uuid, faction_id)
);
CREATE TABLE IF NOT EXISTS fight_gapples_consumed
(
    user_uuid  UUID,
    fight_uuid UUID,
    faction_id INTEGER,
    amount     INTEGER NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id),
    PRIMARY KEY (user_uuid, fight_uuid, faction_id)
);
CREATE TABLE IF NOT EXISTS fight_health_potions_thrown
(
    user_uuid  UUID,
    fight_uuid UUID,
    faction_id INTEGER,
    amount     INTEGER NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id),
    PRIMARY KEY (user_uuid, fight_uuid, faction_id)
);
CREATE TABLE IF NOT EXISTS fight_movement_cooldowns
(
    user_uuid  UUID,
    fight_uuid UUID,
    faction_id INTEGER,
    amount     INTEGER NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id),
    PRIMARY KEY (user_uuid, fight_uuid, faction_id)
);

WITH valid_punishments AS (SELECT id FROM user_punishments WHERE expiration > NOW())
DELETE
FROM user_current_punishments
WHERE punishment_id NOT IN (SELECT id FROM valid_punishments);

WITH valid_deathbans AS (SELECT death_id FROM deathbans WHERE expiration > NOW())
DELETE
FROM current_deathbans
WHERE deathban_id NOT IN (SELECT death_id FROM valid_deathbans);