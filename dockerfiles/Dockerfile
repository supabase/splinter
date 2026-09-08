ARG SUPABASE_VERSION=15.14.1.169
FROM supabase/postgres:${SUPABASE_VERSION}

WORKDIR /home/splinter

RUN chown postgres:postgres /home/splinter

COPY . .

USER postgres

