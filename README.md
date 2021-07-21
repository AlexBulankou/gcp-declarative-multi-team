# GitOps with CloudBuild, Terraform, Config Connector and Config Sync

This project is an example of configuring multiple environments (dev and prod) with a dedicated GKE cluster for each of the environments. GKE cluster has Config Sync and Config Connector add-ons that enable using GitOps and provisioning GCP resources as well as native K8s resources, by submitting yaml configs under environments/[environment]/csproot/namespaces/[team-name], e.g. `environments/dev/csproot/namespaces/service-a/`.

## Installation (platform admin flow)

As a platform admin, you will configure the following environment for multiple teams.

1. Clone this repo and proceed to work on the instructions from your repo. At one step you will modify
   your local and submit the changes.

1. Set several variables that will be used througout the project

    ```bash
    FOLDER_ID = [FOLDER]
    BILLING_ACCOUNT = [BILLING_ACCOUNT]
    ```

1. Create the project that will contain CloudBuild service and GCS bucket.

    ```bash
    CB_PROJECT_ID=[CB_PROJECT_ID]
    gcloud auth login
    gcloud projects create $CB_PROJECT_ID --name=$CB_PROJECT_ID --folder=$FOLDER_ID
    gcloud alpha billing projects link $CB_PROJECT_ID --billing-account $BILLING_ACCOUNT
    ```

1. Set it as current project:

    ```bash
    gcloud config set project $CB_PROJECT_ID

1. Enable multiple APIs on the Cloud Build project:

    ```bash
    gcloud services enable cloudbuild.googleapis.com \
                           compute.googleapis.com \
                           cloudresourcemanager.googleapis.com \
                           iam.googleapis.com \
                           container.googleapis.com \
                           gkehub.googleapis.com
    ```

1. Create storage bucket that will be used to keep Terraform state:

    ```bash
    gsutil mb gs://${CB_PROJECT_ID}-tfstate
    ```

1. Enable Object Versioning to keep the history of your deployments:

    ```bash
    gsutil versioning set on gs://${CB_PROJECT_ID}-tfstate
    ```

1. Create dev and test projects that will contain the infrastructure for your environments:

    ```bash
    
    # specify the project holding the state in backend.tf for for dev and prod (wtih different prefixes)
    sed -i "" s/PROJECT_ID/$CB_PROJECT_ID/g environments/dev/shared/backend.tf
    sed -i "" s/PROJECT_ID/$CB_PROJECT_ID/g environments/prod/shared/backend.tf


    DEV_PROJECT_ID=[DEV_PROJECT_ID]
    gcloud projects create $DEV_PROJECT_ID --name=$DEV_PROJECT_ID --folder=$FOLDER_ID
    gcloud alpha billing projects link $DEV_PROJECT_ID --billing-account $BILLING_ACCOUNT

        
    PROD_PROJECT_ID=[PROD_PROJECT_ID]
    gcloud projects create $PROD_PROJECT_ID --name=$PROD_PROJECT_ID --folder=$FOLDER_ID
    gcloud alpha billing projects link $PROD_PROJECT_ID --billing-account $BILLING_ACCOUNT
    ```

1. Update the code in repo to substitute dev or prod in the command below

    ```bash
    sed -i "" s/PROJECT_ID/$DEV_PROJECT_ID/g environments/dev/shared/terraform.tfvars
    sed -i "" s/PROJECT_ID/$DEV_PROJECT_ID/g environments/dev/csproot/cluster/configconnector.yaml
    sed -i "" s/PROJECT_ID/$DEV_PROJECT_ID/g environments/dev/csproot/namespaces/service-a/namespace.yaml

    sed -i "" s/PROJECT_ID/$PROD_PROJECT_ID/g environments/prod/shared/terraform.tfvars
    sed -i "" s/PROJECT_ID/$CB_PROJECT_ID/g environments/prod/shared/backend.tf
    sed -i "" s/PROJECT_ID/$PROD_PROJECT_ID/g environments/prod/csproot/cluster/configconnector.yaml
    sed -i "" s/PROJECT_ID/$PROD_PROJECT_ID/g environments/prod/csproot/namespaces/service-a/namespace.yaml
    ```

1. Grant permissions to Cloud Build service account:

   Retrieve SA:

    ```bash
    CLOUDBUILD_SA="$(gcloud projects describe $CB_PROJECT_ID \
        --format 'value(projectNumber)')@cloudbuild.gserviceaccount.com"
    ```

    Grant required permissions to both dev and test projects:

    ```bash
    gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
    --member serviceAccount:$CLOUDBUILD_SA --role roles/owner
    gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
    --member serviceAccount:$CLOUDBUILD_SA --role roles/storage.admin
    gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
    --member serviceAccount:$CLOUDBUILD_SA --role roles/storage.objectAdmin

    gcloud projects add-iam-policy-binding $PROD_PROJECT_ID \
    --member serviceAccount:$CLOUDBUILD_SA --role roles/owner
    gcloud projects add-iam-policy-binding $PROD_PROJECT_ID \
    --member serviceAccount:$CLOUDBUILD_SA --role roles/storage.admin
    gcloud projects add-iam-policy-binding $PROD_PROJECT_ID \
    --member serviceAccount:$CLOUDBUILD_SA --role roles/storage.objectAdmin
    ```

1. Follow the [instructions here](https://cloud.google.com/solutions/managing-infrastructure-as-code#directly_connecting_cloud_build_to_your_github_repository) too connect Cloud Build to your GH repository.
1. If you plan to sync your code from the branch other than `main` change it 
1. Submit the changes to your repo and allow Cloud Build checkin hook to synchronize them. Alternatively you can submit them directly for both PROD and DEV environments with:
  
  ```bash
  gcloud auth application-default login

  cd environments/prod/shared
  terraform init -upgrade
  terraform plan



## App Developer Deployment Flow

As app developer you will use Config Connector and Config Sync to manager your infrastructure from your K8s cluster.

1. Identify the projects for dev and test environments.

    ```bash
    DEV_PROJECT_ID=[DEV_PROJECT_ID]
    PROD_PROJECT_ID=[PROD_PROJECT_ID]
    ```

2. Prepare the expanded configuration using Helm:

    ```bash
    helm lint ./templates/wp-chart/ --set google.projectId=$DEV_PROJECT_ID --set google.namespace=service-a
    helm template ./templates/wp-chart/ --set google.projectId=$DEV_PROJECT_ID --set google.namespace=service-a \
        > ./environments/dev/csproot/namespaces/service-a/wp.yaml

    helm lint ./templates/wp-chart/ --set google.projectId=$PROD_PROJECT_ID --set google.namespace=service-a
    helm template ./templates/wp-chart/ --set google.projectId=$PROD_PROJECT_ID --set google.namespace=service-a \
        > ./environments/prod/csproot/namespaces/service-a/wp.yaml
    ```
3. Submit the expanded configuration to git repo. They will be synchronized by Config sync and applied for both dev and prod environment.

4. Validate that Wordpress instances were created in your dev and prod projects.

    ```bash
    kubectl get service wordpress-external -n=service-a
    ping [external-ip]
    ```
