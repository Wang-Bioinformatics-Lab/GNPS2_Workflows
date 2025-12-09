import os
import yaml
import shutil
from glob import glob

def reorganize_workflow_locally(path_to_workflow):
    """
    Parses workflow YAML files and copies necessary files into a
    'deploy/workflows/[workflow_name]' structure within the current working directory.

    Args:
        path_to_workflow (str): The path to the specific workflow's source folder.
    """
    print(f"--- Processing Workflow Folder: {path_to_workflow} ---")

    # 1. Setting the paths for input files
    workflow_input_filename = os.path.join(path_to_workflow, "workflowinput.yaml")
    workflow_display_filename = os.path.join(path_to_workflow, "workflowdisplay.yaml")

    # 2. Validate and Parse Input YAML 
    try:
        with open(workflow_input_filename, 'r') as f:
            workflow_input_specifications = yaml.safe_load(f)
    except FileNotFoundError:
        print(f"Error: Workflow Input File not found at {workflow_input_filename}")
        return
    except yaml.YAMLError:
        print("Error: Cannot Parse Workflow Input File")
        return

    # Extract required names
    try:
        workflow_name = os.path.basename(workflow_input_specifications["workflowname"])
        nf_workflow_file = os.path.basename(workflow_input_specifications["workflowfile"])
    except KeyError as e:
        print(f"Error: Missing key in workflowinput.yaml: {e}")
        return

    # 3. Validate and Parse Display YAML
    try:
        with open(workflow_display_filename, 'r') as f:
            workflow_display_specifications = yaml.safe_load(f)
    except FileNotFoundError:
        print(f"Error: Workflow Display File not found at {workflow_display_filename}")
        return
    except yaml.YAMLError:
        print("Error: Cannot Parse Workflow Display File")
        return

    # 4. Assert name consistency 
    if workflow_name != workflow_display_specifications.get("name"):
        print(f"Error: Workflow names do not match: '{workflow_name}' vs '{workflow_display_specifications.get('name')}'")
        print("Warning: Proceeding despite name mismatch.")

    # 5. Define Target Paths (UPDATED)
    # We now create a root 'deploy/workflows' folder and the specific workflow folder inside it
    deploy_root = "deploy"
    workflows_root = os.path.join(deploy_root, "workflows")
    target_workflow_folder = os.path.join(workflows_root, workflow_name)

    # 6. Create the target deployment directory
    try:
        # os.makedirs handles creating the full path 'deploy/workflows/workflow_name'
        os.makedirs(target_workflow_folder, exist_ok=True)
        print(f"Created/Ensured target folder: **{target_workflow_folder}**")
    except OSError as e:
        print(f"Error creating directory {target_workflow_folder}: {e}")
        return

    # 7. Determine what to copy over
    files_to_copy = ["workflowinput.yaml", "workflowdisplay.yaml", nf_workflow_file, "bin"]

    # 8. Copy files and folders (Symlink handling remains the same)
    for item_name in files_to_copy:
        local_path = os.path.join(path_to_workflow, item_name)
        remote_path = os.path.join(target_workflow_folder, item_name)

        if not os.path.exists(local_path) and not os.path.islink(local_path):
            if item_name != "bin": 
                print(f"Warning: Required file/folder not found: {local_path}. Skipping.")
            continue

        try:
            if os.path.isdir(local_path) and not os.path.islink(local_path):
                if os.path.exists(remote_path):
                    shutil.rmtree(remote_path)
                shutil.copytree(local_path, remote_path, symlinks=False) 
                print(f"Copied folder: **{item_name}** (Dereferenced)")
            
            elif os.path.isdir(local_path) and os.path.islink(local_path):
                if os.path.exists(remote_path):
                    shutil.rmtree(remote_path)
                shutil.copytree(local_path, remote_path) 
                print(f"Copied folder (Symlink Target): **{item_name}** (Dereferenced)")

            else:
                shutil.copy2(local_path, remote_path, follow_symlinks=True) 
                print(f"Copied file: **{item_name}** (Dereferenced)")
                
        except shutil.Error as e:
            print(f"Error copying {item_name}: {e}")
        except OSError as e:
            print(f"Error during copy operation for {item_name}: {e}")

    print(f"--- Successfully reorganized **{workflow_name}** ---")
    print("-" * 50)

# --- Example Usage ---
if __name__ == '__main__':
    # Determine the directory where your workflow sub-folders are located
    base_dir = os.getcwd()
    
    # Find all top-level directories that are not the target 'deploy' folder
    workflow_folders = [f for f in glob(os.path.join(base_dir, "*")) if os.path.isdir(f) and not os.path.basename(f) == 'deploy']
    
    # Filter out system/hidden folders
    workflow_folders = [f for f in workflow_folders if os.path.basename(f) not in ('.git', '..', '.')]

    if not workflow_folders:
        print(f"No workflow sub-folders found in {base_dir}. Please check your working directory/path.")
    else:
        print(f"Found {len(workflow_folders)} workflow folder(s) to process.")
        for folder in workflow_folders:
            reorganize_workflow_locally(folder)