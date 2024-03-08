begin;

    -- No issues
    select * from lint."0002_auth_users_exposed";

    -- Create a view that exposes auth.users
    create view public.oops as
    select * from auth.users;

    select * from lint."0002_auth_users_exposed";

rollback;
