#!/bin/bash

# Terraform GCE Instance Lab - Complete Script
# This script automates the creation of GCE instances using Terraform

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
# TASK 1: PREREQUISITES
# =============================================================================
print_task "1. Prerequisites"

print_step "Step 1.1: Verify Terraform Installation"
print_status "Checking Terraform version..."
terraform version
print_success "Terraform verification completed!"

print_step "Step 1.2: Verify Google Cloud SDK"
print_status "Checking gcloud version..."
gcloud version
print_success "Google Cloud SDK verification completed!"

print_step "Step 1.3: Authenticate to Google Cloud"
print_status "Checking authentication status..."
gcloud auth list
print_success "Authentication verification completed!"

print_step "Step 1.4: Set Active Project"
print_status "Setting active project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"
print_success "Project set successfully!"

echo -e "\n${GREEN}✓ TASK 1 COMPLETED: Prerequisites verified!${NC}"

# =============================================================================
# TASK 2: CREATE CLOUD STORAGE BUCKET FOR TERRAFORM STATE
# =============================================================================
print_task "2. Create a Cloud Storage Bucket for Terraform State"

print_step "Step 2.1: Create Cloud Storage Bucket"
print_status "Creating Cloud Storage bucket for Terraform state..."
gsutil mb -l "$REGION" gs://"$PROJECT_ID"-tf-state
print_success "Cloud Storage bucket created successfully!"

print_step "Step 2.2: Enable Versioning on Bucket"
print_status "Enabling versioning on the bucket..."
gsutil versioning set on gs://"$PROJECT_ID"-tf-state
print_success "Versioning enabled successfully!"

print_step "Step 2.3: Verify Bucket Creation"
print_status "Verifying bucket configuration..."
gsutil ls -L gs://"$PROJECT_ID"-tf-state
print_success "Bucket verification completed!"

echo -e "\n${GREEN}✓ TASK 2 COMPLETED: Terraform state bucket created and configured!${NC}"

# =============================================================================
# TASK 3: CREATE TERRAFORM CONFIGURATION FILES
# =============================================================================
print_task "3. Create Terraform Configuration Files"

print_step "Step 3.1: Create main.tf Configuration File"
print_status "Creating main.tf file with GCE instance configuration..."

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

resource "google_compute_instance" "default" {
  name         = "terraform-instance"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = "default"

    access_config {
    }
  }
}
EOF

print_success "main.tf file created successfully!"

print_step "Step 3.2: Create variables.tf File"
print_status "Creating variables.tf file..."

cat > variables.tf <<EOF
variable "project_id" {
  type        = string
  description = "The ID of the Google Cloud project"
  default     = "$PROJECT_ID"
}

variable "region" {
  type        = string
  description = "The region to deploy resources in"
  default     = "$REGION"
}

variable "zone" {
  type        = string
  description = "The zone to deploy resources in"
  default     = "$ZONE"
}
EOF

print_success "variables.tf file created successfully!"

print_step "Step 3.3: Display Created Files"
print_status "Listing created Terraform configuration files..."
ls -la *.tf
echo -e "\n${YELLOW}Contents of main.tf:${NC}"
head -10 main.tf
echo -e "\n${YELLOW}Contents of variables.tf:${NC}"
cat variables.tf

echo -e "\n${GREEN}✓ TASK 3 COMPLETED: Terraform configuration files created!${NC}"

# =============================================================================
# TASK 4: INITIALIZE, PLAN, AND APPLY TERRAFORM
# =============================================================================
print_task "4. Initialize, Plan, and Apply Terraform"

print_step "Step 4.1: Initialize Terraform"
print_status "Initializing Terraform in working directory..."
terraform init
print_success "Terraform initialized successfully!"

print_step "Step 4.2: Plan Terraform Changes"
print_status "Running terraform plan to review changes..."
terraform plan
print_success "Terraform plan completed successfully!"

print_step "Step 4.3: Apply Terraform Configuration"
print_status "Applying Terraform configuration to create GCE instance..."
print_warning "This will create a GCE instance..."
terraform apply -auto-approve
print_success "Terraform configuration applied successfully!"

print_step "Step 4.4: Display Terraform State"
print_status "Showing current Terraform state..."
terraform show
print_success "Terraform state displayed successfully!"

echo -e "\n${GREEN}✓ TASK 4 COMPLETED: GCE instance created using Terraform!${NC}"

# =============================================================================
# TASK 5: VERIFY THE INSTANCE
# =============================================================================
print_task "5. Verify the Instance"

print_step "Step 5.1: List GCE Instances"
print_status "Listing all GCE instances..."
gcloud compute instances list
print_success "Instance listing completed!"

print_step "Step 5.2: Get Instance Details"
print_status "Getting details of terraform-instance..."
gcloud compute instances describe terraform-instance --zone="$ZONE"
print_success "Instance details retrieved successfully!"

print_step "Step 5.3: Verify Instance Status"
print_status "Checking instance status..."
INSTANCE_STATUS=$(gcloud compute instances describe terraform-instance --zone="$ZONE" --format="value(status)")
echo -e "${CYAN}Instance Status: ${WHITE}$INSTANCE_STATUS${NC}"

if [ "$INSTANCE_STATUS" = "RUNNING" ]; then
    print_success "Instance is running successfully!"
else
    print_warning "Instance status: $INSTANCE_STATUS"
fi

echo -e "\n${GREEN}✓ TASK 5 COMPLETED: Instance verification completed!${NC}"

# =============================================================================
# TASK 6: DESTROY THE INFRASTRUCTURE
# =============================================================================
print_task "6. Destroy the Infrastructure"

print_step "Step 6.1: Destroy Terraform Resources"
print_status "Destroying resources created by Terraform..."
print_warning "This will delete the GCE instance..."
terraform destroy -auto-approve
print_success "Terraform resources destroyed successfully!"

print_step "Step 6.2: Verify Resource Cleanup"
print_status "Verifying that instance has been destroyed..."
gcloud compute instances list --filter="name:terraform-instance" || echo -e "${GREEN}No terraform-instance found - cleanup successful!${NC}"
print_success "Resource cleanup verification completed!"

print_step "Step 6.3: Clean Up Local Files"
print_status "Cleaning up local Terraform files..."
echo -e "${YELLOW}Local files before cleanup:${NC}"
ls -la

print_status "Removing Terraform files..."
rm -f *.tf
rm -f *.tfstate*
rm -rf .terraform/
rm -f .terraform.lock.hcl

echo -e "${YELLOW}Local files after cleanup:${NC}"
ls -la

print_success "Local files cleaned up successfully!"

print_step "Step 6.4: Optional - Clean Up State Bucket"
print_warning "The Terraform state bucket gs://$PROJECT_ID-tf-state still exists."
echo -e "${CYAN}To remove it completely, run:${NC}"
echo -e "${WHITE}gsutil rm -r gs://$PROJECT_ID-tf-state${NC}"
echo -e "${YELLOW}(This is optional - you may want to keep it for future Terraform projects)${NC}"

echo -e "\n${GREEN}✓ TASK 6 COMPLETED: Infrastructure destroyed and cleaned up!${NC}"

print_success "All lab tasks completed successfully! 🎉"