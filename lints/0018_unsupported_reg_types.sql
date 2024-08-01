CREATE VIEW lint."unsupported_reg_types" AS
SELECT
    'unsupported_reg_types' AS name,
    'Unsupported reg* types' AS title,
    'WARN' AS level,
    'EXTERNAL' AS facing,
    ARRAY['CATEGORY'] AS categories,
    'Identifies columns using unsupported reg* types outside pg_catalog schema, which prevents database upgrades using pg_upgrade.' AS description,
    FORMAT(
        'Table `%s.%s` has a column `%s` with unsupported reg* type `%s`.',
        n.nspname, c.relname, a.attname, t.typname
    ) AS detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=unsupported_reg_types' AS remediation,
    jsonb_build_object(
        'schema', n.nspname,
        'table', c.relname,
        'column', a.attname,
        'type', t.typname
    ) AS metadata,
    FORMAT('unsupported_reg_types_%s_%s_%s', n.nspname, c.relname, a.attname) AS cache_key
FROM
    pg_catalog.pg_attribute a
    JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    JOIN pg_catalog.pg_type t ON a.tttypid = t.oid
WHERE
    t.typname IN ('regcollation', 'regconfig', 'regdictionary', 'regnamespace', 'regoper', 'regoperator', 'regproc', 'regprocedure')
    AND n.nspname NOT IN ('pg_catalog', 'information_schema');