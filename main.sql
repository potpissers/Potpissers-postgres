--TODO -> users id table (?)

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

CREATE TABLE IF NOT EXISTS servers
(
    id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name      TEXT UNIQUE NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW() -- TODO (?) -> isWhitelisted
);

CREATE TABLE IF NOT EXISTS online_players
(
    user_uuid UUID PRIMARY KEY,
    user_name TEXT    NOT NULL,
    server_id INTEGER NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE
);

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
    id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    party_uuid   UUID    NOT NULL,
    name         TEXT    NOT NULL,
    server_id    INTEGER NOT NULL,
    is_disbanded BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS one_active_faction_per_name ON factions (name, server_id) WHERE is_disbanded = FALSE;
CREATE TABLE IF NOT EXISTS faction_timestamps
(
    faction_id INTEGER,
    timestamp  TIMESTAMPTZ DEFAULT NOW(),
    reason     TEXT,
    user_uuid  UUID,
    FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE,
    PRIMARY KEY (faction_id, timestamp, reason)
);
CREATE OR REPLACE FUNCTION handle_faction_creation(
    party_uuid UUID,
    name TEXT,
    server_id INTEGER,
    chat_message TEXT,
    user_uuid UUID
)
    RETURNS BOOLEAN
AS
$$
DECLARE
    faction_id INTEGER;
BEGIN
    INSERT INTO factions (party_uuid, name, server_id)
    VALUES (handle_faction_creation.party_uuid, handle_faction_creation.name, handle_faction_creation.server_id)
    RETURNING id INTO faction_id;

    INSERT INTO faction_data (faction_id) VALUES (faction_id);

    INSERT INTO faction_timestamps (faction_id, reason, user_uuid)
    VALUES (faction_id, chat_message, handle_faction_creation.user_uuid);

    INSERT INTO current_factions_members (user_uuid, faction_id, rank_id)
    VALUES (handle_faction_creation.user_uuid, faction_id, 3); -- leader rank

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS current_factions_members
(
    user_uuid  UUID PRIMARY KEY,
    faction_id INTEGER NOT NULL,
    rank_id    INTEGER NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id)
);
CREATE UNIQUE INDEX IF NOT EXISTS one_leader_per_faction ON current_factions_members (faction_id) WHERE rank_id = 4; -- party_ranks -> leader

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

WITH valid_punishments AS (SELECT id FROM user_punishments WHERE expiration > NOW()) -- TODO function
DELETE
FROM user_current_punishments
WHERE punishment_id NOT IN (SELECT id FROM valid_punishments);

WITH valid_deathbans AS (SELECT death_id FROM deathbans WHERE expiration > NOW()) -- TODO function
DELETE
FROM current_deathbans
WHERE deathban_id NOT IN (SELECT death_id FROM valid_deathbans);

\i donate.sql
\i other.sql
\i users.sql
