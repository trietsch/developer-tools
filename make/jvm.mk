# include file to be used by Streammachine makefiles in maven projects
#
# You can override variables and rules by writing the same names BELOW the
# invocation of include ${STRM_DEV_TOOLBOX}/jvm.mk
#
SHELL := bash
.PHONY: echo build clean check-dockertag

branch:=$(shell git rev-parse --abbrev-ref HEAD)
sources:=$(shell if [ -d src ]; then find src -type f;fi) pom.xml
version:=$(shell xmllint --xpath "/*[local-name() = 'project']/*[local-name() = 'version']/text()" pom.xml)
artifactId:=$(shell xmllint --xpath "/*[local-name() = 'project']/*[local-name() = 'artifactId']/text()" pom.xml)
target:=target/${artifactId}-${version}-jar-with-dependencies.jar

echo:
	@echo "artifactId = ${artifactId}"
	@echo "version = ${version}"
	@echo "target = ${target}"
	@echo "branch = ${branch}"
	@echo "dockertag = ${dockertag}"

echo-src:
	@echo "sources = ${sources}"


build: ${target}

clean:
	./mvnw clean

${target}: ${sources}
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

check-dockertag:
	@[ "${dockertag}" ] || ( echo ">> dockertag is not set"; exit 1 )

# gcloud auth configure-docker eu.gcr.io
#
dockerbuild: check-dockertag ${target}
	docker build . -t ${dockertag} && \
	docker push ${dockertag}


dockerbuild-notest: check-dockertag
	./mvnw package -DskipTests && \
	docker build . -t ${dockertag} && \
	docker push ${dockertag}
