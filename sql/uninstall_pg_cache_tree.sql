/*
 * Author: Özüm Eldoğan
 * Created at: 2016-12-20 15:35:03 +0300
 *
 */


SET client_min_messages = warning;

BEGIN;

DROP OPERATOR IF EXISTS -# (anyarray, anyarray);

DROP FUNCTION IF EXISTS ct_assign(target pg_catalog.anyelement, key text, value text);
DROP FUNCTION IF EXISTS ct_copy_value(source pg_catalog.anyelement, inout target pg_catalog.anyelement, key text);
DROP FUNCTION IF EXISTS ct_create_trigger(table_name pg_catalog.regclass, id text, parent text, parents text, children text);
DROP FUNCTION IF EXISTS ct_drop_trigger(table_name pg_catalog.regclass, parent text);
DROP FUNCTION IF EXISTS ct_insert_array(source pg_catalog.anyarray, after_element pg_catalog.anyelement, new_elements pg_catalog.anyarray);
DROP FUNCTION IF EXISTS ct_insert_array(source pg_catalog.anyarray, after_element pg_catalog.anyelement, new_element pg_catalog.anyelement);
DROP FUNCTION IF EXISTS ct_subtract_array(inout lv pg_catalog.anyarray, rv pg_catalog.anyarray);
DROP FUNCTION IF EXISTS ct_trigger_update_cache();

COMMIT;
