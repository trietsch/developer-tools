# include file to be used by Streammachine makefiles in maven projects
#
#
SHELL := bash
.PHONY: echo build

branch:=$(shell git rev-parse --abbrev-ref HEAD)
sources:=$(shell find src -type f) pom.xml
version:=$(shell xmllint --xpath "/*[local-name() = 'project']/*[local-name() = 'version']/text()" pom.xml)
name:=$(shell xmllint --xpath "/*[local-name() = 'project']/*[local-name() = 'name']/text()" pom.xml)
target:="target/${name}-${version}-jar-with-dependencies.jar"

# You can override variables above by writing the same names BELOW the
# invocation of include ${STRM_DEV_TOOLBOX}/make-jvm.mk


echo:
	@echo "name = ${name}"
	@echo "version = ${version}"
	@echo "target = ${target}"
	@echo "branch = ${branch}"
	@echo "dockertag = ${dockertag}"

build: ${target}

${target}: ${sources}
	rm -f target/*.jar && \
	./mvnw package

# Deploy skip required: we're building a Docker image, we're not pushing to artifactory here
# JavaDoc skip required: because Dagger is stupid and doesn't play well with Maven Release
release:
	if [[ "$(branch)" == "master" ]]; then \
	    echo "Creating new release..."; \
	    ./mvnw -s .mvn/settings.xml --batch-mode \
	      clean build-helper:parse-version release:clean release:prepare release:perform \
	      -DdevelopmentVersion='$${parsedVersion.majorVersion}.$${parsedVersion.nextMinorVersion}.0-SNAPSHOT' \
	      -Darguments="-Dmaven.deploy.skip=true -Dmaven.javadoc.skip=true -DskipTests"; \
	else \
	    echo "Ensure that you're working on master when doing a release."; \
	fi

# gcloud auth configure-docker eu.gcr.io
#
dockerbuild:
	docker build . -t ${dockertag} && \
	docker push ${dockertag}


dockerbuild-notest:
	./mvnw package -DskipTests && \
	docker build . -t ${dockertag} && \
	docker push ${dockertag}
