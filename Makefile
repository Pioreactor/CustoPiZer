.PHONY: update-pioreactor-os-list

LATEST_PIOREACTOR_RELEASE_URL := https://api.github.com/repos/Pioreactor/CustoPiZer/releases/latest
PIOREACTOR_BRANCH := pioreactor
PIOREACTOR_OS_LIST_FILES := \
	Makefile \
	data_repository/list_of_pioreactor_releases.json \
	data_repository/os_list_pioreactor.json \
	data_repository/pioreactor_image_cache.json

update-pioreactor-os-list:
	python3 scripts/update_pioreactor_os_list.py $(LATEST_PIOREACTOR_RELEASE_URL)
	git add $(PIOREACTOR_OS_LIST_FILES)
	git commit -m "Update Pioreactor OS list"
	git push origin $(PIOREACTOR_BRANCH)
