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
    is_chat_mod          BOOLEAN DEFAULT FALSE,
    java_personal_mutes  BYTEA,
    party_uuid           UUID
);
CREATE OR REPLACE PROCEDURE upsert_user_data(user_uuid UUID)
AS
$$
INSERT INTO user_data (user_uuid)
VALUES (upsert_user_data.user_uuid)
ON CONFLICT (user_uuid) DO NOTHING
$$
    LANGUAGE sql;
CREATE OR REPLACE PROCEDURE update_user_chat_type(chat_type_name TEXT, user_uuid UUID)
AS
$$
UPDATE user_data
SET chat_type_id = (SELECT id FROM chat_types WHERE name = chat_type_name)
WHERE user_uuid = update_user_chat_type.user_uuid
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_user_chat_type(user_uuid UUID)
    RETURNS TEXT AS
$$
SELECT name
FROM chat_types
         JOIN user_data ON id = user_data.chat_type_id
WHERE user_data.user_uuid = get_user_chat_type.user_uuid
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION get_user_id_chat_mod(user_uuid UUID)
    RETURNS BOOLEAN AS
$$
SELECT is_chat_mod
FROM user_data
WHERE user_data.user_uuid = get_user_id_chat_mod.user_uuid
$$
    LANGUAGE sql;
CREATE OR REPLACE FUNCTION toggle_is_user_chat_mod_return_result(user_uuid UUID)
    RETURNS BOOLEAN AS
$$
UPDATE user_data
SET is_chat_mod = NOT is_chat_mod
WHERE user_uuid = toggle_is_user_chat_mod_return_result.user_uuid
RETURNING is_chat_mod
$$
    LANGUAGE sql;