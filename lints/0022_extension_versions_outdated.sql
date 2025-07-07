create view lint."0022_extension_versions_outdated" as

select
    'extension_versions_outdated' as name,
    'Extension Versions Outdated' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects extensions that are not using the default (recommended) version.' as description,
    format(
        'Extension `%s` is using version `%s` but version `%s` is available. Using outdated extension versions may expose the database to security vulnerabilities.',
        ext.name,
        ext.installed_version,
        ext.default_version
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0022_extension_versions_outdated' as remediation,
    jsonb_build_object(
        'extension_name', ext.name,
        'installed_version', ext.installed_version,
        'default_version', ext.default_version
    ) as metadata,
    format(
        'extension_versions_outdated_%s_%s',
        ext.name,
        ext.installed_version
    ) as cache_key
from
    pg_catalog.pg_available_extensions ext
where
    ext.installed_version is not null
    and ext.default_version is not null
    and ext.installed_version != ext.default_version
order by
    ext.name;