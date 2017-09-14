CREATE TABLE auth_roles
(
    role_id SERIAL PRIMARY KEY NOT NULL,
    name VARCHAR(250) DEFAULT NULL::character varying,
    description TEXT,
    permissions TEXT,
    is_active SMALLINT DEFAULT 1 NOT NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE auth_roles_to_users
(
    user_id INTEGER,
    role_id INTEGER,
    created_at TIMESTAMP,
    CONSTRAINT auth_roles_to_users_pkey PRIMARY KEY (user_id, role_id)
);

CREATE TABLE auth_users
(
    user_id SERIAL PRIMARY KEY NOT NULL,
    login VARCHAR(250) NOT NULL,
    password_hash VARCHAR(250) DEFAULT NULL::character varying,
    secure_token VARCHAR(250) DEFAULT NULL::character varying,
    is_admin SMALLINT DEFAULT 0 NOT NULL,
    is_active SMALLINT DEFAULT 1 NOT NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
CREATE UNIQUE INDEX auth_users_login_uindex ON auth_users (login);
