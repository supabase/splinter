select * from lint."0001_unindexed_foreign_keys"
union all
select * from lint."0002_auth_users_exposed"
union all
select * from lint."0003_auth_rls_initplan"
union all
select * from lint."0004_no_primary_key"
union all
select * from lint."0005_unused_index"
union all
select * from lint."0006_multiple_permissive_policies"
union all
select * from lint."0007_policy_exists_rls_disabled"
union all
select * from lint."0008_rls_enabled_no_policy"
union all
select * from lint."0009_duplicate_index"
union all
select * from lint."0010_security_definer_view"
union all
select * from lint."0011_function_search_path_mutable"
union all
select * from lint."0013_rls_disabled_in_public"
union all
select * from lint."0014_extension_in_public";