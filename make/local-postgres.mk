.PHONY: check-extra-schema-to-drop

check-extra-schema-to-drop:
	@[ "${schema_to_drop}" ] || ( echo ">> schema_to_drop is not set"; exit 1 )

stop-local-postgres:
	docker stop local-postgres >> /dev/null 2>&1 | true && \
	docker rm --force local-postgres >> /dev/null 2>&1 | true && \
	rm -rf /tmp/local-postgres-data >> /dev/null 2>&1 | true

flush-and-migrate: check-extra-schema-to-drop
	export PGPASSWORD=postgres && \
	psql -d postgres -h localhost -p 5432 -U postgres -c "DROP SCHEMA public CASCADE;CREATE SCHEMA public;DROP SCHEMA ${schema_to_drop} CASCADE;"

local-postgres: stop-local-postgres
	docker run -d --rm --name local-postgres \
        -e POSTGRES_PASSWORD=postgres \
        -v /tmp/local-postgres-data/:/var/lib/postgresql/data \
        -p 5432:5432 postgres && \
	echo "Local postgres started on port 5432 - user: postgres, password: postgres"
