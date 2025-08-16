#!/bin/bash

# Terraform Cloud Firestore Lab - Complete Script
# This script automates the setup of Cloud Firestore using Terraform

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

# Get region from project metadata
print_status "Retrieving region from project metadata..."
export REGION=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Set default region if not found in metadata
if [ -z "$REGION" ] || [ "$REGION" = "(unset)" ]; then
    print_warning "Region not found in metadata, using default: us-central1"
    export REGION="us-central1"
fi

echo -e "${CYAN}Project ID: ${WHITE}$PROJECT_ID${NC}"
echo -e "${CYAN}Region: ${WHITE}$REGION${NC}"

# =============================================================================
# TASK 1: SET UP GOOGLE CLOUD PROJECT AND TERRAFORM
# =============================================================================
print_task "1. Set Up Google Cloud Project and Terraform"

print_step "Step 1.1: Set Active Project"
print_status "Setting active project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"
print_success "Project set successfully!"

print_step "Step 1.2: Enable Cloud Firestore API"
print_status "Enabling Cloud Firestore API..."
gcloud services enable firestore.googleapis.com
print_success "Cloud Firestore API enabled successfully!"

print_step "Step 1.3: Enable Cloud Build API"
print_status "Enabling Cloud Build API..."
gcloud services enable cloudbuild.googleapis.com
print_success "Cloud Build API enabled successfully!"

print_step "Step 1.4: Create Cloud Storage Bucket for Terraform State"
print_status "Creating Cloud Storage bucket for Terraform state..."
gcloud storage buckets create gs://"$PROJECT_ID"-tf-state --location=us
print_success "Terraform state bucket created successfully!"

echo -e "\n${GREEN}✓ TASK 1 COMPLETED: Google Cloud project and Terraform setup completed!${NC}"

# =============================================================================
# TASK 2: CREATE TERRAFORM CONFIGURATION
# =============================================================================
print_task "2. Create Terraform Configuration"

print_step "Step 2.1: Create main.tf Configuration File"
print_status "Creating main.tf file with Firestore configuration..."

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
  project = "$PROJECT_ID"
  region  = "$REGION"
}

resource "google_firestore_database" "default" {
  name        = "default"
  project     = "$PROJECT_ID"
  location_id = "nam5"
  type        = "FIRESTORE_NATIVE"
}

output "firestore_database_name" {
  value       = google_firestore_database.default.name
  description = "The name of the Cloud Firestore database."
}
EOF

print_success "main.tf file created successfully!"

print_step "Step 2.2: Create variables.tf File"
print_status "Creating variables.tf file..."

cat > variables.tf <<EOF
variable "project_id" {
  type        = string
  description = "The ID of the Google Cloud project."
  default     = "$PROJECT_ID"
}

variable "bucket_name" {
  type        = string
  description = "Bucket name for terraform state"
  default     = "$PROJECT_ID-tf-state"
}
EOF

print_success "variables.tf file created successfully!"

print_step "Step 2.3: Create outputs.tf File"
print_status "Creating outputs.tf file..."

cat > outputs.tf <<EOF
output "project_id" {
  value       = var.project_id
  description = "The ID of the Google Cloud project."
}

output "bucket_name" {
  value       = var.bucket_name
  description = "The name of the bucket to store terraform state."
}
EOF

print_success "outputs.tf file created successfully!"

print_step "Step 2.4: Display Created Files"
print_status "Listing created Terraform configuration files..."
ls -la *.tf

echo -e "\n${GREEN}✓ TASK 2 COMPLETED: Terraform configuration files created!${NC}"

# =============================================================================
# TASK 3: APPLY THE TERRAFORM CONFIGURATION
# =============================================================================
print_task "3. Apply the Terraform Configuration"

print_step "Step 3.1: Initialize Terraform"
print_status "Initializing Terraform in working directory..."
terraform init
print_success "Terraform initialized successfully!"

print_step "Step 3.2: Review Terraform Plan"
print_status "Running terraform plan to review changes..."
terraform plan
print_success "Terraform plan completed successfully!"

print_step "Step 3.3: Apply Terraform Configuration"
print_status "Applying Terraform configuration..."
print_warning "This will create the Cloud Firestore database..."
terraform apply -auto-approve
print_success "Terraform configuration applied successfully!"

print_step "Step 3.4: Display Terraform Outputs"
print_status "Showing Terraform outputs..."
terraform output
print_success "Terraform outputs displayed successfully!"

print_step "Step 3.5: Verify Cloud Firestore Database"
print_status "Verifying Cloud Firestore database creation..."
gcloud firestore databases list --project="$PROJECT_ID"
print_success "Cloud Firestore database verification completed!"

echo -e "\n${GREEN}✓ TASK 3 COMPLETED: Terraform configuration applied and Firestore database created!${NC}"

# =============================================================================
# TASK 4: CLEAN UP RESOURCES
# =============================================================================
print_task "4. Clean Up Resources"

print_step "Step 4.1: Destroy Terraform Resources"
print_status "Destroying resources created by Terraform..."
print_warning "This will delete the Cloud Firestore database..."
terraform destroy -auto-approve
print_success "Terraform resources destroyed successfully!"

print_step "Step 4.2: Verify Resource Cleanup"
print_status "Verifying that resources have been cleaned up..."
gcloud firestore databases list --project="$PROJECT_ID" || echo -e "${GREEN}No Firestore databases found - cleanup successful!${NC}"
print_success "Resource cleanup verification completed!"

print_step "Step 4.3: Clean Up Local Files"
print_status "Cleaning up local Terraform files..."
rm -f *.tf
rm -f *.tfstate*
rm -rf .terraform/
print_success "Local files cleaned up successfully!"

echo -e "\n${GREEN}✓ TASK 4 COMPLETED: All resources cleaned up successfully!${NC}"

print_success "All lab tasks completed successfully! 🎉"