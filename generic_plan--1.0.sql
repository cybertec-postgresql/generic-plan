CREATE FUNCTION generic_plan(
   query text,
   verbose boolean DEFAULT FALSE
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
BEGIN
   /* reject statements containing a semicolon in the middle */
   IF pg_catalog.strpos(
         pg_catalog.rtrim(generic_plan.query, ';'),
         ';'
      ) > 0 THEN
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

   /* get the generic plan */
   RETURN QUERY EXECUTE
      pg_catalog.concat(
         'EXPLAIN ',
         CASE WHEN generic_plan.verbose THEN '(VERBOSE) ' ELSE '' END,
         'EXECUTE _stmt_',
         open_paren,
         pg_catalog.rtrim(
            pg_catalog.repeat('NULL,', arg_count),
            ','
         ),
         close_paren
      );

   /* delete the prepared statement */
   DEALLOCATE _stmt_;
END;$$;
