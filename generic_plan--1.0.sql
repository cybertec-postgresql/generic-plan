CREATE FUNCTION generic_plan(
   query text,
   verbose boolean DEFAULT FALSE,
   costs boolean DEFAULT TRUE,
   settings boolean DEFAULT FALSE,
   format text DEFAULT 'TEXT'
) RETURNS table (plan text)
   LANGUAGE plpgsql
   VOLATILE
   RETURNS NULL ON NULL INPUT
   SECURITY INVOKER
   PARALLEL SAFE
   ROWS 30
   SET plan_cache_mode = force_generic_plan
AS
$$DECLARE
   arg_count integer;
   open_paren text;
   close_paren text;
   explain_cmd text;
   json_result json;
   xml_result xml;
   yaml_result text;
BEGIN
   /* check the "format" argument */
   IF NOT pg_catalog.upper(generic_plan.format) IN ('TEXT', 'XML', 'JSON', 'YAML') THEN
      RAISE EXCEPTION 'incorrect EXPLAIN format %', generic.plan_format
         USING HINT = 'Supported formats are: TEXT, XML, JSON, YAML';
   END IF;

   /* reject statements containing a semicolon in the middle */
   IF pg_catalog.strpos(
         pg_catalog.rtrim(generic_plan.query, ';'),
         ';'
      ) OPERATOR(pg_catalog.>) 0 THEN
      RAISE EXCEPTION 'query string must not contain a semicolon';
   END IF;

   /* get the parameter count */
   SELECT count(*) INTO arg_count
   FROM pg_catalog.regexp_matches( /* extract the "$n" */
           pg_catalog.regexp_replace( /* remove single quoted strings */
              generic_plan.query,
              '''[^'']*''',
              '',
              'g'
           ),
           '\$\d{1,}',
           'g'
        );

   IF arg_count OPERATOR(pg_catalog.=) 0 THEN
      open_paren := '';
      close_paren := '';
   ELSE
      open_paren := '(';
      close_paren := ')';
   END IF;

   /* construct a prepared statement */
   EXECUTE
      pg_catalog.concat(
         'PREPARE _stmt_',
         open_paren,
         pg_catalog.rtrim(
            pg_catalog.repeat('unknown,', arg_count),
            ','
         ),
         close_paren,
         ' AS ',
         generic_plan.query
      );

   /* construct an EXPLAIN statement */
   explain_cmd :=
      pg_catalog.concat(
         'EXPLAIN (FORMAT ',
         generic_plan.format,
         CASE WHEN generic_plan.verbose THEN ', VERBOSE' ELSE '' END,
         CASE WHEN generic_plan.costs THEN '' ELSE ', COSTS OFF' END,
         CASE WHEN generic_plan.settings THEN ', SETTINGS' ELSE '' END,
         ') EXECUTE _stmt_',
         open_paren,
         pg_catalog.rtrim(
            pg_catalog.repeat('NULL,', arg_count),
            ','
         ),
         close_paren
      );

   /* get and return the plan */
   CASE pg_catalog.upper(generic_plan.format)
      WHEN 'JSON' THEN
         EXECUTE explain_cmd INTO json_result;

         RETURN QUERY
            SELECT * FROM pg_catalog.regexp_split_to_table(json_result::text, E'\n');
      WHEN 'XML' THEN
         EXECUTE explain_cmd INTO xml_result;

         RETURN QUERY
            SELECT * FROM pg_catalog.regexp_split_to_table(xml_result::text, E'\n');
      WHEN 'YAML' THEN
         EXECUTE explain_cmd INTO yaml_result;

         RETURN QUERY
            SELECT * FROM pg_catalog.regexp_split_to_table(yaml_result, E'\n');
      ELSE
         RETURN QUERY EXECUTE explain_cmd;
   END CASE;

   /* delete the prepared statement */
   DEALLOCATE _stmt_;
END;$$;
