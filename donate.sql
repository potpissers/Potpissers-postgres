--TODO -> ip referrals, salt definitely necessary
--TODO -> hash ips
CREATE TABLE IF NOT EXISTS user_referrals
(
    user_uuid UUID PRIMARY KEY,
    referrer  TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

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
CREATE OR REPLACE FUNCTION get_donation_rank(
    user_uuid UUID,
    game_mode_name TEXT
)
    RETURNS TEXT
AS
$$
DECLARE
    total_value_in_cents INT;
BEGIN
    SELECT COALESCE(SUM(value_in_cents), 0)
    INTO total_value_in_cents
    FROM successful_transactions
             JOIN line_items ON successful_transactions.line_item_id = line_items.id
    WHERE successful_transactions.user_uuid = get_donation_rank.user_uuid
      AND chat_rank_id IS NOT NULL
      AND line_items.game_mode_name = get_donation_rank.game_mode_name;

    RETURN COALESCE((SELECT name
                     FROM line_items
                              JOIN chat_ranks ON line_items.chat_rank_id = chat_ranks.id
                     WHERE user_uuid = get_donation_rank.user_uuid
                       AND value_in_cents < total_value_in_cents
                     ORDER BY value_in_cents DESC
                     LIMIT 1), 'default'); -- surely doing case value 0 return 'default' is better, but I'm doing this
END;
$$ LANGUAGE plpgsql;