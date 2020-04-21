# pg_cache_tree

## Abstract

PostgreSQL trigger to cache recursive parents and children of a record in an array field.

## Description

This is a PostgreSQL extension which adds a trigger, and related support and utility functions to store and update recursive parent-child list.

## Synopsis

On CLI:

    $ make install

### Create Extension and Example Table

```SQL
CREATE EXTENSION pg_cache_tree;

CREATE TABLE "BusinessUnit" (
  id INTEGER NOT NULL,
  "parentId" INTEGER,
  "parentsCache" INTEGER [] DEFAULT '{}'::integer[] NOT NULL,
  "childrenCache" INTEGER [] DEFAULT '{}'::integer[] NOT NULL,
  CONSTRAINT "BusinessUnit_PK" PRIMARY KEY(id),
  CONSTRAINT "BusinessUnit_Parent_FK" FOREIGN KEY ("parentId")
    REFERENCES "BusinessUnit"(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);
```

### Option A: Add Single Trigger

```SQL
-- Showign with default values
CREATE TRIGGER "parentId_trigger" AFTER INSERT OR DELETE OR UPDATE OF "id", "parentId" ON "BusinessUnit"
  FOR EACH ROW EXECUTE PROCEDURE ct_trigger_update_cache('{"id": "id", "parent": "parentId", "parents": "parentsCache", "children": "childrenCache"}');
```

### Option B: Add Two Triggers

```SQL
-- Showign with default values
CREATE TRIGGER "parentId_insert_delete_trigger" AFTER INSERT OR DELETE ON "BusinessUnit"
  FOR EACH ROW EXECUTE PROCEDURE
    ct_trigger_update_cache('{"id": "id", "parent": "parentId", "parents": "parentsCache", "children": "childrenCache"}');

CREATE TRIGGER "parentId_update_trigger" AFTER UPDATE OF "id", "parentId" ON "BusinessUnit"
  FOR EACH ROW WHEN (old.id IS DISTINCT FROM new.id OR old."parentId" IS DISTINCT FROM new."parentId") EXECUTE PROCEDURE
    ct_trigger_update_cache('{"id": "id", "parent": "parentId", "parents": "parentsCache", "children": "childrenCache"}');
```

### Option C: Add Two Triggers Using `ct_create_trigger()`

```SQL
-- Showign with default values
SELECT ct_create_trigger('public."BusinessUnit"', id => 'id', parent => 'parentId', parents => 'parentsCache', children => 'childrenCache');
```

```SQL
-- Insert some values. Triggers update parents and children cache.
INSERT INTO "BusinessUnit" ("id", "parentId") VALUES
  (1, NULL),
  (2, 1),
  (20, 2),
  (21, 2);

SELECT * FROM "BusinessUnit";
```

| id  | parentId | parentsCache | childrenCache |
| --- | -------- | ------------ | ------------- |
| 1   | null     | {}           | {2,21,20}     |
| 2   | 1        | {1}          | {21,20}       |
| 20  | 2        | {1,2}        | {}            |
| 21  | 2        | {1,2}        | {}            |

## What is included?

- `ct_trigger_update_cache()` trigger function
- `ct_create_trigger()`, `ct_drop_trigger()` utility functions
- Support functions and operators

## Install

To build it, just do this:

    make
    make installcheck
    make install

If you encounter an error such as:

    "Makefile", line 8: Need an operator

You need to use GNU make, which may well be installed on your system as
`gmake`:

    gmake
    gmake install
    gmake installcheck

If you encounter an error such as:

    make: pg_config: Command not found

Be sure that you have `pg_config` installed and in your path. If you used a
package management system such as RPM to install PostgreSQL, be sure that the
`-devel` package is also installed. If necessary tell the build process where
to find it:

    env PG_CONFIG=/path/to/pg_config make && make installcheck && make install

And finally, if all that fails (and if you're on PostgreSQL 8.1 or lower, it
likely will), copy the entire distribution directory to the `contrib/`
subdirectory of the PostgreSQL source tree and try it there without
`pg_config`:

    env NO_PGXS=1 make && make installcheck && make install

If you encounter an error such as:

    ERROR:  must be owner of database regression

You need to run the test suite using a super user, such as the default
"postgres" super user:

    make installcheck PGUSER=postgres

Once pg_cache_tree is installed, you can add it to a database. If you're running
PostgreSQL 9.1.0 or greater, it's a simple as connecting to a database as a
super user and running:

    CREATE EXTENSION pg_cache_tree;

If you've upgraded your cluster to PostgreSQL 9.1 and already had pg_cache_tree
installed, you can upgrade it to a properly packaged extension with:

    CREATE EXTENSION pg_cache_tree FROM unpackaged;

For versions of PostgreSQL less than 9.1.0, you'll need to run the
installation script:

    psql -d mydb -f /path/to/pgsql/share/contrib/pg_cache_tree.sql

If you want to install pg_cache_tree and all of its supporting objects into a specific
schema, use the `PGOPTIONS` environment variable to specify the schema, like
so:

    PGOPTIONS=--search_path=extensions psql -d mydb -f pg_cache_tree.sql

## Dependencies

No dependencies.

## Copyright and License

See LICENSE file. Copyright (c) 2016 Özüm Eldoğan.
