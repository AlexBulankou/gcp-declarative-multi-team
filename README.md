# TF and KCC Blueprint for multi-team organization setup
It will show how to configure multiple environments (dev, prod) with a dedicated cluster for each environment and then a namespace per team in each of the clusters.

Repeat the following steps for both `dev` and `prod` projects:

```bash
gcloud auth login
gcloud projects create [PROJECT_ID] --name=[PROJECT_ID] --folder=[FOLDER]
gcloud alpha billing projects link [PROJECT_ID] --billing-account [BILLING_ACCOUNT]
```

Set current project:

```bash
gcloud config set project $PROJECT_ID
PROJECT_ID=$(gcloud config get-value project)
```

Enable API:

```bash
gcloud services enable cloudbuild.googleapis.com compute.googleapis.com
```

Create storage bucket that will be used to keep Terraform state:

```bash
gsutil mb gs://${PROJECT_ID}-tfstate
```

Enable Object Versioning to keep the history of your deployments:

```bash
gsutil versioning set on gs://${PROJECT_ID}-tfstate
```

Configure both dev and prod environments' TF state to this bucket. Substitute dev or prod in the command below

```bash
sed -i "" s/PROJECT_ID/$PROJECT_ID/g environments/[dev|prod]/shared/terraform.tfvars
sed -i "" s/PROJECT_ID/$PROJECT_ID/g environments/[dev|prod]/shared/backend.tf
```

to switch back:

```bash
sed -i "" s/$PROJECT_ID/PROJECT_ID/g environments/[dev|prod]/shared/terraform.tfvars
sed -i "" s/$PROJECT_ID/PROJECT_ID/g environments/[dev|prod]/shared/backend.tf
```

Grant permissions to Cloud Build service account:

1. Retrieve the email:

    ```bash
    CLOUDBUILD_SA="$(gcloud projects describe $PROJECT_ID \
        --format 'value(projectNumber)')@cloudbuild.gserviceaccount.com"
    ```
2. Grant required permissions:
    ```bash
    gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member serviceAccount:$CLOUDBUILD_SA --role roles/owner
    ```

3. Follow the [instructions here](https://cloud.google.com/solutions/managing-infrastructure-as-code#directly_connecting_cloud_build_to_your_github_repository) too connect Cloud Build to your GH repository.