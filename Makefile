.PHONY: update-pioreactor-os-list

RELEASE_MANIFEST ?= build/release-manifest.json
PIOREACTOR_BRANCH ?= pioreactor
PIOREACTOR_OS_LIST_FILES := \
	Makefile \
	data_repository/list_of_pioreactor_releases.json \
	data_repository/os_list_pioreactor.json \
	data_repository/pioreactor_image_cache.json

update-pioreactor-os-list:
	python3 scripts/update_pioreactor_os_list.py $(RELEASE_MANIFEST)
	git add $(PIOREACTOR_OS_LIST_FILES)
	@if git diff --cached --quiet; then \
		echo "No OS list changes to commit."; \
	else \
		git commit -m "Update Pioreactor OS list"; \
		git push origin $(PIOREACTOR_BRANCH); \
	fi
