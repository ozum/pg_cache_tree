pg_cache_tree
====================

Abstract
--------

PostgreSQL trigger to cache recursive parents and children of a record in an array field.

Synopsis
--------

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

Description
-----------

This is a PostgreSQL extension which adds a trigger, and related support and utility functions to store and update recursive parent-child list.

Support
-------

[https://github.com/ozum/pg_cache_tree/issues](GitHub Issues)

Author
------

[https://github.com/ozum](Özüm Eldoğan)

Copyright and License
---------------------

Copyright (c) 2016 Özüm Eldoğan.

