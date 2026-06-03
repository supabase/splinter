create view lint."0025_pg17_deprecated_extensions" as

select
    'pg17_deprecated_extensions' as name,
    'PG17 Deprecated Extensions' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects extensions that are deprecated in PostgreSQL 17 images.' as description,
    format(
    'Extension `%s` is deprecated in PostgreSQL 17 images. Consider removing or replacing it before upgrading.',
    pe.extname
) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0025_pg17_deprecated_extensions' as remediation,
    jsonb_build_object(
    'extension_name', pe.extname
) as metadata,
    format(
    'pg17_deprecated_extension_%s',
    pe.extname
) as cache_key
from
    pg_catalog.pg_extension pe
where
    pe.extname in (
        'plv8',
        'timescaledb',
        'adminpack'
    );
