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