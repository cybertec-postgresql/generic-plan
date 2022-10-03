EXTENSION = generic_plan
DATA = generic_plan--1.0.sql
DOCS = README.generic_plan

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
