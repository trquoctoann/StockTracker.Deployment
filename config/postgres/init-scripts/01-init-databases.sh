set -euo pipefail

echo "==> Creating Keycloak database and user..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create Keycloak user (if not same as default postgres user)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${KEYCLOAK_DB_USER}') THEN
            CREATE ROLE "${KEYCLOAK_DB_USER}" WITH LOGIN PASSWORD '${KEYCLOAK_DB_PASSWORD}';
        END IF;
    END
    \$\$;

    -- Create Keycloak database
    SELECT 'CREATE DATABASE "${KEYCLOAK_DB_NAME}" OWNER "${KEYCLOAK_DB_USER}"'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${KEYCLOAK_DB_NAME}')\gexec

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE "${KEYCLOAK_DB_NAME}" TO "${KEYCLOAK_DB_USER}";
EOSQL

echo "==> Keycloak database '${KEYCLOAK_DB_NAME}' created successfully."
echo "==> All databases initialized."
