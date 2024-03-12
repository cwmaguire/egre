PROJECT = egre
COMPILE_FIRST = egre_object egre_handler
DEPS = jsx

## copied from erlang.mk and added +native.
## It made one of the test faster when this was part of GERLSHMUD
ERLC_OPTS = -Werror \
						+debug_info \
						+warn_export_vars \
						+warn_shadow_vars \
						+warn_obsolete_guard
						#+'{parse_transform, gerlshmud_log_transform}'
						#+native ##\

## copied from erlang.mk
TEST_ERLC_OPTS = +debug_info \
								 +warn_export_vars \
                 +warn_shadow_vars \
								 +warn_obsolete_guard
								 #+'{parse_transform, gerlshmud_log_transform}'

include erlang.mk
