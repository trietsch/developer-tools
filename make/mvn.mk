set-version:
	@read -p "Enter New Version: " version; \
	./mvnw versions:set -DnewVersion=$$version
