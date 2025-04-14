SET client_min_messages TO WARNING;

-- DO $$
--     DECLARE
--         r RECORD;
--     BEGIN
--         FOR r IN (SELECT routine_schema, routine_name FROM information_schema.routines WHERE routine_type = 'FUNCTION')
--             LOOP
--                 EXECUTE format('DROP FUNCTION IF EXISTS %I.%I CASCADE', r.routine_schema, r.routine_name);
--             END LOOP;
--     END $$; TODO -> delete all functions and re-create them

CREATE TABLE IF NOT EXISTS ip_referrals
(
    java_hmac_ip      BYTEA PRIMARY KEY NOT NULL,
    java_aes_referrer BYTEA
);
CREATE TABLE IF NOT EXISTS user_referrals
(
    user_uuid UUID PRIMARY KEY,
    referrer  TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);
CREATE OR REPLACE FUNCTION get_user_referral_data(user_uuid UUID, ip_bytes BYTEA)
    RETURNS TABLE
            (
                "exists"                BOOLEAN,
                nullable_refferer       TEXT,
                ip_exists               BOOLEAN,
                nullable_refferer_bytes BYTEA
            )
AS
$$
WITH cte AS (SELECT referrer
             FROM user_referrals
             WHERE user_referrals.user_uuid = get_user_referral_data.user_uuid),
     foo AS (SELECT java_aes_referrer
             FROM ip_referrals
             WHERE java_hmac_ip = ip_bytes)
SELECT (SELECT EXISTS(SELECT * FROM cte) AS exists),
       (SELECT referrer FROM cte),
       (SELECT EXISTS(SELECT * FROM foo) AS ip_exists),
       (SELECT java_aes_referrer FROM foo)
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE insert_user_referral(ip_bytes BYTEA, referrer_bytes BYTEA, user_uuid uuid, referrer TEXT)
AS
$$
WITH _
         AS (INSERT INTO ip_referrals (java_hmac_ip, java_aes_referrer) VALUES (ip_bytes, referrer_bytes) ON CONFLICT DO NOTHING)
INSERT
INTO user_referrals (user_uuid, referrer)
VALUES (insert_user_referral.user_uuid, insert_user_referral.referrer)
ON CONFLICT DO NOTHING
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE handle_upsert_user_referral(user_uuid UUID, "timestamp" TIMESTAMPTZ, ip_bytes BYTEA,
                                                        player_name TEXT)
AS
$$
WITH cte AS (INSERT INTO user_referrals (user_uuid, timestamp)
    VALUES (handle_upsert_user_referral.user_uuid, handle_upsert_user_referral.timestamp)
    ON CONFLICT (user_uuid) DO UPDATE SET timestamp = EXCLUDED.timestamp RETURNING *),
     _ AS (INSERT INTO ip_referrals (java_hmac_ip) VALUES (ip_bytes) ON CONFLICT DO NOTHING)
SELECT pg_notify('referrals',
                 (SELECT json_build_object('player_uuid', cte.user_uuid, 'referrer', cte.referrer, 'timestamp',
                                           cte.timestamp, 'row_number',
                                           (SELECT ROW_NUMBER() over (ORDER BY user_referrals.timestamp)
                                            FROM user_referrals
                                            WHERE user_referrals.user_uuid = handle_upsert_user_referral.user_uuid),
                                           'player_name', handle_upsert_user_referral.player_name)::TEXT
                  FROM cte))
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_10_newest_players()
    RETURNS TABLE
            (
                user_uuid   UUID,
                referrer    TEXT,
                "timestamp" TIMESTAMPTZ,
                row_number  INTEGER
            )
AS
$$
SELECT user_uuid, referrer, timestamp, ROW_NUMBER() OVER (ORDER BY timestamp) AS row_number
FROM user_referrals
ORDER BY timestamp
LIMIT 10
$$
    LANGUAGE sql;

DROP TABLE chat_ranks;
CREATE UNLOGGED TABLE chat_ranks
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
CREATE UNLOGGED TABLE line_items
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
        '/revive (username). removes deathban (alts aren''t affected). current revive cost: /lives', true),
       (1, 'hcf', 'basic rank', 800, 'green name, basic server slot, and revive cost + deathban reduced to 80%', false),
       (2, 'hcf', 'gold rank', 1600, 'yellow name, gold server slot, and revive cost + deathban reduced to 60%', false),
       (3, 'hcf', 'diamond rank', 2400, 'aqua name, diamond server slot, and revive cost + deathban reduced to 40%',
        false),
       (4, 'hcf', 'ruby rank', 3200, 'red name, ruby server slot, and revive cost + deathban reduced to 20%', false),
       (5, 'mz', 'life', 400, '/revive (username). removes alt deathban', true),
       (6, 'mz', 'basic rank', 600, 'green name, basic server slot', false),
       (7, 'mz', 'gold rank', 1200, 'yellow name, gold server slot', false),
       (8, 'mz', 'diamond rank', 1800, 'aqua name, diamond server slot', false),
       (9, 'mz', 'ruby rank', 2400, 'red name, ruby server slot', false);
CREATE OR REPLACE FUNCTION get_line_items()
    RETURNS TABLE
            (
                game_mode_name TEXT,
                line_item_name TEXT,
                value_in_cents INTEGER,
                description    TEXT,
                is_plural      BOOLEAN
            )
AS
$$
SELECT game_mode_name, line_item_name, value_in_cents, description, is_plural
FROM line_items
ORDER BY id
$$
    LANGUAGE sql;

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
CREATE OR REPLACE FUNCTION get_donation_rank(user_uuid UUID, game_mode_name TEXT)
    RETURNS TEXT AS
$$
WITH cte AS (SELECT COALESCE(SUM(value_in_cents), 0) AS total_value_in_cents
             FROM successful_transactions
                      JOIN line_items ON successful_transactions.line_item_id = line_items.id
             WHERE successful_transactions.user_uuid = get_donation_rank.user_uuid
               AND chat_rank_id IS NOT NULL
               AND line_items.game_mode_name = get_donation_rank.game_mode_name)

SELECT COALESCE((SELECT name
                 FROM line_items
                          JOIN chat_ranks ON line_items.chat_rank_id = chat_ranks.id
                 WHERE user_uuid = get_donation_rank.user_uuid
                   AND value_in_cents < (SELECT total_value_in_cents FROM cte)
                 ORDER BY value_in_cents DESC
                 LIMIT 1), 'default');
$$
    LANGUAGE sql;
CREATE OR REPLACE PROCEDURE insert_user_free_successful_transaction(user_uuid UUID, game_mode_name TEXT,
                                                                    line_item_name TEXT,
                                                                    user_name TEXT)
AS
$$
WITH cte AS (SELECT id
             FROM line_items
             WHERE line_items.game_mode_name = insert_user_free_successful_transaction.game_mode_name
               AND line_items.line_item_name = insert_user_free_successful_transaction.line_item_name)
INSERT
INTO successful_transactions (user_uuid, line_item_id, line_item_player_name,
                              line_item_quantity, amount_as_cents)
SELECT insert_user_free_successful_transaction.user_uuid,
       id,
       insert_user_free_successful_transaction.user_name,
       1,
       0
FROM cte
WHERE EXISTS(SELECT * FROM cte)
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_unsuccessful_transactions(order_ids TEXT[])
    RETURNS TABLE
            (
                order_id TEXT
            )
AS
$$
SELECT order_id
FROM unnest(order_ids) AS order_id
WHERE order_id NOT IN (SELECT square_order_id
                       FROM successful_transactions)
$$
    LANGUAGE sql;
CREATE OR REPLACE PROCEDURE insert_successful_transaction(order_id TEXT, user_uuid UUID, line_item_name TEXT,
                                                          line_item_player_name TEXT,
                                                          line_item_quantity INTEGER, amount_as_cents INTEGER)
AS
$$
INSERT INTO successful_transactions (square_order_id, user_uuid, line_item_id, line_item_player_name,
                                     line_item_quantity,
                                     amount_as_cents, referrer)
VALUES (order_id, insert_successful_transaction.user_uuid,
        (SELECT id FROM line_items WHERE line_items.line_item_name = insert_successful_transaction.line_item_name),
        insert_successful_transaction.line_item_player_name,
        insert_successful_transaction.line_item_quantity, insert_successful_transaction.amount_as_cents,
        (SELECT referrer FROM user_referrals WHERE user_referrals.user_uuid = insert_successful_transaction.user_uuid))
$$
    LANGUAGE sql;

--TODO -> users id table (?)

DROP TABLE attack_speeds;
CREATE UNLOGGED TABLE attack_speeds
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
CREATE UNLOGGED TABLE party_ranks
(
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);
INSERT INTO party_ranks (id, name)
VALUES (0, 'member'),
       (1, 'officer'),
       (2, 'co-leader'),
       (3, 'leader');

CREATE TABLE IF NOT EXISTS servers -- the current servers table is altered to match this
(
    id             INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    game_mode_name TEXT NOT NULL,
    name           TEXT,
    timestamp      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (game_mode_name, name)
);
CREATE OR REPLACE FUNCTION get_nullable_game_mode_name_current_server_id(game_mode_name TEXT)
    RETURNS INTEGER
AS
$$
SELECT id
FROM servers
         JOIN server_data ON servers.id = server_data.server_id
WHERE servers.game_mode_name = get_nullable_game_mode_name_current_server_id.game_mode_name
  AND NOT is_initially_whitelisted
ORDER BY timestamp DESC
LIMIT 1
$$
    LANGUAGE sql;

CREATE UNLOGGED TABLE IF NOT EXISTS web_chat_history
(
    user_uuid UUID,
    message   TEXT,
    game_mode_name TEXT,
    server_name    TEXT,
    timestamp      TIMESTAMPTZ DEFAULT NOW()
);
CREATE OR REPLACE FUNCTION get_14_newest_network_messages()
    RETURNS SETOF web_chat_history
AS
$$
SELECT *
FROM web_chat_history
ORDER BY timestamp DESC
LIMIT 14
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_14_newest_server_messages(game_mode_name TEXT, server_name TEXT)
    RETURNS SETOF web_chat_history
AS
$$
SELECT *
FROM web_chat_history
WHERE web_chat_history.game_mode_name = get_14_newest_server_messages.game_mode_name
  AND web_chat_history.server_name = get_14_newest_server_messages.server_name
ORDER BY timestamp DESC
LIMIT 14
$$
    LANGUAGE sql;
CREATE OR REPLACE PROCEDURE handle_insert_web_chat_history(user_uuid UUID, message TEXT, game_mode_name TEXT, server_name TEXT)
AS
$$
WITH cte AS (INSERT INTO web_chat_history (user_uuid, message, game_mode_name, server_name)
    VALUES (handle_insert_web_chat_history.user_uuid, handle_insert_web_chat_history.message,
            handle_insert_web_chat_history.game_mode_name, handle_insert_web_chat_history.server_name) RETURNING *)
SELECT pg_notify('chat', (SELECT json_build_object('uuid', cte.user_uuid, 'message', cte.message, 'game_mode_name',
                                                   cte.game_mode_name, 'server_name',
                                                   cte.server_name)::TEXT
                          FROM cte))
$$
    LANGUAGE sql;

CREATE UNLOGGED TABLE IF NOT EXISTS online_players
(
    user_uuid      UUID PRIMARY KEY,
    user_name      TEXT NOT NULL,
    game_mode_name TEXT NOT NULL,
    server_name    TEXT NOT NULL,
    faction_uuid   UUID, -- TODO,
    network_join   TIMESTAMPTZ DEFAULT NOW(),
    server_join    TIMESTAMPTZ DEFAULT NOW()
);
CREATE OR REPLACE FUNCTION get_online_players()
    RETURNS TABLE
            (
                user_uuid      UUID,
                user_name      TEXT,
                game_mode_name TEXT,
                server_name    TEXT,
                faction_uuid   UUID,
                network_join   TIMESTAMPTZ,
                server_join    TIMESTAMPTZ
            )
AS
$$
SELECT user_uuid, user_name, game_mode_name, server_name, faction_uuid, network_join, server_join
FROM online_players
$$
    LANGUAGE sql;
CREATE OR REPLACE PROCEDURE handle_upsert_online_player(user_uuid UUID, user_name TEXT, game_mode_name TEXT,
                                                        server_name TEXT,
                                                        faction_uuid UUID)
AS
$$
WITH cte AS (INSERT
         INTO online_players (user_uuid, user_name, game_mode_name, server_name, faction_uuid)
             VALUES (handle_upsert_online_player.user_uuid, handle_upsert_online_player.user_name,
                     handle_upsert_online_player.game_mode_name, handle_upsert_online_player.server_name,
                     handle_upsert_online_player.faction_uuid)
             ON CONFLICT (user_uuid) DO UPDATE SET user_name = EXCLUDED.user_name,
                 game_mode_name = EXCLUDED.game_mode_name,
                 faction_uuid = EXCLUDED.faction_uuid,
                 server_join = NOW() RETURNING *)
SELECT pg_notify('online', (SELECT json_build_object('uuid', cte.user_uuid,
                                                     'name', cte.user_name, 'game_mode_name',
                                                     cte.game_mode_name,
                                                     'active_faction',
                                                     cte.faction_uuid,
                                                     'network_join',
                                                     cte.network_join,
                                                     'server_join',
                                                     cte.server_join)::TEXT
                            FROM cte))
$$
    LANGUAGE sql;
CREATE OR REPLACE PROCEDURE handle_delete_online_player(user_uuid UUID)
AS
$$
WITH cte AS (DELETE
    FROM online_players
        WHERE online_players.user_uuid = handle_delete_online_player.user_uuid
        RETURNING *)
SELECT pg_notify('offline', (SELECT json_build_object('uuid', cte.user_uuid, 'name',
                                                      user_name, 'game_mode_name',
                                                      game_mode_name,
                                                      'active_faction', faction_uuid,
                                                      'network_join', network_join, 'server_join',
                                                      server_join)::TEXT
                             FROM cte))
$$
    LANGUAGE sql;

CREATE TABLE IF NOT EXISTS server_data
(
    server_id                         INTEGER PRIMARY KEY,
    is_initially_whitelisted          BOOLEAN DEFAULT TRUE,
    attack_speed_id                   INTEGER DEFAULT 2, -- default 7cps
    death_ban_minutes                 INTEGER DEFAULT 0,
    is_ip_deathban_else_full          BOOLEAN DEFAULT TRUE,
    world_border_radius               INTEGER DEFAULT 1250,
    default_kit_name                  TEXT    DEFAULT NULL,
    default_koth_loot_factor          INTEGER DEFAULT 1,
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
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE
);
CREATE OR REPLACE FUNCTION upsert_server_return_data(game_mode_name TEXT, server_name TEXT)
    RETURNS TABLE
            (
                server_id                         INTEGER,
                is_initially_whitelisted          BOOLEAN,
                attack_speed_id                   INTEGER,
                death_ban_minutes                 INTEGER,
                is_ip_deathban_else_full          BOOLEAN,
                world_border_radius               INTEGER,
                default_kit_name                  TEXT,
                default_koth_loot_factor          INTEGER,
                sharpness_limit                   INTEGER,
                power_limit                       INTEGER,
                protection_limit                  INTEGER,
                bard_regen_level                  INTEGER,
                bard_strength_level               INTEGER,
                is_weakness_enabled               BOOLEAN,
                is_bard_passive_debuffing_enabled BOOLEAN,
                dtr_freeze_timer                  INTEGER,
                dtr_max                           REAL,
                dtr_max_time                      INTEGER,
                dtr_off_peak_freeze_time          INTEGER,
                dtr_peak_freeze_time              INTEGER,
                off_peak_lives_needed_as_cents    INTEGER,

                attack_speed_name                 TEXT
            )
AS
$$
WITH cte AS (
    INSERT INTO servers (game_mode_name, name)
        VALUES (upsert_server_return_data.game_mode_name, server_name)
        ON CONFLICT (game_mode_name, name) DO UPDATE SET name = EXCLUDED.name
        RETURNING id)
INSERT
INTO server_data (server_id)
VALUES ((SELECT id FROM cte))
ON CONFLICT (server_id) DO UPDATE SET server_id = EXCLUDED.server_id
RETURNING *,
        (SELECT name FROM attack_speeds WHERE id = attack_speed_id) AS attack_speed_name;
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_server_default_loot_factor(loot_factor INTEGER, server_id INTEGER)
AS
$$
UPDATE server_data
SET default_koth_loot_factor = loot_factor
WHERE server_id = update_server_default_loot_factor.server_id;
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_server_death_ban_minutes(death_ban_minutes INTEGER, server_id INTEGER)
AS
$$
UPDATE server_data
SET death_ban_minutes = update_server_death_ban_minutes.death_ban_minutes
WHERE server_id = update_server_death_ban_minutes.server_id;
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_server_attack_speed(attack_speed_name TEXT, server_id INTEGER)
AS
$$
UPDATE server_data
SET attack_speed_id = (SELECT id FROM attack_speeds WHERE name = attack_speed_name)
WHERE server_id = update_server_attack_speed.server_id
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_server_sharpness_limit(sharpness_limit INTEGER, server_id INTEGER)
AS
$$
UPDATE server_data
SET sharpness_limit = update_server_sharpness_limit.sharpness_limit
WHERE server_id = update_server_sharpness_limit.server_id
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_server_protection_limit(protection_limit INTEGER, server_id INTEGER)
AS
$$
UPDATE server_data
SET protection_limit = update_server_protection_limit.protection_limit
WHERE server_id = update_server_protection_limit.server_id
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_server_power_limit(power_limit INTEGER, server_id INTEGER)
AS
$$
UPDATE server_data
SET power_limit = update_server_power_limit.power_limit
WHERE server_id = update_server_power_limit.server_id
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_server_regen_limit(regen_limit INTEGER, server_id INTEGER)
AS
$$
UPDATE server_data
SET bard_regen_level = update_server_regen_limit.regen_limit
WHERE server_id = update_server_regen_limit.server_id
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_server_strength_limit(strength_limit INTEGER, server_id INTEGER)
AS
$$
UPDATE server_data
SET bard_strength_level = update_server_strength_limit.strength_limit
WHERE server_id = update_server_strength_limit.server_id
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_server_world_border_radius(world_border_radius INTEGER, server_id INTEGER)
AS
$$
UPDATE server_data
SET world_border_radius = update_server_world_border_radius.world_border_radius
WHERE server_data.server_id = update_server_world_border_radius.server_id
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_server_is_initially_whitelisted(server_id INTEGER)
    RETURNS BOOLEAN
AS
$$
SELECT is_initially_whitelisted
FROM server_data
WHERE server_data.server_id = get_server_is_initially_whitelisted.server_id
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_server_max_dtr(server_id INTEGER)
    RETURNS REAL
AS
$$
SELECT dtr_max
FROM server_data
WHERE server_data.server_id = get_server_max_dtr.server_id
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_server_datas()
    RETURNS TABLE
            (
                death_ban_minutes                 INTEGER,
                world_border_radius               INTEGER,
                default_koth_loot_factor          INTEGER,
                sharpness_limit                   INTEGER,
                power_limit                       INTEGER,
                protection_limit                  INTEGER,
                bard_regen_level                  INTEGER,
                bard_strength_level               INTEGER,
                is_weakness_enabled               BOOLEAN,
                is_bard_passive_debuffing_enabled BOOLEAN,
                dtr_freeze_timer                  INTEGER,
                dtr_max                           REAL,
                off_peak_lives_needed REAL,
                "timestamp"                       TIMESTAMPTZ,
                server_name                       TEXT,
                game_mode_name                    TEXT,
                attack_speed_name                 TEXT,
                is_initially_whitelisted          BOOLEAN
            )
AS
$$
SELECT death_ban_minutes,
       world_border_radius,
       default_koth_loot_factor,
       sharpness_limit,
       power_limit,
       protection_limit,
       bard_regen_level,
       bard_strength_level,
       is_weakness_enabled,
       is_bard_passive_debuffing_enabled,
       dtr_freeze_timer,
       dtr_max,
       off_peak_lives_needed_as_cents::REAL / 100,
       timestamp,
       servers.name,
       game_mode_name,
       attack_speeds.name,
       server_data.is_initially_whitelisted
FROM server_data
         JOIN servers ON id = server_id
         JOIN attack_speeds ON attack_speed_id = attack_speeds.id
$$
    LANGUAGE sql;

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
CREATE OR REPLACE PROCEDURE insert_loot_table_entry(loot_table_id INTEGER, entry_name TEXT, entry_chance DOUBLE PRECISION)
AS
$$
INSERT
INTO loot_table_entries (loot_table_id, entry_name, entry_chance)
VALUES (insert_loot_table_entry.loot_table_id, insert_loot_table_entry.entry_name, insert_loot_table_entry.entry_chance)
ON CONFLICT (loot_table_id, entry_name, entry_chance) DO NOTHING
$$ LANGUAGE sql;

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
CREATE OR REPLACE FUNCTION get_server_loot_chests(server_id INTEGER)
    RETURNS TABLE
            (
                world_name      TEXT,
                x               INTEGER,
                y               INTEGER,
                z               INTEGER,
                loot_table_name TEXT,
                min_amount      INTEGER,
                loot_variance   INTEGER,
                restock_time    INTEGER,
                direction       TEXT,
                block_type      TEXT
            )
AS
$$
SELECT world_name,
       x,
       y,
       z,
       loot_table_name,
       min_amount,
       loot_variance,
       restock_time,
       direction,
       block_type
FROM server_loot_chests
         JOIN loot_tables ON server_loot_chests.loot_table_id = loot_tables.id
WHERE server_loot_chests.server_id = get_server_loot_chests.server_id;
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE delete_server_loot_chest(server_id INTEGER, world_name TEXT, x INTEGER, y INTEGER, z INTEGER
)
AS
$$
DELETE
FROM server_loot_chests
WHERE server_loot_chests.server_id = delete_server_loot_chest.server_id
  AND server_loot_chests.world_name = delete_server_loot_chest.world_name
  AND server_loot_chests.x = delete_server_loot_chest.x
  AND server_loot_chests.y = delete_server_loot_chest.y
  AND server_loot_chests.z = delete_server_loot_chest.z
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE upsert_loot_table_chest(
    server_id INTEGER,
    loot_table_name TEXT,
    world_name TEXT,
    x INTEGER,
    y INTEGER,
    z INTEGER,
    min_amount INTEGER,
    loot_variance INTEGER,
    restock_time INTEGER,
    direction TEXT,
    block_type TEXT
)
AS
$$
WITH cte
         AS (INSERT INTO loot_tables (server_id, loot_table_name) VALUES (upsert_loot_table_chest.server_id,
                                                                          upsert_loot_table_chest.loot_table_name) ON CONFLICT (server_id, loot_table_name) DO UPDATE SET loot_table_name = EXCLUDED.loot_table_name RETURNING id)
INSERT
INTO server_loot_chests (server_id, world_name, x, y, z, loot_table_id, min_amount, loot_variance, restock_time,
                         direction, block_type)
VALUES (upsert_loot_table_chest.server_id, upsert_loot_table_chest.world_name, upsert_loot_table_chest.x,
        upsert_loot_table_chest.y, upsert_loot_table_chest.z, (SELECT id FROM cte), upsert_loot_table_chest.min_amount,
        upsert_loot_table_chest.loot_variance,
        upsert_loot_table_chest.restock_time, upsert_loot_table_chest.direction, upsert_loot_table_chest.block_type)
ON CONFLICT (server_id, world_name, x, y, z) DO UPDATE SET loot_table_id = EXCLUDED.loot_table_id,
                                                           min_amount    = EXCLUDED.min_amount,
                                                           loot_variance = EXCLUDED.loot_variance,
                                                           restock_time  = EXCLUDED.restock_time,
                                                           direction     = EXCLUDED.restock_time,
                                                           block_type    = EXCLUDED.block_type
$$ LANGUAGE sql;

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
CREATE OR REPLACE FUNCTION get_user_is_ip_exempt(user_uuid UUID, server_id INTEGER)
    RETURNS BOOLEAN AS
$$
SELECT EXISTS(SELECT 1
              FROM ip_exempt_uuids
              WHERE ip_exempt_uuids.user_uuid = get_user_is_ip_exempt.user_uuid
                AND ip_exempt_uuids.server_id = get_user_is_ip_exempt.server_id)
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION toggle_is_user_ip_exempt_returning_star(user_uuid UUID, server_id INTEGER)
    RETURNS SETOF ip_exempt_uuids AS
$$
WITH cte
         AS (INSERT INTO ip_exempt_uuids (user_uuid, server_id) VALUES (toggle_is_user_ip_exempt_returning_star.user_uuid,
                                                                        toggle_is_user_ip_exempt_returning_star.server_id) ON CONFLICT (user_uuid, server_id) DO NOTHING RETURNING *)
DELETE
FROM ip_exempt_uuids
WHERE ip_exempt_uuids.user_uuid = toggle_is_user_ip_exempt_returning_star.user_uuid
  AND ip_exempt_uuids.server_id = toggle_is_user_ip_exempt_returning_star.server_id
  AND NOT EXISTS(SELECT * FROM cte)
RETURNING *
$$ LANGUAGE sql;

CREATE TABLE IF NOT EXISTS kits
(
    id                     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kit_name               TEXT UNIQUE NOT NULL,
    bukkit_default_loadout BYTEA       NOT NULL
);
CREATE OR REPLACE FUNCTION get_kit_names()
    RETURNS TEXT[] AS
$$
SELECT ARRAY(
               SELECT kit_name
               FROM kits);
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE upsert_default_kit(kit_name TEXT, bukkit_default_loadout BYTEA)
AS
$$
INSERT INTO kits (kit_name, bukkit_default_loadout)
VALUES (upsert_default_kit.kit_name, upsert_default_kit.bukkit_default_loadout)
ON CONFLICT (kit_name) DO UPDATE SET bukkit_default_loadout = EXCLUDED.bukkit_default_loadout
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION delete_default_kit_return_remaining_names(kit_name TEXT)
    RETURNS TEXT[]
AS
$$
WITH cte AS (
    DELETE
        FROM kits -- TODO -> handle cascade
            WHERE kits.kit_name = delete_default_kit_return_remaining_names.kit_name)
SELECT array_agg(kits.kit_name)
FROM kits
$$
    LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_default_kit_name(kit_name TEXT, server_id INTEGER)
AS
$$
UPDATE server_data
SET default_kit_name = kit_name
WHERE server_data.server_id = update_default_kit_name.server_id
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_kit_bukkit_default_contents(kit_name TEXT)
    RETURNS BYTEA AS
$$
SELECT bukkit_default_loadout
FROM kits
WHERE kits.kit_name = get_kit_bukkit_default_contents.kit_name
$$ LANGUAGE sql;

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
CREATE OR REPLACE FUNCTION get_server_consumable_kit_names(server_id INTEGER)
    RETURNS TEXT[] AS
$$
SELECT ARRAY(SELECT kit_name
             FROM server_consumable_kits
             WHERE server_consumable_kits.server_id = get_server_consumable_kit_names.server_id)
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE upsert_server_consumable_kit(server_id INTEGER, kit_name TEXT, bukkit_kit_contents BYTEA,
                                                         cooldown INTEGER)
AS
$$
INSERT INTO server_consumable_kits (server_id, kit_name, bukkit_kit_contents, cooldown)
VALUES (upsert_server_consumable_kit.server_id, upsert_server_consumable_kit.kit_name,
        upsert_server_consumable_kit.bukkit_kit_contents, upsert_server_consumable_kit.cooldown)
ON CONFLICT (server_id, kit_name) DO UPDATE SET bukkit_kit_contents = EXCLUDED.bukkit_kit_contents,
                                                cooldown            = EXCLUDED.cooldown
$$ LANGUAGE sql;

CREATE TABLE IF NOT EXISTS user_consumable_kits_history
(
    user_uuid UUID,
    kit_id    INTEGER,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_uuid, kit_id, timestamp)
);
CREATE OR REPLACE FUNCTION get_nullable_newest_server_consumable_kits_data_timestamp(user_uuid UUID, server_id INTEGER, kit_name TEXT)
    RETURNS TABLE
            (
                id                  INTEGER,
                bukkit_kit_contents BYTEA,
                cooldown            INTEGER,
                "timestamp"         TIMESTAMPTZ
            )
AS
$$
SELECT id, bukkit_kit_contents, cooldown, timestamp
FROM user_consumable_kits_history
         JOIN server_consumable_kits
              ON server_consumable_kits.id = user_consumable_kits_history.kit_id
WHERE user_consumable_kits_history.user_uuid = get_nullable_newest_server_consumable_kits_data_timestamp.user_uuid
  AND server_consumable_kits.server_id = get_nullable_newest_server_consumable_kits_data_timestamp.server_id
  AND server_consumable_kits.kit_name = get_nullable_newest_server_consumable_kits_data_timestamp.kit_name
ORDER BY timestamp DESC
LIMIT 1
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE insert_user_consumable_kit_history_entry(user_uuid UUID, kit_id INTEGER)
AS
$$
INSERT INTO user_consumable_kits_history (user_uuid, kit_id)
VALUES (insert_user_consumable_kit_history_entry.user_uuid, insert_user_consumable_kit_history_entry.kit_id)
$$ LANGUAGE sql;

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
CREATE OR REPLACE FUNCTION get_user_staff_rank_name(user_uuid UUID, server_id INTEGER)
    RETURNS TEXT AS
$$
SELECT name
FROM user_staff_ranks
         JOIN chat_ranks ON user_staff_ranks.chat_rank_id = chat_ranks.id
WHERE user_staff_ranks.user_uuid = get_user_staff_rank_name.user_uuid
  AND user_staff_ranks.server_id = get_user_staff_rank_name.server_id
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE upsert_user_staff_rank(user_uuid UUID, server_id INTEGER, staff_rank_name TEXT)
AS
$$
INSERT
INTO user_staff_ranks (user_uuid, server_id, chat_rank_id)
VALUES (upsert_user_staff_rank.user_uuid, upsert_user_staff_rank.server_id,
        (SELECT id FROM chat_ranks WHERE name = staff_rank_name))
ON CONFLICT (user_uuid, server_id) DO UPDATE SET chat_rank_id = EXCLUDED.chat_rank_id
$$ LANGUAGE sql;

DROP TABLE punishment_types;
CREATE UNLOGGED TABLE IF NOT EXISTS punishment_types
(
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);
INSERT INTO punishment_types (id, name)
VALUES (0, 'ban'),
       (1, 'mute'),
       (2, '7cps');
CREATE TABLE IF NOT EXISTS user_punishments
(
    id                 INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_uuid          UUID        NOT NULL,
    server_id          INTEGER     NOT NULL,
    punishment_type_id INTEGER     NOT NULL,
    timestamp          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reason             TEXT        NOT NULL,
    expiration         TIMESTAMPTZ NOT NULL,
    FOREIGN KEY (server_id) REFERENCES servers (id) ON DELETE CASCADE
);
CREATE OR REPLACE FUNCTION get_farthest_user_punishment(punishment_type_name TEXT, user_uuid UUID, server_id INTEGER)
    RETURNS TABLE
            (
                expiration TIMESTAMPTZ,
                reason     TEXT
            )
AS
$$
SELECT expiration, reason
FROM user_punishments
         JOIN punishment_types ON user_punishments.punishment_type_id = punishment_types.id
WHERE name = punishment_type_name
  AND user_punishments.user_uuid = get_farthest_user_punishment.user_uuid
  AND user_punishments.server_id = get_farthest_user_punishment.server_id
  AND expiration > NOW()
ORDER BY expiration DESC
LIMIT 1
$$ LANGUAGE sql;
CREATE TABLE IF NOT EXISTS user_current_punishments
(
    punishment_id INTEGER PRIMARY KEY,
    java_hmac_ip  BYTEA,
    FOREIGN KEY (punishment_id) REFERENCES user_punishments (id)
);
CREATE OR REPLACE PROCEDURE insert_user_punishment(user_uuid UUID, server_id INTEGER, punishment_type_name TEXT,
                                                   reason TEXT, expiration TIMESTAMPTZ, ip_bytes BYTEA)
AS
$$
WITH cte AS
         (INSERT INTO user_punishments (user_uuid, server_id, punishment_type_id, reason, expiration) VALUES (insert_user_punishment.user_uuid,
                                                                                                              insert_user_punishment.server_id,
                                                                                                              (SELECT id FROM punishment_types WHERE name = punishment_type_name),
                                                                                                              insert_user_punishment.reason,
                                                                                                              insert_user_punishment.expiration) RETURNING id)
INSERT
INTO user_current_punishments (punishment_id, java_hmac_ip)
VALUES ((SELECT id FROM cte), insert_user_punishment.ip_bytes)
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_farthest_user_ip_punishment(user_uuid UUID, ip_bytes BYTEA, server_id INTEGER,
                                                           punishment_type_name TEXT)
    RETURNS TABLE
            (
                expiration TIMESTAMPTZ,
                reason     TEXT
            )
AS
$$
SELECT expiration, reason
FROM user_punishments
         JOIN user_current_punishments ON user_punishments.id = user_current_punishments.punishment_id
         JOIN punishment_types ON user_punishments.punishment_type_id = punishment_types.id
WHERE user_punishments.user_uuid != get_farthest_user_ip_punishment.user_uuid
  AND user_current_punishments.java_hmac_ip = get_farthest_user_ip_punishment.ip_bytes
  AND user_punishments.server_id = get_farthest_user_ip_punishment.server_id
  AND name = get_farthest_user_ip_punishment.punishment_type_name
  AND (NOT EXISTS(SELECT *
                  FROM ip_exempt_uuids
                  WHERE ip_exempt_uuids.user_uuid = get_farthest_user_ip_punishment.user_uuid
                    AND ip_exempt_uuids.server_id = get_farthest_user_ip_punishment.server_id))
ORDER BY expiration DESC
LIMIT 1
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION reduce_user_punishments_by_type_returning_star(user_uuid UUID, server_id INTEGER, punishment_name TEXT)
    RETURNS SETOF user_punishments
AS
$$
UPDATE user_punishments
SET expiration = NOW()
WHERE user_punishments.user_uuid = reduce_user_punishments_by_type_returning_star.user_uuid
  AND user_punishments.server_id = reduce_user_punishments_by_type_returning_star.server_id
  AND punishment_type_id = (SELECT id FROM punishment_types WHERE name = punishment_name)
RETURNING *
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION reduce_user_punishments_by_type_by_length_returning_star(user_uuid UUID, server_id INTEGER,
                                                                                    punishment_name TEXT,
                                                                                    length_minutes INTEGER)
    RETURNS SETOF user_punishments
AS
$$
UPDATE user_punishments
SET expiration = NOW()
WHERE user_punishments.user_uuid = reduce_user_punishments_by_type_by_length_returning_star.user_uuid
  AND user_punishments.server_id = reduce_user_punishments_by_type_by_length_returning_star.server_id
  AND punishment_type_id = (SELECT id FROM punishment_types WHERE name = punishment_name)
  AND expiration BETWEEN NOW() AND NOW() + length_minutes * INTERVAL '1 minute'
RETURNING *
$$ LANGUAGE sql;

CREATE TABLE IF NOT EXISTS party_invites
(
    user_uuid    UUID,
    party_uuid   UUID,
    inviter_uuid UUID    NOT NULL,
    rank_id      INTEGER NOT NULL,
    timestamp    TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_uuid, party_uuid)
);
CREATE OR REPLACE PROCEDURE delete_party_invite(user_uuid UUID, party_uuid UUID)
AS
$$
DELETE
FROM party_invites
WHERE party_invites.user_uuid = delete_party_invite.user_uuid
  AND party_invites.party_uuid = delete_party_invite.party_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_user_party_invite_rank_name(user_uuid UUID, party_uuid UUID)
    RETURNS TEXT AS
$$
SELECT name
FROM party_invites
         JOIN party_ranks ON party_invites.rank_id = party_ranks.id
WHERE party_invites.user_uuid = get_user_party_invite_rank_name.user_uuid
  AND party_invites.party_uuid = get_user_party_invite_rank_name.party_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE upsert_party_invite(user_uuid UUID, party_uuid UUID, inviter_uuid UUID, rank_name TEXT)
AS
$$
INSERT
INTO party_invites (user_uuid, party_uuid, inviter_uuid, rank_id)
VALUES (upsert_party_invite.user_uuid, upsert_party_invite.party_uuid, upsert_party_invite.inviter_uuid,
        (SELECT id FROM party_ranks WHERE name = rank_name))
ON CONFLICT (user_uuid, party_uuid) DO UPDATE SET rank_id      = EXCLUDED.rank_id,
                                                  inviter_uuid = EXCLUDED.inviter_uuid,
                                                  timestamp    = NOW()
    -- TODO -> make this return uuid if existed like ally etc
$$ LANGUAGE sql;

CREATE TABLE IF NOT EXISTS ally_invites
(
    inviter_party_uuid UUID,
    invited_party_uuid UUID,
    inviter_user_uuid  UUID,
    timestamp          TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (inviter_party_uuid, invited_party_uuid)
);
CREATE OR REPLACE FUNCTION get_is_ally_invited(inviter_party_uuid UUID, invited_party_uuid UUID)
    RETURNS BOOLEAN AS
$$
SELECT EXISTS(SELECT *
              FROM ally_invites
              WHERE ally_invites.inviter_party_uuid = get_is_ally_invited.inviter_party_uuid
                AND ally_invites.invited_party_uuid = get_is_ally_invited.invited_party_uuid)
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION upsert_ally_invite_return_existed(inviter_party_uuid UUID, invited_party_uuid UUID,
                                                             inviter_user_uuid UUID)
    RETURNS BOOLEAN AS
$$
INSERT INTO ally_invites (inviter_party_uuid, invited_party_uuid, inviter_user_uuid)
VALUES (upsert_ally_invite_return_existed.inviter_party_uuid, upsert_ally_invite_return_existed.invited_party_uuid,
        upsert_ally_invite_return_existed.inviter_user_uuid)
ON CONFLICT (inviter_party_uuid, invited_party_uuid) DO UPDATE SET inviter_user_uuid = EXCLUDED.inviter_user_uuid,
                                                                   timestamp         = NOW()
RETURNING xmax <> 0 -- TODO -> make this return the uuid if it already existed
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE delete_ally_invite(party_uuid UUID, party_arg_uuid UUID)
AS
$$
DELETE
FROM ally_invites
WHERE inviter_party_uuid = party_uuid
  AND invited_party_uuid = party_arg_uuid
$$ LANGUAGE sql;

CREATE TABLE IF NOT EXISTS current_parties_relations
(
    party_uuid         UUID,
    party_arg_uuid     UUID,
    is_ally_else_enemy BOOLEAN NOT NULL,
    PRIMARY KEY (party_uuid, party_arg_uuid)
);
CREATE OR REPLACE FUNCTION get_party_relations(party_uuid UUID)
    RETURNS TABLE
            (
                party_arg_uuid     UUID,
                is_ally_else_enemy BOOLEAN
            )
AS
$$
SELECT party_arg_uuid, is_ally_else_enemy
FROM current_parties_relations
WHERE current_parties_relations.party_uuid = get_party_relations.party_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE delete_party_relation(party_uuid UUID, party_arg_uuid UUID)
AS
$$
DELETE
FROM current_parties_relations
WHERE current_parties_relations.party_uuid = delete_party_relation.party_uuid
  AND current_parties_relations.party_arg_uuid = delete_party_relation.party_arg_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_party_relation_is_ally_else_enemy(party_uuid UUID, party_arg_uuid UUID)
    RETURNS BOOLEAN AS
$$
SELECT is_ally_else_enemy
FROM current_parties_relations
WHERE current_parties_relations.party_uuid = get_party_relation_is_ally_else_enemy.party_uuid
  AND current_parties_relations.party_arg_uuid = get_party_relation_is_ally_else_enemy.party_arg_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE insert_party_relation(party_uuid UUID, party_arg_uuid UUID, is_ally_else_enemy BOOLEAN)
AS
$$
INSERT INTO current_parties_relations (party_uuid, party_arg_uuid, is_ally_else_enemy)
VALUES (insert_party_relation.party_uuid, insert_party_relation.party_arg_uuid,
        insert_party_relation.is_ally_else_enemy)
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_party_relations(party_uuid UUID)
    RETURNS TABLE
            (
                party_arg_uuid     UUID,
                is_ally_else_enemy BOOLEAN
            )
AS
$$
SELECT party_arg_uuid, is_ally_else_enemy
FROM current_parties_relations
WHERE current_parties_relations.party_uuid = get_party_relations.party_uuid
$$ LANGUAGE sql;

CREATE TABLE IF NOT EXISTS current_parties_members
(
    user_uuid  UUID PRIMARY KEY,
    party_uuid UUID    NOT NULL,
    rank_id    INTEGER NOT NULL
);
DROP INDEX IF EXISTS one_leader_per_party;
CREATE UNIQUE INDEX IF NOT EXISTS one_leader_per_party ON current_parties_members (party_uuid) WHERE rank_id = 3;
-- party_ranks -> leader
CREATE OR REPLACE FUNCTION get_party_leader_uuid(party_uuid UUID)
    RETURNS UUID
AS
$$
SELECT user_uuid
FROM current_parties_members
         JOIN party_ranks on current_parties_members.rank_id = party_ranks.id
WHERE current_parties_members.party_uuid = get_party_leader_uuid.party_uuid
  AND name = 'leader'
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE handle_network_party_delete(party_uuid UUID)
AS
$$
WITH _ AS (DELETE FROM current_parties_relations WHERE party_arg_uuid = handle_network_party_delete.party_uuid OR
                                                       current_parties_relations.party_uuid =
                                                       handle_network_party_delete.party_uuid)
DELETE
FROM current_parties_members
WHERE current_parties_members.party_uuid = handle_network_party_delete.party_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_user_network_party_rank_name(user_uuid UUID)
    RETURNS TEXT AS
$$
SELECT name
FROM current_parties_members
         JOIN party_ranks ON current_parties_members.rank_id = party_ranks.id
WHERE current_parties_members.user_uuid = get_user_network_party_rank_name.user_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_user_is_in_party(user_uuid UUID, party_uuid UUID)
    RETURNS BOOLEAN AS
$$
SELECT EXISTS(SELECT *
              FROM current_parties_members
              WHERE current_parties_members.user_uuid = get_user_is_in_party.user_uuid
                AND current_parties_members.party_uuid = get_user_is_in_party.party_uuid)
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE delete_user_party(user_uuid UUID, party_uuid UUID)
AS
$$
DELETE
FROM current_parties_members
WHERE current_parties_members.user_uuid = delete_user_party.user_uuid
  AND current_parties_members.party_uuid = delete_user_party.party_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_user_party_uuid(user_uuid UUID)
    RETURNS UUID AS
$$
SELECT party_uuid
FROM current_parties_members
WHERE current_parties_members.user_uuid = get_user_party_uuid.user_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_party_members(party_uuid UUID)
    RETURNS TABLE
            (
                user_uuid UUID,
                name      TEXT
            )
AS
$$
SELECT user_uuid, name
FROM current_parties_members
         JOIN party_ranks ON id = rank_id
WHERE current_parties_members.party_uuid = get_party_members.party_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE insert_current_parties_members_user(user_uuid UUID, party_uuid UUID, party_rank_name TEXT)
AS
$$
INSERT INTO current_parties_members (user_uuid, party_uuid, rank_id)
VALUES (insert_current_parties_members_user.user_uuid, insert_current_parties_members_user.party_uuid,
        (SELECT id FROM party_ranks WHERE name = party_rank_name))
ON CONFLICT (user_uuid) DO UPDATE SET rank_id = EXCLUDED.rank_id
WHERE current_parties_members.party_uuid = EXCLUDED.party_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE handle_insert_party_member(user_uuid UUID, party_uuid UUID, rank_name TEXT)
AS
$$
WITH _ AS (DELETE FROM party_invites WHERE party_invites.user_uuid = handle_insert_party_member.user_uuid AND
                                           party_invites.party_uuid = handle_insert_party_member.party_uuid)
INSERT
INTO current_parties_members (user_uuid, party_uuid, rank_id)
VALUES (handle_insert_party_member.user_uuid, handle_insert_party_member.party_uuid,
        (SELECT id FROM party_ranks WHERE name = rank_name))
ON CONFLICT (user_uuid) DO UPDATE SET rank_id = CASE
                                                    WHEN current_parties_members.party_uuid = EXCLUDED.party_uuid
                                                        THEN EXCLUDED.rank_id
                                                    ELSE current_parties_members.rank_id END
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE handle_update_party_leader(party_uuid UUID, user_uuid UUID)
AS
$$
WITH _
         AS (UPDATE current_parties_members SET rank_id = (SELECT id FROM party_ranks WHERE name = 'co-leader') WHERE
        rank_id = (SELECT id FROM party_ranks WHERE name = 'leader') AND
        party_uuid = handle_update_party_leader.party_uuid)
UPDATE current_parties_members
SET rank_id = (SELECT id FROM party_ranks WHERE name = 'leader')
WHERE user_uuid = handle_update_party_leader.user_uuid
  AND party_uuid = handle_update_party_leader.party_uuid
$$ LANGUAGE sql;

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
CREATE OR REPLACE FUNCTION get_faction_name(party_uuid UUID, server_id INTEGER)
    RETURNS TEXT AS
$$
SELECT name
FROM factions
WHERE factions.party_uuid = get_faction_name.party_uuid
  AND factions.server_id = get_faction_name.server_id
$$ LANGUAGE sql;
CREATE TABLE IF NOT EXISTS faction_timestamps
(
    faction_id INTEGER,
    timestamp  TIMESTAMPTZ DEFAULT NOW(),
    reason     TEXT,
    user_uuid  UUID,
    FOREIGN KEY (faction_id) REFERENCES factions (id) ON DELETE CASCADE,
    PRIMARY KEY (faction_id, timestamp, reason)
);
CREATE OR REPLACE FUNCTION handle_faction_creation(party_uuid UUID, name TEXT, server_id INTEGER, chat_message TEXT,
                                                   user_uuid UUID)
    RETURNS BOOLEAN AS
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
CREATE OR REPLACE FUNCTION get_user_faction_uuid(user_uuid UUID, server_id INTEGER)
    RETURNS UUID
AS
$$
SELECT party_uuid
FROM current_factions_members
         JOIN factions ON current_factions_members.faction_id = factions.id
WHERE current_factions_members.user_uuid = get_user_faction_uuid.user_uuid
  AND factions.server_id = get_user_faction_uuid.server_id
$$ LANGUAGE sql;

CREATE TABLE IF NOT EXISTS current_factions_members
(
    user_uuid  UUID PRIMARY KEY,
    faction_id INTEGER NOT NULL,
    rank_id    INTEGER NOT NULL,
    FOREIGN KEY (faction_id) REFERENCES factions (id)
);
CREATE UNIQUE INDEX IF NOT EXISTS one_leader_per_faction ON current_factions_members (faction_id) WHERE rank_id = 4;
-- party_ranks -> leader
CREATE OR REPLACE FUNCTION get_faction_members(party_uuid UUID)
    RETURNS TABLE
            (
                user_uuid UUID,
                name      TEXT
            )
AS
$$
SELECT user_uuid, party_ranks.name
FROM current_factions_members
         JOIN factions ON factions.id = current_factions_members.faction_id
         JOIN party_ranks ON party_ranks.id = current_factions_members.rank_id
WHERE factions.party_uuid = get_faction_members.party_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_user_faction_rank_name(user_uuid UUID, faction_uuid UUID)
    RETURNS TEXT
AS
$$
SELECT party_ranks.name
FROM current_factions_members
         JOIN factions ON current_factions_members.faction_id = factions.id
         JOIN party_ranks ON current_factions_members.rank_id = party_ranks.id
WHERE current_factions_members.user_uuid = get_user_faction_rank_name.user_uuid
  AND party_uuid = faction_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE delete_user_current_faction(user_uuid UUID, faction_uuid UUID)
AS
$$
WITH cte as (DELETE FROM faction_current_dtr_regen_players WHERE
    faction_current_dtr_regen_players.user_uuid = delete_user_current_faction.user_uuid AND
    faction_id =
    (SELECT id FROM factions WHERE party_uuid = faction_uuid) RETURNING faction_id)
DELETE
FROM current_factions_members
WHERE current_factions_members.user_uuid = delete_user_current_faction.user_uuid
  AND faction_id = (SELECT faction_id FROM cte)
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE upsert_user_current_faction(user_uuid UUID, faction_uuid UUID, rank_name TEXT)
AS
$$
WITH cte AS (DELETE FROM party_invites WHERE party_invites.user_uuid = upsert_user_current_faction.user_uuid AND
                                             party_uuid = faction_uuid)
INSERT
INTO current_factions_members (user_uuid, faction_id, rank_id)
VALUES (upsert_user_current_faction.user_uuid, (SELECT id FROM factions WHERE party_uuid = faction_uuid),
        (SELECT id FROM party_ranks WHERE name = rank_name))
ON CONFLICT (user_uuid) DO UPDATE SET rank_id = EXCLUDED.rank_id
WHERE current_factions_members.faction_id = EXCLUDED.faction_id
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_user_is_in_faction(user_uuid UUID, faction_uuid UUID)
    RETURNS BOOLEAN AS
$$
SELECT EXISTS(SELECT *
              FROM current_factions_members
                       JOIN factions ON current_factions_members.faction_id = factions.id
              WHERE current_factions_members.user_uuid = get_user_is_in_faction.user_uuid
                AND party_uuid = faction_uuid)
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE handle_faction_disband(faction_uuid UUID)
AS
$$
WITH cte AS (UPDATE factions SET is_disbanded = true WHERE party_uuid = faction_uuid RETURNING id),
     _ AS (DELETE FROM faction_current_dtr_regen_players WHERE faction_id = (SELECT id FROM cte)),
     _1 AS (DELETE FROM current_parties_relations WHERE party_uuid = faction_uuid OR party_arg_uuid = faction_uuid)
DELETE
FROM current_factions_members
WHERE faction_id = (SELECT id FROM cte)
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_current_faction_leader(faction_uuid UUID, leader_uuid UUID)
AS
$$
WITH cte
         AS (UPDATE current_factions_members SET rank_id = (SELECT id FROM party_ranks WHERE name = 'co-leader') WHERE
        rank_id = (SELECT id FROM party_ranks WHERE name = 'leader') AND
        faction_id = (SELECT id FROM factions WHERE party_uuid = faction_uuid) RETURNING faction_id)
UPDATE current_factions_members
SET rank_id = (SELECT id FROM party_ranks WHERE name = 'leader')
WHERE user_uuid = leader_uuid
  AND faction_id = (SELECT faction_id FROM cte)
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_faction_max_dtr(server_id INTEGER, faction_uuid UUID)
    RETURNS REAL
AS
$$
SELECT LEAST(COUNT(user_uuid) + 0.01,
             (SELECT dtr_max FROM server_data WHERE server_data.server_id = get_faction_max_dtr.server_id))
FROM current_factions_members
         JOIN factions ON current_factions_members.faction_id = factions.id
WHERE party_uuid = faction_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_7_factions(game_mode_name TEXT, server_name TEXT)
    RETURNS TABLE
            (
                name                       TEXT,
                party_uuid                 UUID,
                frozen_until               TIMESTAMPTZ,
                current_max_dtr            REAL,
                current_regen_adjusted_dtr REAL
            )
AS
$$
SELECT factions.name, party_uuid, frozen_until, current_max_dtr, current_regen_adjusted_dtr
FROM factions
         JOIN servers ON factions.server_id = servers.id
         JOIN LATERAL get_dtr_data(servers.id, party_uuid) ON TRUE
WHERE servers.game_mode_name = get_7_factions.game_mode_name
  AND servers.name = server_name
  AND is_disbanded = false
LIMIT 7
$$
    LANGUAGE sql;

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
CREATE OR REPLACE FUNCTION get_faction_data(party_uuid UUID)
    RETURNS TABLE
            (
                balance         INTEGER,
                home_world_name TEXT,
                home_x          INTEGER,
                home_y          INTEGER,
                home_z          INTEGER
            )
AS
$$
SELECT balance, home_world_name, home_x, home_y, home_z
FROM faction_data
         JOIN factions ON factions.id = faction_data.faction_id
WHERE factions.party_uuid = get_faction_data.party_uuid
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION handle_dtr_death_return_result(faction_uuid UUID, server_id INTEGER,
                                                          new_dtr_regen_players UUID[], dtr_amount REAL)
    RETURNS TABLE
            (
                current_minimum_dtr REAL,
                frozen_until        TIMESTAMPTZ,
                dtr_freeze_timer    INTEGER
            )
AS
$$
DECLARE
    fac_id           INTEGER;
    dtr_freeze_timer INTEGER;
BEGIN
    SELECT id FROM factions WHERE party_uuid = faction_uuid INTO fac_id;

    DELETE
    FROM faction_current_dtr_regen_players
    WHERE faction_current_dtr_regen_players.faction_id = fac_id;

    SELECT server_data.dtr_freeze_timer
    INTO dtr_freeze_timer
    FROM server_data
    WHERE server_data.server_id = handle_dtr_death_return_result.server_id;

    INSERT
    INTO faction_current_dtr_regen_players (faction_id, user_uuid)
    VALUES (fac_id, UNNEST(new_dtr_regen_players));

    RETURN QUERY UPDATE faction_data
        SET current_minimum_dtr = GREATEST(get_dtr(server_id, faction_uuid) - dtr_amount,
                                           -get_faction_max_dtr(handle_dtr_death_return_result.server_id,
                                                                faction_uuid)), -- TODO -> this is so wasteful
            frozen_until = NOW() + dtr_freeze_timer * INTERVAL '1 second'
        WHERE faction_data.faction_id = fac_id
        RETURNING faction_data.current_minimum_dtr, faction_data.frozen_until, dtr_freeze_timer;
END;
$$
    LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION get_dtr_data(server_id INTEGER, party_uuid UUID)
    RETURNS TABLE
            (
                frozen_until               TIMESTAMPTZ,
                current_max_dtr            REAL,
                current_regen_adjusted_dtr REAL
            )
AS
$$
WITH cte AS (SELECT GREATEST(LEAST(EXTRACT(EPOCH FROM (NOW() - frozen_until)) /
                                   (SELECT dtr_max_time
                                    FROM server_data
                                    WHERE server_data.server_id = get_dtr_data.server_id),
                                   1.0),
                             0.0)                                                                          AS regen_percentage,
                    LEAST(COUNT(user_uuid) + 0.01, (SELECT dtr_max
                                                    FROM server_data
                                                    WHERE server_data.server_id = get_dtr_data.server_id)) AS current_max_dtr,
                    current_minimum_dtr,
                    frozen_until
             FROM faction_data
                      LEFT JOIN faction_current_dtr_regen_players
                                ON faction_data.faction_id = faction_current_dtr_regen_players.faction_id
                      JOIN factions ON factions.id = faction_data.faction_id
             WHERE factions.party_uuid = get_dtr_data.party_uuid
             GROUP BY frozen_until, current_minimum_dtr)
SELECT frozen_until,
       current_max_dtr,
       current_minimum_dtr +
       ((current_max_dtr - current_minimum_dtr) * regen_percentage) AS current_regen_adjusted_dtr -- minimum + (amount to be regen'd * regen percentage)
FROM cte
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_dtr(server_id INTEGER, party_uuid UUID)
    RETURNS REAL
AS
$$
WITH cte AS (SELECT GREATEST(LEAST(EXTRACT(EPOCH FROM (NOW() - frozen_until)) /
                                   (SELECT dtr_max_time
                                    FROM server_data
                                    WHERE server_data.server_id = get_dtr.server_id),
                                   1.0),
                             0.0)                                                                     AS regen_percentage,
                    LEAST(COUNT(user_uuid) + 0.01, (SELECT dtr_max
                                                    FROM server_data
                                                    WHERE server_data.server_id = get_dtr.server_id)) AS current_max_dtr,
                    current_minimum_dtr,
                    frozen_until
             FROM faction_data
                      LEFT JOIN faction_current_dtr_regen_players
                                ON faction_data.faction_id = faction_current_dtr_regen_players.faction_id
                      JOIN factions ON factions.id = faction_data.faction_id
             WHERE factions.party_uuid = get_dtr.party_uuid
             GROUP BY frozen_until, current_minimum_dtr)
SELECT current_minimum_dtr +
       ((current_max_dtr - current_minimum_dtr) * regen_percentage) AS current_regen_adjusted_dtr -- minimum + (amount to be regen'd * regen percentage)
FROM cte
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_f_list_data(server_id INTEGER, party_uuids UUID[])
    RETURNS TABLE
            (
                name                       TEXT,
                party_uuid                 UUID,
                current_regen_adjusted_dtr REAL
            )
AS
$$
WITH cte AS (SELECT GREATEST(LEAST(EXTRACT(EPOCH FROM (NOW() - frozen_until)) /
                                   (SELECT dtr_max_time
                                    FROM server_data
                                    WHERE server_data.server_id = get_f_list_data.server_id),
                                   1.0),
                             0.0)                                                                             AS regen_percentage,
                    LEAST(COUNT(user_uuid) + 0.01, (SELECT dtr_max
                                                    FROM server_data
                                                    WHERE server_data.server_id = get_f_list_data.server_id)) AS current_max_dtr,
                    current_minimum_dtr,
                    name,
                    party_uuid
             FROM faction_data
                      JOIN faction_current_dtr_regen_players
                           ON faction_data.faction_id = faction_current_dtr_regen_players.faction_id
                      JOIN factions ON factions.id = faction_data.faction_id
             WHERE party_uuid = ANY (get_f_list_data.party_uuids)
             GROUP BY frozen_until, current_minimum_dtr, name, party_uuid)
SELECT name,
       party_uuid,
       current_minimum_dtr +
       ((current_max_dtr - current_minimum_dtr) * regen_percentage) AS current_regen_adjusted_dtr -- minimum + (amount to be regen'd * regen percentage)
FROM cte
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_faction_home(world_name TEXT, x INTEGER, y INTEGER, z INTEGER, pitch REAL, yaw REAL,
                                                party_uuid UUID)
AS
$$
UPDATE faction_data
SET home_world_name = world_name,
    home_x          = x,
    home_y          = y,
    home_z          = z,
    home_pitch      = pitch,
    home_yaw        = yaw
WHERE faction_id = (SELECT id FROM factions WHERE factions.party_uuid = update_faction_home.party_uuid)
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION update_faction_balance_subtract_return_result(amount INTEGER, party_uuid UUID)
    RETURNS INTEGER
AS
$$
UPDATE faction_data
SET balance = balance - amount
WHERE faction_id =
      (SELECT id FROM factions WHERE factions.party_uuid = update_faction_balance_subtract_return_result.party_uuid)
  AND balance >= amount
RETURNING balance
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION update_faction_balance_add_return_result(party_uuid UUID, reason TEXT, user_uuid UUID, amount INTEGER)
    RETURNS INTEGER
AS
$$
WITH cte
         AS (INSERT INTO faction_timestamps (faction_id, reason, user_uuid) VALUES ((SELECT id
                                                                                     FROM factions
                                                                                     WHERE factions.party_uuid =
                                                                                           update_faction_balance_add_return_result.party_uuid),
                                                                                    update_faction_balance_add_return_result.reason,
                                                                                    update_faction_balance_add_return_result.user_uuid) RETURNING faction_id)
UPDATE faction_data
SET balance = balance + amount
WHERE faction_id = (SELECT faction_id FROM cte)
RETURNING balance
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION handle_update_faction_name_return_result(new_name TEXT, server_id INTEGER, faction_uuid UUID,
                                                                    chat_message TEXT, user_uuid UUID)
    RETURNS BOOLEAN
AS
$$
WITH cte AS (SELECT EXISTS(SELECT *
                           FROM factions
                           WHERE name = new_name
                             AND factions.server_id = handle_update_faction_name_return_result.server_id) AS exists), -- TODO -> account for disbanded
     id
         AS (UPDATE factions SET name = new_name WHERE party_uuid = faction_uuid AND NOT (SELECT exists FROM cte) RETURNING id)
INSERT
INTO faction_timestamps (faction_id, reason, user_uuid)
SELECT (SELECT id FROM id), chat_message, handle_update_faction_name_return_result.user_uuid
WHERE NOT (SELECT exists FROM cte)
RETURNING NOT (SELECT exists FROM cte)
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION update_withdraw_faction_balance_return_results(faction_uuid UUID, amount INTEGER)
    RETURNS TABLE
            (
                withdraw_amount INTEGER,
                balance         INTEGER
            )
AS
$$
WITH cte AS (SELECT balance, faction_id
             FROM faction_data
                      JOIN factions ON faction_data.faction_id = factions.id
             WHERE party_uuid = faction_uuid)
UPDATE faction_data
SET balance = GREATEST(balance - amount, 0)
WHERE faction_id = (SELECT faction_id FROM cte)
RETURNING LEAST((SELECT balance FROM cte), amount), balance
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION update_add_faction_minimum_dtr_return_name(faction_uuid UUID, amount INTEGER)
    RETURNS TEXT
AS
$$
WITH cte AS (SELECT name, id
             FROM factions
             WHERE party_uuid = faction_uuid)
UPDATE faction_data
SET current_minimum_dtr = current_minimum_dtr + amount
WHERE faction_id = (SELECT id FROM cte)
RETURNING (SELECT name FROM cte)
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION update_set_faction_frozen_until_return_name(faction_uuid UUID, frozen_until TIMESTAMPTZ)
    RETURNS TEXT -- TODO -> this retroactively regens dtr if set to the past
AS
$$
WITH cte AS (SELECT name, id
             FROM factions
             WHERE party_uuid = faction_uuid)
UPDATE faction_data
SET frozen_until = update_set_faction_frozen_until_return_name.frozen_until
WHERE faction_id = (SELECT id FROM cte)
RETURNING (SELECT name FROM cte)
$$ LANGUAGE sql;

CREATE TABLE IF NOT EXISTS faction_current_dtr_regen_players
(
    faction_id INTEGER,
    user_uuid  UUID,
    FOREIGN KEY (faction_id) REFERENCES factions (id),
    PRIMARY KEY (faction_id, user_uuid)
);
CREATE OR REPLACE PROCEDURE insert_dtr_regen_player(user_uuid UUID, party_uuid UUID)
AS
$$
INSERT INTO faction_current_dtr_regen_players (user_uuid, faction_id)
VALUES (insert_dtr_regen_player.user_uuid,
        (SELECT id FROM factions WHERE factions.party_uuid = insert_dtr_regen_player.party_uuid))
ON CONFLICT (user_uuid, faction_id) DO NOTHING
$$ LANGUAGE sql;

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
CREATE OR REPLACE FUNCTION insert_user_fight_return_id(user_uuid UUID, server_id INTEGER)
    RETURNS INTEGER AS
$$
WITH cte AS (
    INSERT INTO fights (fight_uuid, server_id)
        VALUES (insert_user_fight_return_id.user_uuid, insert_user_fight_return_id.server_id)
        ON CONFLICT (fight_uuid, server_id)
            DO UPDATE SET fight_uuid = EXCLUDED.fight_uuid
        RETURNING id)
INSERT
INTO user_fights (user_uuid, fight_id)
VALUES (insert_user_fight_return_id.user_uuid, (SELECT id FROM cte))
RETURNING id
$$ LANGUAGE sql;

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
CREATE OR REPLACE FUNCTION get_12_latest_network_deaths()
    RETURNS TABLE
            (
                game_mode_name          TEXT,
                name                    TEXT,
                victim_user_fight_id    INTEGER,
                "timestamp"             TIMESTAMPTZ,
                victim_uuid             UUID,
                bukkit_victim_inventory BYTEA,
                death_world             TEXT,
                death_x                 INTEGER,
                death_y                 INTEGER,
                death_z                 INTEGER,
                death_message           TEXT,
                killer_uuid             UUID,
                bukkit_kill_weapon      BYTEA,
                bukkit_killer_inventory BYTEA
            )
AS
$$
SELECT servers.game_mode_name,
       name,
       victim_user_fight_id,
       user_deaths.timestamp,
       victim_uuid,
       bukkit_victim_inventory,
       death_world,
       death_x,
       death_y,
       death_z,
       death_message,
       killer_uuid,
       bukkit_kill_weapon,
       bukkit_killer_inventory
FROM user_deaths
         JOIN servers ON user_deaths.server_id = servers.id
ORDER BY timestamp DESC
LIMIT 12
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_12_latest_server_deaths(game_mode_name TEXT, server_name TEXT)
    RETURNS TABLE
            (
                game_mode_name          TEXT,
                name                    TEXT,
                victim_user_fight_id    INTEGER,
                "timestamp"             TIMESTAMPTZ,
                victim_uuid             UUID,
                bukkit_victim_inventory BYTEA,
                death_world             TEXT,
                death_x                 INTEGER,
                death_y                 INTEGER,
                death_z                 INTEGER,
                death_message           TEXT,
                killer_uuid             UUID,
                bukkit_kill_weapon      BYTEA,
                bukkit_killer_inventory BYTEA
            )
AS
$$
SELECT servers.game_mode_name,
       name,
       victim_user_fight_id,
       user_deaths.timestamp,
       victim_uuid,
       bukkit_victim_inventory,
       death_world,
       death_x,
       death_y,
       death_z,
       death_message,
       killer_uuid,
       bukkit_kill_weapon,
       bukkit_killer_inventory
FROM user_deaths
         JOIN servers ON user_deaths.server_id = servers.id
WHERE servers.game_mode_name = get_12_latest_server_deaths.game_mode_name
  AND name = server_name
ORDER BY timestamp DESC
LIMIT 12
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION insert_user_death_return_id(
    server_id INTEGER,
    victim_user_fight_id INTEGER,
    victim_uuid UUID,
    bukkit_victim_inventory BYTEA,
    death_world TEXT,
    death_x INTEGER,
    death_y INTEGER,
    death_z INTEGER,
    death_message TEXT,
    killer_uuid UUID,
    bukkit_kill_weapon BYTEA,
    bukkit_killer_inventory BYTEA
)
    RETURNS INTEGER AS
$$
DECLARE
    death_id INTEGER;
BEGIN
    INSERT INTO user_deaths (server_id, victim_user_fight_id, victim_uuid,
                             bukkit_victim_inventory,
                             death_world, death_x, death_y, death_z, death_message,
                             killer_uuid, bukkit_kill_weapon,
                             bukkit_killer_inventory)
    VALUES (insert_user_death_return_id.server_id, insert_user_death_return_id.victim_user_fight_id,
            insert_user_death_return_id.victim_uuid, insert_user_death_return_id.bukkit_victim_inventory,
            insert_user_death_return_id.death_world, insert_user_death_return_id.death_x,
            insert_user_death_return_id.death_y, insert_user_death_return_id.death_z,
            insert_user_death_return_id.death_message, insert_user_death_return_id.killer_uuid,
            insert_user_death_return_id.bukkit_kill_weapon, insert_user_death_return_id.bukkit_killer_inventory)
    RETURNING id INTO death_id;
PERFORM pg_notify('deaths',
                 (SELECT json_build_object('game_mode_name', (SELECT game_mode_name FROM servers WHERE id = server_id),
                                           'server_name',
                                           (SELECT name FROM servers WHERE id = server_id), 'victim_user_fight_id',
                                           insert_user_death_return_id.victim_user_fight_id, 'timestamp', null,
                                           'victim_uuid', insert_user_death_return_id.victim_uuid, 'death_world_name',
                                           insert_user_death_return_id.death_world, 'death_x',
                                           insert_user_death_return_id.death_x,
                                           'death_y', insert_user_death_return_id.death_y, 'death_z',
                                           insert_user_death_return_id.death_z, 'death_message',
                                           insert_user_death_return_id.death_message, 'killer_uuid',
                                           insert_user_death_return_id.killer_uuid)::TEXT));
    RETURN death_id;
END
$$ LANGUAGE plpgsql; -- TODO this piece of fucking shit pg_notify function will literally just not work if i use it in a cte
CREATE OR REPLACE FUNCTION get_user_kill_streak(user_uuid UUID, server_id INTEGER)
    RETURNS INTEGER AS
$$
WITH latest_death
         AS (SELECT COALESCE(MAX(timestamp), '-infinity'::timestamptz) AS timestamp
             FROM user_deaths
             WHERE user_deaths.victim_uuid = get_user_kill_streak.user_uuid
               AND user_deaths.server_id = get_user_kill_streak.server_id)
SELECT COUNT(*) AS kill_streak
FROM user_deaths
WHERE user_deaths.killer_uuid = get_user_kill_streak.user_uuid
  AND user_deaths.server_id = get_user_kill_streak.server_id
  AND timestamp > (SELECT timestamp FROM latest_death)
$$ LANGUAGE sql;

CREATE TABLE IF NOT EXISTS current_heroes -- TODO impl
(
    user_uuid            UUID,
    server_id            INTEGER,
    java_hmac_ip         TEXT        NOT NULL,
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
CREATE OR REPLACE FUNCTION get_7_newest_bandits(game_mode_name TEXT, server_name TEXT)
    RETURNS TABLE
            (
                user_uuid            UUID,
                death_id             INTEGER,
                death_timestamp      TIMESTAMPTZ,
                expiration_timestamp TIMESTAMPTZ,
                bandit_message       TEXT
            )
AS
$$
SELECT user_uuid,
       death_id,
       user_deaths.timestamp,
       expiration_timestamp,
       bandit_message
FROM bandits
         JOIN user_deaths on bandits.death_id = user_deaths.id
         JOIN servers ON user_deaths.server_id = servers.id
WHERE servers.game_mode_name = get_7_newest_bandits.game_mode_name
  AND name = server_name
ORDER BY user_deaths.timestamp DESC
LIMIT 7
$$
    LANGUAGE sql;
CREATE TABLE IF NOT EXISTS current_bandits
(
    bandit_id    INTEGER PRIMARY KEY,
    java_hmac_ip BYTEA NOT NULL,
    FOREIGN KEY (bandit_id) REFERENCES bandits (id)
);
CREATE OR REPLACE FUNCTION get_user_is_bandit(user_uuid UUID, server_id INTEGER, user_ip_bytes BYTEA)
    RETURNS BOOLEAN
AS
$$
WITH cte AS (SELECT EXISTS(SELECT *
                           FROM ip_exempt_uuids
                           WHERE ip_exempt_uuids.user_uuid = get_user_is_bandit.user_uuid
                             AND ip_exempt_uuids.server_id = get_user_is_bandit.server_id) AS is_ip_exempt)
SELECT EXISTS(SELECT expiration_timestamp
              FROM bandits
                       JOIN current_bandits ON bandits.id = current_bandits.bandit_id
              WHERE bandits.server_id = get_user_is_bandit.server_id
                AND expiration_timestamp > NOW()
                AND (bandits.user_uuid = get_user_is_bandit.user_uuid OR
                     (current_bandits.java_hmac_ip = user_ip_bytes AND NOT (SELECT is_ip_exempt FROM cte))))
$$
    LANGUAGE sql;
CREATE OR REPLACE PROCEDURE handle_insert_bandit(bandit_uuid UUID, server_id INTEGER, death_id INTEGER,
                                                 expiration TIMESTAMPTZ,
                                                 bandit_message TEXT, ip_bytes BYTEA)
AS
$$
WITH cte
         AS (INSERT INTO bandits (user_uuid, server_id, death_id, expiration_timestamp, bandit_message) VALUES (bandit_uuid,
                                                                                                                handle_insert_bandit.server_id,
                                                                                                                handle_insert_bandit.death_id,
                                                                                                                expiration,
                                                                                                                handle_insert_bandit.bandit_message) RETURNING *),
     _ AS (SELECT pg_notify('bandits',
                            (SELECT json_build_object('user_uuid', bandit_uuid, 'death_id', death_id, 'death_timestamp',
                                                      user_deaths.timestamp,
                                                      'expiration_timestamp', expiration, 'bandit_message',
                                                      bandit_message)::TEXT
                             FROM user_deaths)))
INSERT
INTO current_bandits (bandit_id, java_hmac_ip)
VALUES ((SELECT id FROM cte), handle_insert_bandit.ip_bytes)
$$
    LANGUAGE sql;

CREATE TABLE IF NOT EXISTS deathbans
(
    death_id   INTEGER PRIMARY KEY,
    expiration TIMESTAMPTZ NOT NULL,
    is_ip_only BOOLEAN     NOT NULL,
    FOREIGN KEY (death_id) REFERENCES user_deaths (id) ON DELETE CASCADE
);
CREATE OR REPLACE FUNCTION get_farthest_user_death_ban(victim_uuid UUID, server_id INTEGER)
    RETURNS TABLE
            (
                expiration    TIMESTAMPTZ,
                death_message TEXT
            )
AS
$$
SELECT expiration, death_message
FROM deathbans
         JOIN user_deaths ON user_deaths.id = deathbans.death_id
WHERE user_deaths.victim_uuid = get_farthest_user_death_ban.victim_uuid
  AND user_deaths.server_id = get_farthest_user_death_ban.server_id
  AND expiration > NOW()
  AND NOT is_ip_only
  AND timestamp > COALESCE((SELECT timestamp
                            FROM revives
                            WHERE revived_user_uuid = get_farthest_user_death_ban.victim_uuid
                              AND revives.server_id = get_farthest_user_death_ban.server_id
                            ORDER BY timestamp DESC
                            LIMIT 1), '-infinity'::timestamptz)
ORDER BY expiration DESC
LIMIT 1
$$ LANGUAGE sql;
CREATE TABLE IF NOT EXISTS current_deathbans
(
    deathban_id  INTEGER PRIMARY KEY,
    java_hmac_ip BYTEA, -- TODO not null ?
    FOREIGN KEY (deathban_id) REFERENCES deathbans (death_id) ON DELETE CASCADE
);
CREATE OR REPLACE FUNCTION handle_insert_deathban_return_duration_data_if_inserted(user_uuid UUID, server_id INTEGER,
                                                                                   user_seconds_played INTEGER,
                                                                                   death_id INTEGER, ip_bytes BYTEA)
    RETURNS TABLE
            (
                death_ban_seconds   INTEGER,
                deathban_expiration TIMESTAMPTZ,
                is_ip_only          BOOLEAN
            )
AS
$$
DECLARE
    hcf_donation_rank_if_hcf TEXT;
    death_ban_seconds        INTEGER;
    is_ip_only               BOOLEAN;
    deathban_expiration      TIMESTAMPTZ;
BEGIN
    IF (SELECT game_mode_name FROM servers WHERE id = server_id) = 'hcf' THEN
        SELECT get_donation_rank(user_uuid, 'hcf')
        INTO hcf_donation_rank_if_hcf;
    END IF;

    SELECT LEAST(death_ban_minutes * 60, user_seconds_played) *
           CASE hcf_donation_rank_if_hcf
               WHEN 'default' THEN 1
               WHEN 'basic' THEN .8
               WHEN 'gold' THEN .6
               WHEN 'diamond' THEN .4
               WHEN 'ruby' THEN .2
               ELSE 1 END,
           is_ip_deathban_else_full
    INTO death_ban_seconds, is_ip_only
    FROM server_data
    WHERE server_data.server_id =
          handle_insert_deathban_return_duration_data_if_inserted.server_id;

    INSERT INTO deathbans (death_id, expiration, is_ip_only)
    SELECT handle_insert_deathban_return_duration_data_if_inserted.death_id,
           NOW() + death_ban_seconds * INTERVAL '1 second',
           is_ip_only
    WHERE death_ban_seconds > 0
    RETURNING expiration INTO deathban_expiration;

    INSERT
    INTO current_deathbans (deathban_id, java_hmac_ip)
    SELECT handle_insert_deathban_return_duration_data_if_inserted.death_id,
           handle_insert_deathban_return_duration_data_if_inserted.ip_bytes
    WHERE death_ban_seconds > 0;

    RETURN QUERY SELECT death_ban_seconds, deathban_expiration, is_ip_only;
END
$$
    LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION get_farthest_user_ip_deathban(user_uuid UUID, ip_bytes BYTEA, server_id INTEGER)
    RETURNS TABLE
            (
                expiration    TIMESTAMPTZ,
                death_message TEXT
            )
AS
$$
SELECT expiration, death_message
FROM deathbans
         JOIN current_deathbans ON deathbans.death_id = current_deathbans.deathban_id
         JOIN user_deaths ON deathbans.death_id = user_deaths.id
WHERE victim_uuid != user_uuid
  AND current_deathbans.java_hmac_ip = get_farthest_user_ip_deathban.ip_bytes
  AND user_deaths.server_id = get_farthest_user_ip_deathban.server_id
  AND (NOT EXISTS(SELECT *
                  FROM ip_exempt_uuids
                  WHERE ip_exempt_uuids.user_uuid = get_farthest_user_ip_deathban.user_uuid
                    AND ip_exempt_uuids.server_id = get_farthest_user_ip_deathban.server_id))
  AND expiration > NOW()
  AND timestamp > COALESCE((SELECT revives.timestamp
                            FROM revives
                                     JOIN user_deaths ON victim_uuid = revived_user_uuid
                            WHERE revived_user_uuid = user_deaths.victim_uuid
                              AND revives.server_id = get_farthest_user_ip_deathban.server_id
                            ORDER BY timestamp DESC
                            LIMIT 1),
                           '-infinity'::timestamptz) -- TODO -> this requires ip death-ban's to revive the victim directly, which is fine for now
ORDER BY expiration DESC
LIMIT 1
$$ LANGUAGE sql;

CREATE TABLE IF NOT EXISTS revives
(
    id                 INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    revived_user_uuid  UUID    NOT NULL,
    timestamp          TIMESTAMPTZ DEFAULT NOW(),
    server_id          INTEGER NOT NULL,
    reason             TEXT    NOT NULL,
    reviver_user_uuid  UUID    NOT NULL,
    life_cost_in_cents INTEGER NOT NULL
);
CREATE OR REPLACE PROCEDURE insert_revive(revived_uuid UUID, server_id INTEGER, reason TEXT, reviver_uuid UUID)
AS
$$
INSERT INTO revives (revived_user_uuid, server_id, reason, reviver_user_uuid, life_cost_in_cents)
VALUES (revived_uuid, insert_revive.server_id, insert_revive.reason, reviver_uuid, 0)
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_user_game_mode_lives_as_cents(user_uuid UUID, game_mode_name TEXT)
    RETURNS INTEGER
AS
$$
SELECT (SELECT COALESCE(SUM(line_item_quantity), 0) * 100
                   AS purchased_lives_as_cents
        FROM successful_transactions
        WHERE successful_transactions.user_uuid = get_user_game_mode_lives_as_cents.user_uuid
          AND line_item_id = (SELECT id
                              FROM line_items
                              WHERE line_items.game_mode_name = get_user_game_mode_lives_as_cents.game_mode_name
                                AND line_item_name = 'life')) - COALESCE(SUM(revives.life_cost_in_cents), 0)
FROM revives
WHERE revives.reviver_user_uuid = get_user_game_mode_lives_as_cents.user_uuid
  AND server_id IN
      (SELECT id FROM servers WHERE servers.game_mode_name = get_user_game_mode_lives_as_cents.game_mode_name)
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION handle_insert_revive_return_result_in_cents_if_successful(game_mode_name TEXT,
                                                                                     reviver_uuid UUID,
                                                                                     revived_uuid UUID,
                                                                                     server_id INTEGER,
                                                                                     reason TEXT)
    RETURNS INTEGER -- TODO -> this should get the server id by itself
AS
$$
WITH cte AS (SELECT get_user_game_mode_lives_as_cents(reviver_uuid, game_mode_name) AS current_lives_as_cents),
     bar
         AS (SELECT off_peak_lives_needed_as_cents * CASE
                                                         WHEN get_is_koth_active(handle_insert_revive_return_result_in_cents_if_successful.server_id)
                                                             THEN .5
                                                         ELSE 1 END AS life_cost_in_cents
             FROM server_data)
INSERT
INTO revives (revived_user_uuid, server_id, reason, reviver_user_uuid, life_cost_in_cents)
SELECT revived_uuid,
       handle_insert_revive_return_result_in_cents_if_successful.server_id,
       handle_insert_revive_return_result_in_cents_if_successful.reason,
       reviver_uuid,
       (SELECT life_cost_in_cents FROM bar)
WHERE (SELECT current_lives_as_cents FROM cte) - (SELECT life_cost_in_cents FROM bar) > 0
RETURNING (SELECT current_lives_as_cents FROM cte) - (SELECT life_cost_in_cents FROM bar);
$$ LANGUAGE sql;

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
CREATE OR REPLACE FUNCTION get_arena_names(server_id INTEGER)
    RETURNS TEXT[] AS
$$
SELECT ARRAY(SELECT name
             FROM server_arenas
                      JOIN arena_data ON server_arenas.arena_id = arena_data.id
             WHERE server_arenas.server_id = get_arena_names.server_id)
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION upsert_server_arena_return_id(name TEXT, creator TEXT, server_id INTEGER)
    RETURNS INTEGER
AS
$$
WITH cte
         AS (INSERT INTO arena_data (name, creator) VALUES (upsert_server_arena_return_id.name,
                                                            upsert_server_arena_return_id.creator) ON CONFLICT (name) DO UPDATE SET creator = EXCLUDED.creator RETURNING id)
INSERT
INTO server_arenas (arena_id, server_id)
VALUES ((SELECT id FROM cte), upsert_server_arena_return_id.server_id)
RETURNING id
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_server_arena_name_exists(name TEXT, server_id INTEGER)
    RETURNS BOOLEAN AS
$$
SELECT EXISTS(SELECT *
              FROM server_arenas
                       JOIN arena_data ON server_arenas.arena_id = arena_data.id
              WHERE arena_data.name = get_server_arena_name_exists.name
                AND server_arenas.server_id = get_server_arena_name_exists.server_id)
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION delete_server_arena_return_id(name TEXT, server_id INTEGER)
    RETURNS INTEGER AS
$$
DELETE
FROM server_arenas
WHERE id = (SELECT server_arenas.id
            FROM server_arenas
                     JOIN arena_data ON server_arenas.arena_id = arena_data.id
            WHERE arena_data.name = delete_server_arena_return_id.name
              AND server_arenas.server_id = delete_server_arena_return_id.server_id)
RETURNING id
$$ LANGUAGE sql;
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
CREATE OR REPLACE FUNCTION get_arena_data(arena_id INTEGER)
    RETURNS TABLE
            (
                name    TEXT,
                creator TEXT
            )
AS
$$
SELECT name, creator
FROM arena_data
         LEFT JOIN server_koths ON arena_data.id = server_koths.arena_id
         LEFT JOIN server_arenas ON arena_data.id = server_arenas.arena_id
WHERE server_arenas.id = get_arena_data.arena_id
   OR server_koths.id = get_arena_data.arena_id
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION upsert_server_koth_return_id(arena_name TEXT, arena_creator TEXT, server_id INTEGER,
                                                        world_name TEXT, x INTEGER,
                                                        y INTEGER, z INTEGER)
    RETURNS INTEGER
AS
$$
WITH cte AS
         (
             INSERT INTO arena_data (name, creator)
                 VALUES (arena_name, arena_creator)
                 ON CONFLICT (name) DO UPDATE SET creator = EXCLUDED.creator
                 RETURNING id)
INSERT
INTO server_koths (arena_id, server_id, world, x, y, z)
VALUES ((SELECT id FROM cte), upsert_server_koth_return_id.server_id, world_name, upsert_server_koth_return_id.x,
        upsert_server_koth_return_id.y, upsert_server_koth_return_id.z)
ON CONFLICT (arena_id, server_id) DO UPDATE SET world = EXCLUDED.world,
                                                x     = EXCLUDED.x,
                                                y     = EXCLUDED.y,
                                                z     = EXCLUDED.z
RETURNING id
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION delete_server_koth_return_id(koth_name TEXT, server_id INTEGER)
    RETURNS INTEGER
AS
$$
DELETE
FROM server_koths
WHERE arena_id = (SELECT id FROM arena_data WHERE name = koth_name)
  AND server_koths.server_id = delete_server_koth_return_id.server_id
RETURNING id
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_server_koth_datas(server_id INTEGER)
    RETURNS TABLE
            (
                world   TEXT,
                x       INTEGER,
                y       INTEGER,
                z       INTEGER,
                name    TEXT,
                CREATOR text
            )
AS
$$
SELECT world, x, y, z, name, creator
FROM server_koths
         JOIN arena_data ON server_koths.arena_id = arena_data.id
WHERE server_koths.server_id = get_server_koth_datas.server_id
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_server_koth_id(koth_name TEXT, server_id INTEGER)
    RETURNS INTEGER
AS
$$
SELECT server_koths.id
FROM server_koths
         JOIN arena_data ON server_koths.arena_id = arena_data.id
WHERE name = koth_name
  AND server_koths.server_id = get_server_koth_id.server_id
$$ LANGUAGE sql;

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
CREATE OR REPLACE FUNCTION update_koths_capper_return_optional_data(server_koth_id INTEGER, user_uuid UUID)
    RETURNS TABLE
            (
                name      TEXT,
                max_timer INTEGER
            )
AS
$$
WITH cte AS (SELECT koths.id, name, max_timer
             FROM koths
                      JOIN server_koths ON koths.server_koths_id = server_koths.id
                      JOIN arena_data ON server_koths.arena_id = arena_data.id
             WHERE server_koths_id = server_koth_id
               AND end_timestamp IS NULL
               AND capping_user_uuid IS NULL)
UPDATE koths
SET capping_user_uuid = user_uuid
WHERE id = (SELECT id FROM cte)
RETURNING (SELECT name FROM cte), (SELECT max_timer FROM cte)
$$ LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_knocked_koth_user_uuid(user_uuid UUID, server_koth_id INTEGER)
AS
$$
UPDATE koths
SET capping_user_uuid = NULL
WHERE capping_user_uuid = user_uuid
  AND server_koths_id = server_koth_id
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION update_successful_koth_capture_return_loot_factor(party_uuid UUID, server_koth_id INTEGER)
    RETURNS INTEGER
AS
$$
UPDATE koths
SET end_timestamp      = NOW(),
    capping_party_uuid = party_uuid
WHERE server_koths_id = server_koth_id
  AND end_timestamp IS NULL
RETURNING loot_factor
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION handle_server_koth_toggle_return_star(koth_name TEXT, server_id INTEGER,
                                                                 koth_max_timer INTEGER,
                                                                 koth_is_movement_restricted BOOLEAN)
    RETURNS SETOF koths
AS
$$
WITH cte AS (SELECT server_koths.id
             FROM server_koths
                      JOIN arena_data ON server_koths.arena_id = arena_data.id
             WHERE name = koth_name
               AND server_koths.server_id = handle_server_koth_toggle_return_star.server_id),
     _ AS (DELETE FROM koths WHERE end_timestamp IS NULL AND
                                                        server_koths_id = (SELECT id FROM cte))
INSERT
INTO koths (server_koths_id, loot_factor, max_timer, is_movement_restricted)
SELECT (SELECT id FROM cte),
       (SELECT server_data.default_koth_loot_factor
        FROM server_data
        WHERE server_data.server_id = handle_server_koth_toggle_return_star.server_id),
       koth_max_timer,
       koth_is_movement_restricted
WHERE NOT EXISTS(SELECT *
                 FROM koths
                 WHERE end_timestamp IS NULL
                   AND server_koths_id = (SELECT id FROM cte))
RETURNING *
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION toggle_active_koth_is_movement_restricted_return_result(koth_name TEXT, server_id INTEGER)
    RETURNS BOOLEAN
AS
$$
UPDATE koths
SET is_movement_restricted = NOT is_movement_restricted
WHERE end_timestamp IS NULL
  AND id = (SELECT server_koths.id
            FROM arena_data
                     JOIN server_koths ON arena_data.id = server_koths.arena_id
            WHERE name = koth_name
              AND server_koths.server_id = toggle_active_koth_is_movement_restricted_return_result.server_id)
RETURNING is_movement_restricted
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_is_koth_active(server_id INTEGER)
    RETURNS BOOLEAN
AS
$$
SELECT EXISTS (SELECT * FROM koths WHERE server_id = get_is_koth_active.server_id AND end_timestamp IS NULL)
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_14_newest_network_koths()
    RETURNS TABLE
            (
                server_koths_id        INTEGER,
                start_timestamp        TIMESTAMPTZ,
                loot_factor            INTEGER,
                max_timer              INTEGER,
                is_movement_restricted BOOLEAN,
                capping_user_uuid      UUID,
                end_timestamp          TIMESTAMPTZ,
                capping_party_uuid     UUID,
                world                  TEXT,
                cap_message            TEXT,
                x                      INTEGER,
                y                      INTEGER,
                z                      INTEGER,
                game_mode_name         TEXT,
                server_name            TEXT,
                arena_name             TEXT,
                creator                TEXT

            )
AS
$$
SELECT server_koths_id,
       start_timestamp,
       loot_factor,
       max_timer,
       is_movement_restricted,
       CASE WHEN end_timestamp IS NOT NULL THEN capping_user_uuid END AS capping_user_uuid,
       end_timestamp,
       capping_party_uuid,
       cap_message,
       world,
       x,
       y,
       z,
       game_mode_name,
       servers.name                                                   AS server_name,
       arena_data.name                                                AS arena_name,
       creator
FROM koths
         JOIN server_koths ON server_koths_id = server_koths.id
         JOIN servers ON servers.id = server_koths.server_id
         JOIN arena_data ON arena_data.id = server_koths.arena_id
WHERE end_timestamp IS NOT NULL
ORDER BY end_timestamp
LIMIT 14
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_14_newest_server_koths(game_mode_name TEXT, server_name TEXT)
    RETURNS TABLE
            (
                server_koths_id        INTEGER,
                start_timestamp        TIMESTAMPTZ,
                loot_factor            INTEGER,
                max_timer              INTEGER,
                is_movement_restricted BOOLEAN,
                capping_user_uuid      UUID,
                end_timestamp          TIMESTAMPTZ,
                capping_party_uuid     UUID,
                cap_message            TEXT,
                world                  TEXT,
                x                      INTEGER,
                y                      INTEGER,
                z                      INTEGER,
                game_mode_name         TEXT,
                server_name            TEXT,
                arena_name             TEXT,
                creator                TEXT
            )
AS
$$
SELECT server_koths_id,
       start_timestamp,
       loot_factor,
       max_timer,
       is_movement_restricted,
       CASE WHEN end_timestamp IS NOT NULL THEN capping_user_uuid END AS capping_user_uuid,
       end_timestamp,
       capping_party_uuid,
       cap_message,
       world,
       x,
       y,
       z,
       servers.game_mode_name,
       servers.name                                                   AS server_name,
       arena_data.name                                                AS arena_name,
       creator
FROM koths
         JOIN server_koths ON server_koths_id = server_koths.id
         JOIN servers ON servers.id = server_koths.server_id
         JOIN arena_data ON arena_data.id = server_koths.arena_id
WHERE servers.game_mode_name = get_14_newest_server_koths.game_mode_name
  AND servers.name = get_14_newest_server_koths.server_name
  AND end_timestamp IS NULL
ORDER BY end_timestamp
LIMIT 14
$$
    LANGUAGE sql;

CREATE TABLE IF NOT EXISTS supply_drops
(
    id                          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    server_id                   INTEGER     NOT NULL,
    start_timestamp             TIMESTAMPTZ NOT NULL,

    nullable_server_koth_id     INTEGER,
    is_koth_movement_restricted BOOLEAN     NOT NULL,
    world_name                  TEXT        NOT NULL,
    x                           INTEGER     NOT NULL,
    y                           INTEGER     NOT NULL,
    z                           INTEGER     NOT NULL,
    radius                      INTEGER     NOT NULL,
    chest_open_timestamp        TIMESTAMPTZ NOT NULL,
    loot_factor                 INTEGER     NOT NULL,
    restock_timer               INTEGER     NOT NULL,
    restock_amount              INTEGER     NOT NULL,

    end_timestamp               TIMESTAMPTZ,
    win_message                 TEXT,
    FOREIGN KEY (nullable_server_koth_id) REFERENCES server_koths (id),
    FOREIGN KEY (server_id) REFERENCES servers (id)
);
CREATE OR REPLACE FUNCTION get_14_newest_network_supply_drops()
    RETURNS TABLE
            (
                id                          INTEGER,
                server_name                 TEXT,
                game_mode_name              TEXT,
                start_timestamp             TIMESTAMPTZ,

                nullable_server_koth_id     INTEGER,
                is_koth_movement_restricted BOOLEAN,
                world_name                  TEXT,
                x                           INTEGER,
                y                           INTEGER,
                z                           INTEGER,
                radius                      INTEGER,
                chest_open_timestamp        TIMESTAMPTZ,
                loot_factor                 INTEGER,
                restock_timer               INTEGER,
                restock_amount              INTEGER,

                end_timestamp               TIMESTAMPTZ,
                win_message                 TEXT
            )
AS
$$
SELECT supply_drops.id,
       servers.name,
       game_mode_name,
       start_timestamp,
       nullable_server_koth_id,
       is_koth_movement_restricted,
       world_name,
       x,
       y,
       z,
       radius,
       chest_open_timestamp,
       loot_factor,
       restock_timer,
       restock_amount,
       end_timestamp,
       win_message
FROM supply_drops
         JOIN servers ON supply_drops.server_id = servers.id
WHERE end_timestamp IS NOT NULL
ORDER BY end_timestamp
LIMIT 14
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_14_newest_network_supply_drops(server_name TEXT, game_mode_name TEXT)
    RETURNS TABLE
            (
                id                          INTEGER,
                server_name                 TEXT,
                game_mode_name              TEXT,
                start_timestamp             TIMESTAMPTZ,

                nullable_server_koth_id     INTEGER,
                is_koth_movement_restricted BOOLEAN,
                world_name                  TEXT,
                x                           INTEGER,
                y                           INTEGER,
                z                           INTEGER,
                radius                      INTEGER,
                chest_open_timestamp        TIMESTAMPTZ,
                loot_factor                 INTEGER,
                restock_timer               INTEGER,
                restock_amount              INTEGER,

                end_timestamp               TIMESTAMPTZ,
                win_message                 TEXT
            )
AS
$$
SELECT supply_drops.id,
       servers.name,
       servers.game_mode_name,
       start_timestamp,
       nullable_server_koth_id,
       is_koth_movement_restricted,
       world_name,
       x,
       y,
       z,
       radius,
       chest_open_timestamp,
       loot_factor,
       restock_timer,
       restock_amount,
       end_timestamp,
       win_message
FROM supply_drops
         JOIN servers ON supply_drops.server_id = servers.id
WHERE end_timestamp IS NOT NULL
  AND servers.name = get_14_newest_network_supply_drops.server_name
  AND servers.game_mode_name = get_14_newest_network_supply_drops.game_mode_name
ORDER BY end_timestamp
LIMIT 14
$$
    LANGUAGE sql;
CREATE TABLE IF NOT EXISTS supply_drop_rounds
(
    id                              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supply_drop_id                  INTEGER NOT NULL,
    timestamp                       TIMESTAMPTZ DEFAULT NOW(),
    java_chest_location_coordinates BYTEA   NOT NULL,

    win_message                     TEXT,
    end_timestamp                   TIMESTAMPTZ,
    FOREIGN KEY (supply_drop_id) REFERENCES supply_drops (id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS supply_drops_rounds_item_data
(
    supply_drop_round_id INTEGER NOT NULL,
    user_uuid            UUID    NOT NULL,
    party_uuid           UUID,
    chests_looted        INTEGER NOT NULL,
    FOREIGN KEY (supply_drop_round_id) REFERENCES supply_drop_rounds (id) ON DELETE CASCADE,
    PRIMARY KEY (supply_drop_round_id, user_uuid)
);
CREATE OR REPLACE FUNCTION insert_supply_drop_return_data(server_id INTEGER,
                                                          world_name TEXT,
                                                          x INTEGER, y INTEGER, z INTEGER, radius INTEGER,
                                                          chest_open_timestamp TIMESTAMPTZ,
                                                          restock_timer INTEGER,
                                                          restock_amount INTEGER,
                                                          nullable_server_koth_id INTEGER,
                                                          is_koth_movement_restricted BOOLEAN)
    RETURNS TABLE
            (
                loot_factor    INTEGER,
                supply_drop_id INTEGER
            )
AS
$$
INSERT INTO supply_drops (server_id, start_timestamp, world_name, x, y, z, radius, chest_open_timestamp, loot_factor,
                          restock_timer, restock_amount, nullable_server_koth_id, is_koth_movement_restricted)
VALUES (insert_supply_drop_return_data.server_id, NOW(),
        insert_supply_drop_return_data.world_name,
        insert_supply_drop_return_data.x, insert_supply_drop_return_data.y,
        insert_supply_drop_return_data.z, insert_supply_drop_return_data.radius,
        insert_supply_drop_return_data.chest_open_timestamp,
        (SELECT default_koth_loot_factor
         FROM server_data
         WHERE server_data.server_id = insert_supply_drop_return_data.server_id),
        insert_supply_drop_return_data.restock_timer,
        insert_supply_drop_return_data.restock_amount,
        insert_supply_drop_return_data.nullable_server_koth_id,
        insert_supply_drop_return_data.is_koth_movement_restricted)
RETURNING loot_factor, id
$$
    LANGUAGE sql;
CREATE OR REPLACE PROCEDURE insert_supply_drop_round(id INTEGER, bytes BYTEA)
AS
$$
WITH _ AS (
    UPDATE supply_drop_rounds
        SET end_timestamp = NOW()
        WHERE supply_drop_id = insert_supply_drop_round.id
            AND end_timestamp IS NULL)
INSERT
INTO supply_drop_rounds (supply_drop_id, java_chest_location_coordinates)
VALUES (insert_supply_drop_round.id, bytes)
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION insert_supply_drop_round_data_return_data_if_continuing(id INTEGER)
    RETURNS SETOF supply_drops
AS
$$
SELECT *
FROM supply_drops
WHERE supply_drops.id = insert_supply_drop_round_data_return_data_if_continuing.id
  AND EXISTS(SELECT *
             FROM supply_drops
             WHERE supply_drops.id = insert_supply_drop_round_data_return_data_if_continuing.id
               AND (SELECT COUNT(*)
                    FROM supply_drop_rounds
                    WHERE supply_drop_id = insert_supply_drop_round_data_return_data_if_continuing.id) < restock_amount)
$$
    LANGUAGE sql;
CREATE OR REPLACE PROCEDURE upsert_supply_drop_round_data(id INTEGER, user_uuid UUID, party_uuid UUID) -- TODO -> make this message the player with an update
AS
$$
WITH cte AS (SELECT EXISTS(SELECT *
                           FROM supply_drops
                           WHERE end_timestamp IS NULL
                             AND supply_drops.id = upsert_supply_drop_round_data.id) AS isnt_expired)
INSERT
INTO supply_drops_rounds_item_data (supply_drop_round_id, user_uuid, party_uuid, chests_looted)
SELECT (SELECT supply_drop_rounds.id
        FROM supply_drop_rounds
        WHERE supply_drop_id = upsert_supply_drop_round_data.id
          AND end_timestamp IS NULL),
       upsert_supply_drop_round_data.user_uuid,
       upsert_supply_drop_round_data.party_uuid,
       1
FROM cte
WHERE isnt_expired
ON CONFLICT (supply_drop_round_id, user_uuid) DO UPDATE SET chests_looted = supply_drops_rounds_item_data.chests_looted + 1
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_supply_drop_winner_data(supply_drop_id INTEGER)
    RETURNS TABLE
            (
                highest_user_uuid    UUID,
                highest_user_amount  INTEGER,
                highest_party_uuid   UUID,
                highest_party_amount INTEGER
            )
AS
$$
WITH cte AS (SELECT id
             FROM supply_drop_rounds
             WHERE supply_drop_rounds.supply_drop_id = get_supply_drop_winner_data.supply_drop_id),
     foo AS (SELECT user_uuid, SUM(chests_looted) AS total_chests_looted
             FROM supply_drops_rounds_item_data
             WHERE supply_drop_round_id IN (SELECT id FROM cte)
             GROUP BY user_uuid
             ORDER BY total_chests_looted DESC
             LIMIT 1),
     bar AS (SELECT party_uuid, SUM(chests_looted) AS total_chests_looted
             FROM supply_drops_rounds_item_data
             WHERE supply_drop_round_id IN (SELECT id FROM cte)
               AND party_uuid IS NOT NULL
             GROUP BY party_uuid
             ORDER BY total_chests_looted DESC
             LIMIT 1)
SELECT user_uuid,
       total_chests_looted,
       (SELECT party_uuid FROM bar),
       (SELECT total_chests_looted FROM bar)
FROM foo
$$
    LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_finished_supply_drop(message TEXT, supply_drop_id INTEGER)
AS
$$
UPDATE supply_drops
SET end_timestamp = NOW(),
    win_message   = message
WHERE id = supply_drop_id
$$
    LANGUAGE sql;

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
CREATE OR REPLACE FUNCTION get_user_diamond_ores_mined(user_uuid UUID, server_id INTEGER)
    RETURNS INTEGER
AS
$$
SELECT amount
FROM user_diamond_ores_mined
WHERE user_diamond_ores_mined.user_uuid = get_user_diamond_ores_mined.user_uuid
  AND user_diamond_ores_mined.server_id = get_user_diamond_ores_mined.server_id
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION handle_diamond_ores_mined_upsert_return_results(user_uuid UUID, server_id INTEGER, amount INTEGER, party_uuid UUID)
    RETURNS TABLE
            (
                user_diamonds_mined    INTEGER,
                faction_diamonds_mined INTEGER
            ) -- TODO record
AS
$$
WITH cte
         AS (INSERT INTO user_diamond_ores_mined (user_uuid, server_id, amount) VALUES (handle_diamond_ores_mined_upsert_return_results.user_uuid,
                                                                                        handle_diamond_ores_mined_upsert_return_results.server_id,
                                                                                        handle_diamond_ores_mined_upsert_return_results.amount) ON CONFLICT (user_uuid, server_id) DO UPDATE SET
        amount = user_diamond_ores_mined.amount +
                 EXCLUDED.amount RETURNING amount AS user_diamonds_mined),
     foo AS (
         INSERT
             INTO faction_diamond_ores_mined (faction_id, amount)
                 SELECT id, handle_diamond_ores_mined_upsert_return_results.amount
                 FROM factions
                 WHERE factions.party_uuid = handle_diamond_ores_mined_upsert_return_results.party_uuid
                   AND factions.server_id = handle_diamond_ores_mined_upsert_return_results.server_id
                   AND handle_diamond_ores_mined_upsert_return_results.party_uuid IS NOT NULL
                 ON CONFLICT (faction_id) DO UPDATE SET amount =
                         faction_diamond_ores_mined.amount +
                         EXCLUDED.amount RETURNING amount AS faction_diamonds_mined)
SELECT (SELECT user_diamonds_mined FROM cte)    AS user_diamonds_mined,
       (SELECT faction_diamonds_mined FROM foo) AS faction_diamonds_mined
$$ LANGUAGE sql;
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

\i other.sql
\i users.sql
