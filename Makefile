init_modules:
	git submodule update --init --recursive

status_modules:
	bash ./admin_submodules_status.sh

update_modules:
	bash ./admin_update_submodules.sh

package_workflows:
	python ./deploy/admin_package_workflows.py

	# compressing
	cd deploy/workflows && tar -czvf ../GNPS2_Workflows.tar.gz *