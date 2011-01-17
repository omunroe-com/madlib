# Generate developer documentation
devdoc: doc/bin/sql_filter mathjax
	doxygen doc/etc/developer.doxyfile

# Generate user documentation
doc: doc/bin/sql_filter mathjax
	doxygen doc/etc/user.doxyfile

# sql_filter for converting .sql files to a file with C++ declarations, for
# use with doxygen
doc/bin/sql_filter: doc/etc/sql.parser.cc doc/etc/sql.scanner.cc
	g++ -o $@ $(filter %.cc,$^)
	rm doc/etc/location.hh doc/etc/position.hh doc/etc/stack.hh

#BISON_FLAGS = -v --debug
#FLEX_FLAGS = -d

%.parser.cc %.parser.hh: %.yy Makefile
	bison ${BISON_FLAGS} -o $(@:.hh=.cc) $<

# Empty recipe. Note: If ";" was missing, the following would cancel implicit rules
# (see 10.5.6 in the make manual)
# %.parser.hh: %.parser.cc ;

%.scanner.cc: %.ll %.parser.hh Makefile
	flex ${FLEX_FLAGS} $< > $@

.INTERMEDIATE: doc/etc/sql.parser.cc doc/etc/sql.parser.hh doc/etc/sql.scanner.cc

# MathJax is used by doxygen to display formulas in HTML
MATHJAX_DIR = doc/var/mathjax
MATHJAX_LAST_UPDATE = ${MATHJAX_DIR}/.last_update
MATHJAX_UPDATE_INTERVAL = 7

# If the modification date of ${MATHJAX_LAST_UPDATE} is less than
# ${MATHJAX_UPDATE_INTERVAL} days, we will update MathJax.
MATHJAX_NEEDS_UPDATE ?= $(shell \
	if [[ -f ${MATHJAX_LAST_UPDATE} && \
		  $$(( $$(date "+%s") \
		- $$(perl -e 'printf "%u", (stat shift)[9]' ${MATHJAX_LAST_UPDATE}) )) \
		-lt $$(( ${MATHJAX_UPDATE_INTERVAL} * 24 * 60 * 60 )) ]]; \
	then \
		echo 0; \
	else \
		echo 1; \
	fi)

# Update the mathjax installation, which is used by doxygen
# See http://www.mathjax.org/resources/docs/?installation.html
mathjax:
ifneq (${MATHJAX_NEEDS_UPDATE},0)
	@echo "MathJax needs update. Will sync with repository..."
	if [ -d ${MATHJAX_DIR} ]; then \
		cd ${MATHJAX_DIR}; \
		git pull origin; \
	else \
		git clone git://github.com/mathjax/MathJax.git ${MATHJAX_DIR}; \
		cd ${MATHJAX_DIR}; \
	fi; \
	if [ -f fonts.zip ]; then \
		if [ -d fonts ]; then echo rm -rf fonts; fi; \
		unzip fonts.zip; \
	fi
	touch ${MATHJAX_DIR}/.last_update
endif
