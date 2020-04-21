\set ECHO none
BEGIN;
\i sql/pg_cache_tree.sql

CREATE SCHEMA other;

CREATE TABLE other."Account" (
  id INTEGER,
  "parentId" INTEGER,
  "parentsCache" INTEGER [] DEFAULT '{}'::integer[] NOT NULL,
  "childrenCache" INTEGER [] DEFAULT '{}'::integer[] NOT NULL,
  CONSTRAINT account_pkey PRIMARY KEY(id)
);

SELECT ct_create_trigger('other."Account"');

INSERT INTO other."Account" (id, "parentId") VALUES
(1, null),
(2, null),
(3, null),
(10, 1),
(100, 10),
(101, 10),
(20, 2),
(21, 2),
(200, 20),
(201, 20),
(210, 21)
;

UPDATE other."Account" SET "parentId" = 21 WHERE id = 200;
UPDATE other."Account" SET id = 25, "parentId" = 21 WHERE id = 201;

DELETE FROM other."Account" WHERE id = 210;

\set ECHO all

SELECT * FROM other."Account" ORDER BY id;

ROLLBACK;
