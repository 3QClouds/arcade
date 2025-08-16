#!/bin/bash

# Terraform Service Account Management Lab - Complete Script
# This script automates the Terraform setup for Google Cloud service account management

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to print colored status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${PURPLE}════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════════════${NC}"
}

print_task() {
    echo -e "\n${CYAN}▶ TASK: $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════${NC}"
}

# Get project information using metadata
print_status "Getting project and environment information..."
export PROJECT_ID=$(gcloud config get-value project)

# Get region and zone from project metadata
print_status "Retrieving zone and region from project metadata..."
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Set default region and zone if not found in metadata
if [ -z "$REGION" ] || [ "$REGION" = "(unset)" ]; then
    print_warning "Region not found in metadata, using default: us-central1"
    export REGION="us-central1"
fi

if [ -z "$ZONE" ] || [ "$ZONE" = "(unset)" ]; then
    print_warning "Zone not found in metadata, using default: us-central1-a"
    export ZONE="us-central1-a"
fi

echo -e "${CYAN}Project ID: ${WHITE}$PROJECT_ID${NC}"
echo -e "${CYAN}Region: ${WHITE}$REGION${NC}"
echo -e "${CYAN}Zone: ${WHITE}$ZONE${NC}"

# =============================================================================
# TASK 1: CONFIGURE GOOGLE CLOUD PROJECT
# =============================================================================
print_task "1. Configure Google Cloud Project"

print_step "Step 1.1: Set Project ID"
print_status "Setting active project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"
print_success "Project ID configured successfully!"

print_step "Step 1.2: Set Default Region"
print_status "Setting default compute region to: $REGION"
gcloud config set compute/region "$REGION"
print_success "Default region configured successfully!"

print_step "Step 1.3: Set Default Zone"
print_status "Setting default compute zone to: $ZONE"
gcloud config set compute/zone "$ZONE"
print_success "Default zone configured successfully!"

print_step "Step 1.4: Enable IAM API"
print_status "Enabling IAM API..."
gcloud services enable iam.googleapis.com
print_success "IAM API enabled successfully!"

echo -e "\n${GREEN}✓ TASK 1 COMPLETED: Google Cloud project configured successfully!${NC}"

# =============================================================================
# TASK 2: CREATE A CLOUD STORAGE BUCKET FOR TERRAFORM STATE
# =============================================================================
print_task "2. Create a Cloud Storage Bucket for Terraform State"

print_step "Step 2.1: Create Cloud Storage Bucket"
print_status "Creating bucket: gs://$PROJECT_ID-tf-state"
gcloud storage buckets create gs://"$PROJECT_ID"-tf-state \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --uniform-bucket-level-access
print_success "Cloud Storage bucket created successfully!"

print_step "Step 2.2: Enable Versioning on Bucket"
print_status "Enabling versioning on the bucket..."
gsutil versioning set on gs://"$PROJECT_ID"-tf-state
print_success "Bucket versioning enabled successfully!"

echo -e "\n${GREEN}✓ TASK 2 COMPLETED: Terraform state bucket configured!${NC}"

# =============================================================================
# TASK 3: CREATE A TERRAFORM CONFIGURATION FILE
# =============================================================================
print_task "3. Create a Terraform Configuration File"

print_step "Step 3.1: Create Terraform Directory"
print_status "Creating terraform-service-account directory..."
mkdir -p terraform-service-account
cd terraform-service-account
print_success "Terraform directory created and entered!"

print_step "Step 3.2: Create main.tf Configuration File"
print_status "Creating main.tf with Terraform configuration..."

cat > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    bucket = "$PROJECT_ID-tf-state"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region 
}

resource "google_service_account" "default" {
  account_id   = "terraform-sa"
  display_name = "Terraform Service Account"
}
EOF

print_success "main.tf configuration file created!"

print_step "Step 3.3: Create variables.tf File"
print_status "Creating variables.tf with variable definitions..."

cat > variables.tf <<EOF
variable "project_id" {
  type = string
  description = "The GCP project ID"
  default = "$PROJECT_ID"
}

variable "region" {
  type = string
  description = "The GCP region"
  default = "$REGION"
}
EOF

print_success "variables.tf file created!"

print_step "Step 3.4: Display Configuration Files"
print_status "Displaying created configuration files..."

echo -e "\n${YELLOW}Contents of main.tf:${NC}"
cat main.tf

echo -e "\n${YELLOW}Contents of variables.tf:${NC}"
cat variables.tf

echo -e "\n${GREEN}✓ TASK 3 COMPLETED: Terraform configuration files created!${NC}"

# =============================================================================
# TASK 4: INITIALIZE AND APPLY TERRAFORM CONFIGURATION
# =============================================================================
print_task "4. Initialize and Apply Terraform Configuration"

print_step "Step 4.1: Initialize Terraform"
print_status "Initializing Terraform in the current directory..."
terraform init
print_success "Terraform initialization completed!"

print_step "Step 4.2: Plan Terraform Configuration"
print_status "Creating Terraform execution plan..."
terraform plan
print_success "Terraform plan completed!"

print_step "Step 4.3: Apply Terraform Configuration"
print_status "Applying Terraform configuration to create resources..."
terraform apply -auto-approve
print_success "Terraform configuration applied successfully!"

print_step "Step 4.4: Verify Service Account Creation"
print_status "Verifying service account creation..."
gcloud iam service-accounts list --project="$PROJECT_ID" --filter="email:terraform-sa@$PROJECT_ID.iam.gserviceaccount.com"

print_status "Listing all service accounts in the project..."
gcloud iam service-accounts list --project="$PROJECT_ID"

print_success "Service account verification completed!"

echo -e "\n${GREEN}✓ TASK 4 COMPLETED: Terraform configuration applied and verified!${NC}"

# =============================================================================
# TASK 5: CLEAN UP RESOURCES
# =============================================================================
print_task "5. Clean Up Resources"

print_step "Step 5.1: Display Current Terraform State"
print_status "Showing current Terraform-managed resources..."
terraform show

print_step "Step 5.2: Plan Resource Destruction"
print_status "Planning resource destruction..."
terraform plan -destroy

print_step "Step 5.3: Destroy Terraform-Managed Infrastructure"
print_status "Destroying Terraform-managed resources..."
print_warning "This will delete the service account created by Terraform"
terraform destroy -auto-approve
print_success "Terraform resources destroyed successfully!"

print_step "Step 5.4: Verify Resource Cleanup"
print_status "Verifying that the service account has been removed..."
gcloud iam service-accounts list --project="$PROJECT_ID" --filter="email:terraform-sa@$PROJECT_ID.iam.gserviceaccount.com" || echo -e "${GREEN}Service account successfully removed!${NC}"

print_step "Step 5.5: Optional - Remove Terraform State Bucket"
print_warning "The Terraform state bucket still exists: gs://$PROJECT_ID-tf-state"
echo -e "${YELLOW}To remove it manually, run:${NC}"
echo -e "${WHITE}gsutil rm -r gs://$PROJECT_ID-tf-state${NC}"

echo -e "\n${GREEN}✓ TASK 5 COMPLETED: Resources cleaned up successfully!${NC}"

print_success "All lab tasks completed successfully! 🎉"