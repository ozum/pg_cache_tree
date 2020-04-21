/*
 * Author: Özüm Eldoğan
 * Created at: 2020-04-20 15:35:03 +0300
 *
 */

SET client_min_messages = warning;




--
-- ─── FUNCTIONS ──────────────────────────────────────────────────────────────────
--

CREATE OR REPLACE FUNCTION ct_assign (
  target pg_catalog.anyelement,
  key text,
  value text
)
RETURNS pg_catalog.anyelement AS
$body$
-- Undocumented PostgreSQL Feature, maybe need to use other methods here:
-- https://stackoverflow.com/questions/7711432/how-to-set-value-of-composite-variable-field-using-dynamic-sql/7782641#7782641
SELECT json_populate_record(target, ('{"'||key||'":"'||value||'"}')::json);
$body$
LANGUAGE 'sql'
IMMUTABLE
CALLED ON NULL INPUT
-- SECURITY INVOKER
LEAKPROOF
PARALLEL SAFE
COST 100;

COMMENT ON FUNCTION ct_assign(target pg_catalog.anyelement, key text, value text)
IS '(target anyelement, key text, value text)

SEE: https://stackoverflow.com/questions/7711432/how-to-set-value-of-composite-variable-field-using-dynamic-sql/7782641#7782641
(Undocumented PostgreSQL Feature, maybe need to use other methods from URL)

Assigns given value into target''s given key/column. Value must be text, but it will be converted target''s correct type.

Maybe useful to assign values to dynamic columns. (Column name stored in variable.)

Example:

-- Assign dynamic column ''id'')
column_name := ''id'';
some_row := ct_assign(some_row, column_name, 99::TEXT); -- some_row.id := 99

-- Copy id of OLD into NEW. NEW.id = OLD.id
column_name := ''id'';
EXECUTE format(''SELECT $1.%I::TEXT'', column_name) INTO old_id USING OLD;
NEW := ct_assign(NEW, column_name, old_id);

';

CREATE OR REPLACE FUNCTION ct_copy_value (
  source pg_catalog.anyelement,
  inout target pg_catalog.anyelement,
  key text
)
RETURNS pg_catalog.anyelement AS
$body$
DECLARE
  new_value TEXT;
BEGIN
  EXECUTE format('SELECT $1.%I::TEXT', key) INTO new_value USING source;
  target := ct_assign(target, key, new_value);
END;
$body$
LANGUAGE 'plpgsql'
IMMUTABLE
CALLED ON NULL INPUT
-- SECURITY INVOKER
LEAKPROOF
PARALLEL SAFE
COST 100;

COMMENT ON FUNCTION ct_copy_value(source pg_catalog.anyelement, inout target pg_catalog.anyelement, key text)
IS '(source anyelement, target anyelement, key text)

Copies value from dynamic column name of source row into target row and returns new row.

Example:

column_name := ''id'';
target_row := ct_copy_value(source_row, target_row, column_name); -- target_row.id = source_row.id
NEW := ct_copy_value(OLD, NEW, column_name); -- NEW.id = OLD.id';

CREATE OR REPLACE FUNCTION ct_create_trigger (
  table_name pg_catalog.regclass,
  id text = 'id'::text,
  parent text = 'parentId'::text,
  parents text = 'parentsCache'::text,
  children text = 'childrenCache'::text
)
RETURNS void AS
$body$
DECLARE
    insert_delete_trigger TEXT := parent || '_insert_delete_trigger';
    update_trigger TEXT := parent || '_update_trigger';
    args JSONB := format('{"id": "%s", "parent": "%s", "parents": "%s", "children": "%s"}', id, parent, parents, children);
BEGIN
	PERFORM ct_drop_trigger(table_name, parent => parent);

	EXECUTE format('CREATE TRIGGER %1$I AFTER INSERT OR DELETE ON %2$s FOR EACH ROW EXECUTE PROCEDURE ct_trigger_update_cache(''%3$s'');',
    	insert_delete_trigger, table_name, args);

    EXECUTE format('
        CREATE TRIGGER %1$I AFTER UPDATE OF %2$I, %3$I ON %4$s
		FOR EACH ROW WHEN (OLD.%2$I IS DISTINCT FROM NEW.%2$I OR OLD.%3$I IS DISTINCT FROM NEW.%3$I)
  			EXECUTE PROCEDURE ct_trigger_update_cache(''%5$s'');
	', update_trigger, args->>'id', args->>'parent', table_name, args);
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
-- SECURITY INVOKER
PARALLEL UNSAFE
COST 100;

COMMENT ON FUNCTION ct_create_trigger(table_name pg_catalog.regclass, id text, parent text, parents text, children text)
IS 'Creates related triggers for given table. See "ct_trigger_update_cache" for arguments and requirements.

Example:
SELECT ct_create_trigger(''other_schema."Account"'', id => ''id'', parent => ''parentId'');';

CREATE OR REPLACE FUNCTION ct_drop_trigger (
  table_name pg_catalog.regclass,
  parent text = 'parentId'::text
)
RETURNS void AS
$body$
DECLARE
    insert_delete_trigger TEXT := parent || '_insert_delete_trigger';
    update_trigger TEXT := parent || '_update_trigger';
BEGIN
	EXECUTE format('DROP TRIGGER IF EXISTS %I ON %s', insert_delete_trigger, table_name);
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %s', update_trigger, table_name);
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
-- SECURITY INVOKER
PARALLEL UNSAFE
COST 100;

COMMENT ON FUNCTION ct_drop_trigger(table_name pg_catalog.regclass, parent text)
IS 'Drops related triggers from given table created by "ct_create_trigger()".
Example:
SELECT ct_drop_trigger(''other_schema."Account"'', parent => ''parentId'');';


CREATE OR REPLACE FUNCTION ct_insert_array (
  source pg_catalog.anyarray,
  after_element pg_catalog.anyelement,
  new_elements pg_catalog.anyarray
)
RETURNS pg_catalog.anyarray AS
$body$
DECLARE
  pos integer DEFAULT array_position(source, after_element); -- Position of element in array.
BEGIN
  IF pos IS NULL OR pos = 0 THEN
    RETURN new_elements || source;
  END IF;
  RETURN source[1:pos] || new_elements || source[pos + 1:];
END;
$body$
LANGUAGE 'plpgsql'
IMMUTABLE
CALLED ON NULL INPUT
-- SECURITY INVOKER
LEAKPROOF
PARALLEL SAFE
COST 100;

COMMENT ON FUNCTION ct_insert_array(source pg_catalog.anyarray, after_element pg_catalog.anyelement, new_elements pg_catalog.anyarray)
IS '(source anyarray, after_element anyelement, new_elements anyarray)

Creates a new array by inserting `new elements` array into `source` array after position of `after_element` element. Useful for
depth first arrays.

Used by `ct_trigger_update_cache` trigger function.';


CREATE OR REPLACE FUNCTION ct_insert_array (
  source pg_catalog.anyarray,
  after_element pg_catalog.anyelement,
  new_element pg_catalog.anyelement
)
RETURNS pg_catalog.anyelement AS
$body$
BEGIN
  RETURN extra_modules.t_cpc_insert_array (source, after_element, ARRAY[new_element]);
END;
$body$
LANGUAGE 'plpgsql'
IMMUTABLE
CALLED ON NULL INPUT
-- SECURITY INVOKER
LEAKPROOF
PARALLEL SAFE
COST 100;

COMMENT ON FUNCTION ct_insert_array(source pg_catalog.anyarray, after_element pg_catalog.anyelement, new_element pg_catalog.anyelement)
IS '(source anyarray, after_element anyelement, new_element anyelement)

Creates a new array by inserting `new element` into `source` array after position of `after_element` element. Useful for
depth first arrays.

Used by `ct_trigger_update_cache` trigger function.';


CREATE OR REPLACE FUNCTION ct_subtract_array (
  inout lv pg_catalog.anyarray,
  rv pg_catalog.anyarray
)
RETURNS pg_catalog.anyarray AS
$body$
BEGIN
  FOR i IN 1..array_upper(rv, 1)
  LOOP
    lv := array_remove(lv, rv[i]);
  END LOOP;
END;
$body$
LANGUAGE 'plpgsql'
IMMUTABLE
CALLED ON NULL INPUT
-- SECURITY INVOKER
LEAKPROOF
PARALLEL SAFE
COST 100;

COMMENT ON FUNCTION ct_subtract_array(inout lv pg_catalog.anyarray, rv pg_catalog.anyarray)
IS '(lv anyarray, rv anyarray)

Deletes every element in `rv` array from `lv` array. (Returns lv - rv).

Used by `-#` operator (i.e. `array_a -# array_b`).';


CREATE OR REPLACE FUNCTION ct_trigger_update_cache (
)
RETURNS trigger AS
$body$
DECLARE
	args JSONB 					:= TG_ARGV[0]::JSONB;
    id_column TEXT 				:= COALESCE(args->>'id', 'id');
    parent_column TEXT 			:= COALESCE(args->>'parent', 'parentId');
    children_column TEXT 		:= COALESCE(args->>'children', 'childrenCache');
    parents_column TEXT 		:= COALESCE(args->>'parents', 'parentsCache');
    table_name  TEXT     		:= format('%I.%I', TG_TABLE_SCHEMA, TG_TABLE_NAME);
    is_id_update BOOLEAN;
    parent_changed BOOLEAN;
    old_parent_is_null BOOLEAN;
    new_parent_is_null BOOLEAN;
    id_changed BOOLEAN;
    new_parents_as_text TEXT;
BEGIN

	--    SET LOCAL search_path TO extra_modules, public;
	IF (TG_OP IN ('DELETE', 'UPDATE')) THEN
    	EXECUTE format('SELECT $1.%I IS NULL', parent_column) INTO old_parent_is_null USING OLD; -- OLD.parent_id IS NULL
    END IF;

    IF (TG_OP = 'UPDATE') THEN
    	EXECUTE format('SELECT $1.%1$I <> $2.%1$I', id_column) INTO id_changed USING OLD, NEW; -- OLD.id = NEW.id
    	EXECUTE format('SELECT $1.%1$I IS DISTINCT FROM $2.%1$I', parent_column) INTO parent_changed USING OLD, NEW; -- OLD.parent_id IS DISTINCT FROM NEW.parent_id
    END IF;

    IF (TG_OP IN ('INSERT', 'UPDATE')) THEN
        EXECUTE format('SELECT $1.%I IS NULL', parent_column) INTO new_parent_is_null USING NEW; -- OLD.parent_id IS NULL
    END IF;



    IF (TG_OP = 'UPDATE') THEN
        IF (NOT id_changed AND NOT parent_changed) THEN RETURN NEW; END IF;

        IF id_changed THEN
            -- REPLACE OLD ID WITH NEW IN PARENTS AND CHILDREN
            -- UPDATE table SET "childrenRecursive" = array_replace("childrenRecursive", OLD.id, NEW.id) WHERE id = ANY(OLD."parentsRecursive")
            EXECUTE format('UPDATE %s SET %2$I = array_replace(%2$I, $1.%3$I, $2.%3$I) WHERE %3$I = ANY($1.%4$I)', table_name, children_column, id_column, parents_column) USING OLD, NEW;

            -- UPDATE table SET "parentsRecursive" = array_replace("parentsRecursive", OLD.id, NEW.id) WHERE id = ANY(OLD."childrenRecursive")
            EXECUTE format('UPDATE %s SET %2$I = array_replace(%2$I, $1.%3$I, $2.%3$I) WHERE id = ANY($1.%4$I)', table_name, parents_column, id_column, children_column) USING OLD, NEW;

            IF NOT parent_changed THEN RETURN NEW; END IF;

            -- If we are here, parent id and id are changed at the same time. Since old id is no more in table refer it with new id.
            -- Undocumented PostgreSQL Feature, maybe need to use other methods here: https://stackoverflow.com/questions/7711432/how-to-set-value-of-composite-variable-field-using-dynamic-sql/28673097#28673097
            OLD := ct_copy_value(NEW, OLD, id_column); -- OLD.id := NEW.id
        END IF;

        IF (parent_changed AND NOT old_parent_is_null) THEN
            -- If parentId change is is cascaded from id update, old id is not there, because it is updated to new id.
            EXECUTE format('SELECT count(*) = 0 FROM %s WHERE %I = $1.%I', table_name, id_column, parent_column) INTO is_id_update USING OLD; -- SELECT count(*) = 0 FROM table WHERE id = OLD.parentId
            IF (is_id_update) THEN
                RETURN NEW;
            END IF;
        END IF;
    END IF;

    IF TG_OP IN ('DELETE', 'UPDATE') THEN
    	-- CACHE CHILDREN
    	IF (NOT old_parent_is_null) THEN
        	EXECUTE format('UPDATE %s SET %2$I = %2$I -# ($1.%3$I || $1.%2$I) WHERE %3$I = ANY($1.%4$I)', table_name, children_column, id_column, parents_column) USING OLD; -- UPDATE table SET "childrenRecursive" = "childrenRecursive" -# (OLD.id || OLD."childrenRecursive") WHERE id = ANY(OLD."parentsRecursive")
    	END IF;

    	-- CACHE PARENTS
        EXECUTE format('UPDATE %s SET %2$I = %2$I -# ($1.%3$I || $1.%2$I) WHERE %3$I = ANY($1.%3$I || $1.%4$I)', table_name, parents_column, id_column, children_column) USING OLD; -- UPDATE table SET "parentsRecursive" = "parentsRecursive" -# (OLD.id || OLD."parentsRecursive") WHERE id = ANY(OLD.id || OLD."childrenRecursive")
    END IF;

    IF TG_OP IN ('INSERT', 'UPDATE') THEN
		EXECUTE format('SELECT (%1$I || %2$I)::TEXT FROM %3$s WHERE %2$I = $1.%4$I', parents_column, id_column, table_name, parent_column) INTO new_parents_as_text USING NEW;  -- SELECT "parentsRecursive" || id FROM table WHERE id = NEW."parentId"
		NEW := ct_assign(NEW, parents_column, new_parents_as_text);

        IF NEW."parentId" IS NOT NULL THEN
            -- CACHE CHILDREN
            EXECUTE format('
                UPDATE %s
                SET %2$I = ct_insert_array(%2$I, $1.%3$I, $1.%4$I || $1.%2$I)
                WHERE %4$I = ANY($1.%5$I)
            ', table_name, children_column, parent_column, id_column, parents_column) USING NEW; -- UPDATE table SET "childrenRecursive" = ct_insert_array("childrenRecursive", NEW."parentId", NEW.id || NEW."childrenRecursive") WHERE id = ANY(NEW."parentsRecursive")
        END IF;

        -- CACHE PARENTS
        EXECUTE format('UPDATE %s SET %2$I = array_remove(%2$I || $1.%3$I || $1.%2$I, %3$I) WHERE %3$I = ANY($1.%3$I || $1.%4$I)', table_name, parents_column, id_column, children_column) USING NEW; -- UPDATE table SET "parentsRecursive" = array_remove("parentsRecursive" || NEW.id || NEW."parentsRecursive", id) WHERE id = ANY(NEW.id || NEW."childrenRecursive")
    END IF;
    RETURN NULL;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
-- SECURITY INVOKER
PARALLEL UNSAFE
COST 100;

COMMENT ON FUNCTION ct_trigger_update_cache()
IS '({ "id": "id", "parent": "parentId", "children": "childrenRecursive", "parents": "parentsRecursive"} JSONB)

Trigger function to be used after for each row. Keeps cache of parents and children of the record in tree structure.

Column names are configurable.

Required fields are (using default column names): `id`, `parentId`, `parentsRecursive` (array), `childrenRecursive` (array).

TRIGGER:
After for each row
INSERT
UPDATE ("id", "parentId")
DELETE';


--
-- ─── OPERATORS ──────────────────────────────────────────────────────────────────
--

CREATE OPERATOR -# ( PROCEDURE = ct_subtract_array,
LEFTARG = anyarray, RIGHTARG = anyarray);
