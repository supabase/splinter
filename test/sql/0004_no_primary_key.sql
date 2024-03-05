begin;

	-- No issues	
	select * from lint."0004_no_primary_key";

	-- Table with a primary key
    create table public.foo (
        id int primary key
    );

	-- Table with a primary key
    create table public.bar (
        id int
    );

    -- Only the "bar" table is listed
	select * from lint."0004_no_primary_key";

rollback;
