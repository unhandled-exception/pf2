CREATE TABLE antiflood
(
    id BIGSERIAL PRIMARY KEY NOT NULL,
    salt CHAR(16) NOT NULL,
    created_at TIMESTAMP DEFAULT now() NOT NULL,
    processed_at TIMESTAMP
);
CREATE INDEX antiflood__created_at_index ON antiflood (created_at);

CREATE EXTENSION IF NOT EXISTS pgcrypto;
