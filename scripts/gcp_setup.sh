#!/usr/bin/env bash
# =============================================================================
# GCP setup script for wsde (Worst Stag Do Ever)
#
# Run once from the repo root after gcloud auth login and billing linked.
# Safe to re-run — most commands are idempotent.
#
# Usage:
#   chmod +x scripts/gcp_setup.sh
#   ./scripts/gcp_setup.sh
#
# What this does:
#   1. Enables required APIs
#   2. Creates App Engine app (europe-west2, Standard)
#   3. Creates Cloud SQL PostgreSQL instance + database + user
#   4. Creates GCS bucket for static files
#   5. Creates a deployment service account with required roles
#   6. Sets up Workload Identity Federation for keyless GitHub Actions auth
#   7. Prints all the secrets/values you need to add to GitHub
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Config — edit these if needed
# ---------------------------------------------------------------------------
PROJECT_ID="wsde-marcelkornblum"
REGION="europe-west2"
GITHUB_REPO="marcelkornblum/wsde"

# Cloud SQL
SQL_INSTANCE="wsde-db"
SQL_TIER="db-f1-micro"           # cheapest; upgrade when needed
SQL_VERSION="POSTGRES_17"
DB_NAME="wsde"
DB_USER="wsde"

# GCS
GCS_BUCKET="${PROJECT_ID}-static"

# Service account for deployments
SA_NAME="wsde-deploy"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Workload Identity Federation
WIF_POOL="github-actions"
WIF_PROVIDER="github"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo -e "\n\033[36m▶  $*\033[0m"; }
success() { echo -e "\033[32m✅  $*\033[0m"; }
warn()    { echo -e "\033[33m⚠️   $*\033[0m"; }

# ---------------------------------------------------------------------------
# 0. Set project
# ---------------------------------------------------------------------------
info "Setting active project to ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

# ---------------------------------------------------------------------------
# 1. Enable APIs
# ---------------------------------------------------------------------------
info "Enabling required APIs (this can take a minute)..."
gcloud services enable \
    appengine.googleapis.com \
    sqladmin.googleapis.com \
    storage.googleapis.com \
    secretmanager.googleapis.com \
    iam.googleapis.com \
    iamcredentials.googleapis.com \
    cloudresourcemanager.googleapis.com \
    sts.googleapis.com
success "APIs enabled"

# ---------------------------------------------------------------------------
# 2. App Engine app
# ---------------------------------------------------------------------------
info "Creating App Engine app in ${REGION}..."
if gcloud app describe --project="${PROJECT_ID}" &>/dev/null; then
    warn "App Engine app already exists — skipping creation"
else
    gcloud app create --region="${REGION}" --project="${PROJECT_ID}"
    success "App Engine app created"
fi

# ---------------------------------------------------------------------------
# 3. Cloud SQL instance
# ---------------------------------------------------------------------------
info "Creating Cloud SQL instance '${SQL_INSTANCE}' (${SQL_VERSION}, ${SQL_TIER})..."
info "This usually takes 3–5 minutes..."
if gcloud sql instances describe "${SQL_INSTANCE}" --project="${PROJECT_ID}" &>/dev/null; then
    warn "Cloud SQL instance '${SQL_INSTANCE}' already exists — skipping"
else
    gcloud sql instances create "${SQL_INSTANCE}" \
        --database-version="${SQL_VERSION}" \
        --tier="${SQL_TIER}" \
        --edition=ENTERPRISE \
        --region="${REGION}" \
        --storage-auto-increase \
        --no-assign-ip \
        --project="${PROJECT_ID}"
    success "Cloud SQL instance created"
fi

CLOUD_SQL_CONNECTION_NAME=$(gcloud sql instances describe "${SQL_INSTANCE}" \
    --project="${PROJECT_ID}" \
    --format="value(connectionName)")
info "Connection name: ${CLOUD_SQL_CONNECTION_NAME}"

info "Creating database '${DB_NAME}'..."
gcloud sql databases create "${DB_NAME}" \
    --instance="${SQL_INSTANCE}" \
    --project="${PROJECT_ID}" 2>/dev/null || warn "Database '${DB_NAME}' already exists"

info "Creating database user '${DB_USER}'..."
# Generate a strong random password
DB_PASSWORD=$(python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits + '!@#%^&*') for _ in range(32)))")
gcloud sql users create "${DB_USER}" \
    --instance="${SQL_INSTANCE}" \
    --password="${DB_PASSWORD}" \
    --project="${PROJECT_ID}" 2>/dev/null || {
    warn "User '${DB_USER}' already exists — generating new password..."
    DB_PASSWORD=$(python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits + '!@#%^&*') for _ in range(32)))")
    gcloud sql users set-password "${DB_USER}" \
        --instance="${SQL_INSTANCE}" \
        --password="${DB_PASSWORD}" \
        --project="${PROJECT_ID}"
}
success "Database user configured"

# ---------------------------------------------------------------------------
# 4. GCS bucket for static files
# ---------------------------------------------------------------------------
info "Creating GCS bucket gs://${GCS_BUCKET}..."
if gsutil ls "gs://${GCS_BUCKET}" &>/dev/null; then
    warn "Bucket gs://${GCS_BUCKET} already exists — skipping"
else
    gsutil mb -l "${REGION}" "gs://${GCS_BUCKET}"
    success "Bucket created"
fi

info "Making bucket publicly readable (for static files)..."
gsutil iam ch allUsers:objectViewer "gs://${GCS_BUCKET}"
success "Bucket is public"

# Uniform bucket-level access
gsutil uniformbucketlevelaccess set on "gs://${GCS_BUCKET}" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 5. Deployment service account
# ---------------------------------------------------------------------------
info "Creating service account '${SA_NAME}'..."
if gcloud iam service-accounts describe "${SA_EMAIL}" --project="${PROJECT_ID}" &>/dev/null; then
    warn "Service account already exists — skipping creation"
else
    gcloud iam service-accounts create "${SA_NAME}" \
        --display-name="wsde GitHub Actions deploy" \
        --project="${PROJECT_ID}"
    success "Service account created"
fi

info "Granting roles to service account..."
ROLES=(
    "roles/appengine.deployer"
    "roles/appengine.serviceAdmin"
    "roles/cloudbuild.builds.editor"
    "roles/cloudsql.client"
    "roles/storage.admin"
    "roles/iam.serviceAccountUser"
    "roles/secretmanager.secretAccessor"
)
for ROLE in "${ROLES[@]}"; do
    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="${ROLE}" \
        --condition=None \
        --quiet
done
success "Roles granted"

# ---------------------------------------------------------------------------
# 6. Workload Identity Federation (keyless GitHub Actions auth)
# ---------------------------------------------------------------------------
info "Creating Workload Identity Pool '${WIF_POOL}'..."
if gcloud iam workload-identity-pools describe "${WIF_POOL}" \
        --location="global" --project="${PROJECT_ID}" &>/dev/null; then
    warn "WIF pool '${WIF_POOL}' already exists — skipping"
else
    gcloud iam workload-identity-pools create "${WIF_POOL}" \
        --location="global" \
        --display-name="GitHub Actions" \
        --project="${PROJECT_ID}"
    success "WIF pool created"
fi

WIF_POOL_ID=$(gcloud iam workload-identity-pools describe "${WIF_POOL}" \
    --location="global" \
    --project="${PROJECT_ID}" \
    --format="value(name)")

info "Creating WIF provider '${WIF_PROVIDER}'..."
if gcloud iam workload-identity-pools providers describe "${WIF_PROVIDER}" \
        --workload-identity-pool="${WIF_POOL}" \
        --location="global" \
        --project="${PROJECT_ID}" &>/dev/null; then
    warn "WIF provider '${WIF_PROVIDER}' already exists — skipping"
else
    gcloud iam workload-identity-pools providers create-oidc "${WIF_PROVIDER}" \
        --workload-identity-pool="${WIF_POOL}" \
        --location="global" \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor" \
        --attribute-condition="assertion.repository=='${GITHUB_REPO}'" \
        --project="${PROJECT_ID}"
    success "WIF provider created"
fi

WIF_PROVIDER_ID=$(gcloud iam workload-identity-pools providers describe "${WIF_PROVIDER}" \
    --workload-identity-pool="${WIF_POOL}" \
    --location="global" \
    --project="${PROJECT_ID}" \
    --format="value(name)")

info "Binding WIF pool to service account..."
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
    --project="${PROJECT_ID}" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/${WIF_POOL_ID}/attribute.repository/${GITHUB_REPO}"
success "WIF binding created"

# ---------------------------------------------------------------------------
# 7. Generate a Django SECRET_KEY
# ---------------------------------------------------------------------------
DJANGO_SECRET_KEY=$(python3 -c "
import secrets, string
chars = string.ascii_letters + string.digits + '!@#\$%^&*(-_=+)'
print(''.join(secrets.choice(chars) for _ in range(60)))
")

# ---------------------------------------------------------------------------
# 8. Print summary — everything needed for GitHub secrets
# ---------------------------------------------------------------------------
echo ""
echo "============================================================================="
echo "  ✅  GCP SETUP COMPLETE"
echo "============================================================================="
echo ""
echo "Add these as secrets/variables in GitHub:"
echo "  https://github.com/${GITHUB_REPO}/settings/environments"
echo ""
echo "Create TWO environments: 'staging' and 'production'"
echo "Add these to BOTH (same values unless you want separate DBs):"
echo ""
echo "  Secrets:"
echo "    GCP_WORKLOAD_IDENTITY_PROVIDER  = ${WIF_PROVIDER_ID}"
echo "    GCP_SERVICE_ACCOUNT             = ${SA_EMAIL}"
echo "    GCP_PROJECT_ID                  = ${PROJECT_ID}"
echo "    CLOUD_SQL_CONNECTION_NAME       = ${CLOUD_SQL_CONNECTION_NAME}"
echo "    DJANGO_SECRET_KEY               = ${DJANGO_SECRET_KEY}"
echo "    DB_NAME                         = ${DB_NAME}"
echo "    DB_USER                         = ${DB_USER}"
echo "    DB_PASSWORD                     = ${DB_PASSWORD}"
echo ""
echo "  Variables:"
echo "    GCS_BUCKET_NAME                 = ${GCS_BUCKET}"
echo ""
echo "Next steps:"
echo "  1. Add the secrets above to GitHub"
echo "  2. Create app.yaml in the repo root (run: make app-yaml or see below)"
echo "  3. Push to main to trigger a staging deploy"
echo ""
echo "app.yaml minimum:"
echo "---"
cat <<APPYAML
runtime: python313
service: default
entrypoint: gunicorn -b :\$PORT core.wsgi:application

env_variables:
  DJANGO_SETTINGS_MODULE: core.settings.production

beta_settings:
  cloud_sql_instances: ${CLOUD_SQL_CONNECTION_NAME}
APPYAML
echo "---"
echo ""
echo "Save the DB_PASSWORD somewhere safe — it won't be shown again."
echo "============================================================================="
