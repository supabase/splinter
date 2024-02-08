ARG SUPABASE_VERSION=15.1.1.13
FROM supabase/postgres:${SUPABASE_VERSION}

WORKDIR /home/splinter

RUN chown postgres:postgres /home/splinter

COPY . .

USER postgres

