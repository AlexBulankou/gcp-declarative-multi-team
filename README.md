# GitOps with CloudBuild, Terraform, Config Connector and Config Sync

This project is an example of configuring multiple environments (dev and prod) with a dedicated GKE cluster for each of the environments. GKE cluster has Config Sync and Config Connector add-ons that enable using GitOps and provisioning GCP resources as well as native K8s resources provisioning, by submitting yaml configs under environments/[environment]/csproot/namespaces/[team-name], e.g. `environments/dev/csproot/namespaces/service-a/`.

## Installation (platform admin flow)

1. Create the project that will contain CloudBuild service and GCS bucket.

    ```bash
    gcloud auth login
    CB_PROJECT_ID=[CB_PROJECT_ID]
    gcloud projects create $CB_PROJECT_ID --name=$CB_PROJECT_ID --folder=[FOLDER]
    gcloud alpha billing projects link $CB_PROJECT_ID --billing-account [BILLING_ACCOUNT]
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
                           container.googleapis.com
    ```

1. Create storage bucket that will be used to keep Terraform state:

    ```bash
    gsutil mb gs://${CB_PROJECT_ID}-tfstate
    ```

1. Enable Object Versioning to keep the history of your deployments:

    ```bash
    gsutil versioning set on gs://${CB_PROJECT_ID}-tfstate
    ```

1. Create dev and test projects that will contain the infrastructure for your environments. After creation, assign the variables:

    ```bash
    DEV_PROJECT_ID=[DEV_PROJECT_ID]
    PROD_PROJECT_ID=[PROD_PROJECT_ID]
    ```

1. Update the code in repo to substitute dev or prod in the command below

    ```bash
    sed -i "" s/PROJECT_ID/$DEV_PROJECT_ID/g environments/dev/shared/terraform.tfvars
    sed -i "" s/PROJECT_ID/$DEV_PROJECT_ID/g environments/dev/shared/backend.tf

    sed -i "" s/PROJECT_ID/$PROD_PROJECT_ID/g environments/prod/shared/terraform.tfvars
    sed -i "" s/PROJECT_ID/$PROD_PROJECT_ID/g environments/prod/shared/backend.tf
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


## App Developer Deployment Flow

1. Set the projects that you're working with:

    ```bash
    DEV_PROJECT_ID=[DEV_PROJECT_ID]
    PROD_PROJECT_ID=[PROD_PROJECT_ID]
    ```

2. Validate and prepare the chart using `helm` for both dev and prod environments:

    ```bash
    helm lint ./templates/wp-chart/ --set google.projectId=$DEV_PROJECT_ID
    helm template ./templates/wp-chart/ --set google.projectId=$DEV_PROJECT_ID \
        > ./environments/dev/csproot/namespaces/service-a/wp.yaml

    helm lint ./templates/wp-chart/ --set google.projectId=$PROD_PROJECT_ID
    helm template ./templates/wp-chart/ --set google.projectId=$PROD_PROJECT_ID \
        > ./environments/prod/csproot/namespaces/service-a/wp.yaml
    ```
