init_modules:
	git submodule update --init --recursive

status_modules:
	bash ./admin_submodules_status.sh

update_modules:
	bash ./admin_update_submodules.sh

package_workflows:
	rm -rf deploy/workflows

	python ./deploy/admin_package_workflows.py

	# compressing
	cd deploy/workflows && tar -cvf - * | pigz -9 > ../GNPS2_Workflows.tar.gz && cd ../..

	echo "Packaged workflows are available at deploy/GNPS2_Workflows.tar.gz now good to deploy"