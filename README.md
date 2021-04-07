# TF and KCC Blueprint for multi-team organization setup
It will show how to configure multiple environments (dev, prod) with a dedicated cluster for each environment and then a namespace per team in each of the clusters.

1. Create the project that will have CloudBuild service and GCS bucket.

# folder_id: 52733342542
# billing_account: 019970-D6BDB5-6AF850

    ```bash
    gcloud auth login
    CB_PROJECT_ID=[CB_PROJECT_ID]
    gcloud projects create $CB_PROJECT_ID --name=$CB_PROJECT_ID --folder=[FOLDER]
    gcloud alpha billing projects link $CB_PROJECT_ID --billing-account [BILLING_ACCOUNT]
    ```

    Set current project:

    ```bash
    gcloud config set project $CB_PROJECT_ID


    1. Enable CloudBuild API:

    ```bash
    gcloud services enable cloudbuild.googleapis.com compute.googleapis.com
    ```

    Create storage bucket that will be used to keep Terraform state:

    ```bash
    gsutil mb gs://${CB_PROJECT_ID}-tfstate
    ```

    Enable Object Versioning to keep the history of your deployments:

    ```bash
    gsutil versioning set on gs://${CB_PROJECT_ID}-tfstate
    ```
    ```


1. Create dev and test projects that will contain the infrastructure for your environments. After creation, assign the variables:
    ```bash
    DEV_PROJECT_ID=[DEV_PROJECT_ID]
    PROD_PROJECT_ID=[PROD_PROJECT_ID]

    Update the code in repo to substitute dev or prod in the command below

    ```bash
    sed -i "" s/PROJECT_ID/$DEV_PROJECT_ID/g environments/dev/shared/terraform.tfvars
    sed -i "" s/PROJECT_ID/$DEV_PROJECT_ID/g environments/dev/shared/backend.tf

    sed -i "" s/PROJECT_ID/$PROD_PROJECT_ID/g environments/prod/shared/terraform.tfvars
    sed -i "" s/PROJECT_ID/$PROD_PROJECT_ID/g environments/prod/shared/backend.tf
    ```

1. Grant permissions to Cloud Build service account:

   Retrieve the email:

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

Don't forget to repeat the same steps for test project.