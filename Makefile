include /home/y/share/yahoo_cfg/screwdriver/Make.rules


HADOOP_TEST_VERSION = 2.6.0
PKG_DIR := ypackage
BASE_DIST_VERSION := $(shell cat $(PKG_DIR)/BASE_DIST_VERSION)
HADOOP_VERSION := $(shell cat $(PKG_DIR)/HADOOP_VERSION)
VERSION_TIMESTAMP := $(shell date +%y%m%d%H%M)
DIST_FULL_VERSION = $(shell cat $(PKG_DIR)/DIST_FULL_VERSION)

DEFAULT_SCALA_VERSION := 2.10
# Suffixed _MAKE so users can set SCALA_VERSION in the env.
SCALA_VERSION_MAKE = $(shell cat $(PKG_DIR)/SCALA_VERSION)

SCALA_VERSION_SUFFIX = $(shell cat $(PKG_DIR)/SCALA_VERSION_SUFFIX)

.PHONY: screwdriver spark_bld spark_test spark_bld_sbt spark_test_sbt \
	$(PKG_DIR)/DIST_FULL_VERSION manually_create_dist_package update_pom_versions_and_ignore_changes \
	$(PKG_DIR)/SCALA_VERSION $(PKG_DIR)/SCALA_VERSION_SUFFIX

HADOOP_PROFILE = hadoop-2.6
YARN_PROFILE = yarn
DEFAULT_MVN_PROFILES = -P$(YARN_PROFILE) -P$(HADOOP_PROFILE) -Phive -Phive-thriftserver
DIST_MVN_PROFILES = $(DEFAULT_MVN_PROFILES) -Psparkr

MVN = build/mvn --force
CORES = $(shell test -f /proc/cpuinfo && grep '^processor' /proc/cpuinfo |wc -l)
CORES ?= 1

screwdriver: spark_bld

test: spark_bld_sbt spark_test_sbt spark_save_test_results 

test_mvn: spark_test spark_save_test_results 

$(PKG_DIR)/SCALA_VERSION:
	> $(PKG_DIR)/SCALA_VERSION # start with empty file
	if [ -n "$${SCALA_VERSION}" ]; then \
		echo "$${SCALA_VERSION}" > $(PKG_DIR)/SCALA_VERSION; \
	else \
		echo $(DEFAULT_SCALA_VERSION) > $(PKG_DIR)/SCALA_VERSION; \
	fi

$(PKG_DIR)/SCALA_VERSION_SUFFIX: $(PKG_DIR)/SCALA_VERSION
	> $(PKG_DIR)/SCALA_VERSION_SUFFIX # start with empty file
	# For non-empty lines, prefix with _ and remove . characters.
	# e.g. 2.11 -> _211
	if [ "$(SCALA_VERSION_MAKE)" != "$(DEFAULT_SCALA_VERSION)" ]; then \
		sed -e 's;^..*$$;_&;' -e 's;\.;;g' $(PKG_DIR)/SCALA_VERSION > \
			$(PKG_DIR)/SCALA_VERSION_SUFFIX; \
	fi

/tmp/rinstall/bin/R:
	cd $(PKG_DIR)/R/ && tar -zxvf R-3.2.1.tar.gz
	cd $(PKG_DIR)/R/R-3.2.1 && ./configure --prefix=/tmp/rinstall && make -j $(CORES) && make install

spark_bld: /tmp/rinstall/bin/R $(PKG_DIR)/SCALA_VERSION_SUFFIX
	if [ "$(SCALA_VERSION_MAKE)" != "$(DEFAULT_SCALA_VERSION)" ]; then \
		./dev/change-scala-version.sh $(SCALA_VERSION_MAKE); \
	fi
	PATH=/tmp/rinstall/bin:$$PATH $(MVN) -Dscala-$(SCALA_VERSION_MAKE) $(DIST_MVN_PROFILES) -DskipTests package

spark_test:
	(export SPARK_JAVA_OPTS="-Dspark.authenticate=false" && export MAVEN_OPTS="-Xmx3096m -XX:PermSize=128m -XX:MaxPermSize=2048m" && $(MVN) -P$(HADOOP_PROFILE) -P$(YARN_PROFILE) -Dmaven.test.error.ignore=true -Dmaven.test.failure.ignore=true -DMaxPermGen=1024m install test)

# echo "q" is needed because sbt on encountering a build file with failure
# (either resolution or compilation) prompts the user for input either q, r,
# etc to quit or retry. This echo is there to make it not block.
spark_bld_sbt:
	echo -e "q\n" | sbt/sbt -P$(YARN_PROFILE) -P$(HADOOP_PROFILE) clean package assembly/assembly

spark_test_sbt:
	echo -e "q\n" | sbt/sbt -P$(YARN_PROFILE) -P$(HADOOP_PROFILE) test; exit 0

spark_save_test_results:
	mkdir sparktestresults && cp core/target/test-reports/*.xml sparktestresults/ && cp yarn/target/test-reports/*.xml sparktestresults/ && cp sql/core/target/test-reports/*.xml sparktestresults/ && cp streaming/target/test-reports/*.xml sparktestresults && cp repl/target/test-reports/*.xml sparktestresults/ && cp mllib/target/test-reports/*.xml  sparktestresults/ && cp ./graphx/target/test-reports/*.xml sparktestresults/

spark_clean_sbt:
	echo -e "q\n" | sbt/sbt $(DEFAULT_MVN_PROFILES) -Dhadoop.version=$(HADOOP_VERSION) clean

$(PKG_DIR)/DIST_FULL_VERSION: $(PKG_DIR)/SCALA_VERSION_SUFFIX
	echo "$(BASE_DIST_VERSION)_$(HADOOP_VERSION)_$(VERSION_TIMESTAMP)$(SCALA_VERSION_SUFFIX)" > $(PKG_DIR)/DIST_FULL_VERSION

define ignore-working-tree-changes
git ls-files -z | xargs --null git update-index --assume-unchanged
endef

define unignore-working-tree-changes
git ls-files -z | xargs --null git update-index --no-assume-unchanged
endef

define setup-versions
$(MVN) -q $(DIST_MVN_PROFILES) versions:set -DnewVersion=$(DIST_FULL_VERSION) $(MVN_MAKE_OPTS) > mvn-versions:set.log && \
	$(MVN) -q $(DIST_MVN_PROFILES) versions:update-child-modules $(MVN_MAKE_OPTS)
endef

update_pom_versions_and_ignore_changes: $(PKG_DIR)/DIST_FULL_VERSION
	$(setup-versions)
	$(ignore-working-tree-changes)

manually_create_dist_package: update_pom_versions_and_ignore_changes $(PKG_DIR)/SCALA_VERSION_SUFFIX
	cd $(PKG_DIR) && \
		yinst_create --buildtype release spark_yarn.yicf
	$(unignore-working-tree-changes)
