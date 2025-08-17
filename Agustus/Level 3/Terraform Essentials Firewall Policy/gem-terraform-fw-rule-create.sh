#!/bin/bash

# Terraform Firewall Configuration Lab - Complete Script
# This script automates the Terraform setup for firewall rules

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
export ZONE=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])")
export PROJECT_ID=$(gcloud config get-value project)

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
# TASK 1: CREATE CLOUD STORAGE BUCKET FOR TERRAFORM STATE
# =============================================================================
print_task "1. Create Cloud Storage Bucket for Terraform State"

print_step "Step 1.1: Create Terraform State Bucket"
print_status "Creating Cloud Storage bucket: $PROJECT_ID-tf-state"
gcloud storage buckets create gs://$PROJECT_ID-tf-state \
    --project=$PROJECT_ID \
    --location=$REGION \
    --uniform-bucket-level-access

print_success "Terraform state bucket created successfully!"

print_step "Step 1.2: Enable Bucket Versioning"
print_status "Enabling versioning on the bucket..."
gsutil versioning set on gs://$PROJECT_ID-tf-state

print_success "Bucket versioning enabled successfully!"

echo -e "\n${GREEN}✓ TASK 1 COMPLETED: Terraform state bucket ready!${NC}"

# =============================================================================
# TASK 2: DEFINING THE FIREWALL RULE IN TERRAFORM
# =============================================================================
print_task "2. Defining the Firewall Rule in Terraform"

print_step "Step 2.1: Create Terraform Configuration Files"
print_status "Creating firewall.tf file..."

cat > firewall.tf <<EOF_END
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-from-anywhere"
  network = "default"
  project = "$PROJECT_ID"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-allowed"]
}
EOF_END

print_success "firewall.tf created successfully!"

print_status "Creating variables.tf file..."

cat > variables.tf <<EOF_END
variable "project_id" {
  type        = string
  default     = "$PROJECT_ID"
}

variable "bucket_name" {
  type = string
  default = "$PROJECT_ID-tf-state"
}

variable "region" {
  type = string
  default = "$REGION"
}
EOF_END

print_success "variables.tf created successfully!"

print_status "Creating outputs.tf file..."

cat > outputs.tf <<EOF_END
output "firewall_name" {
  value = google_compute_firewall.allow_ssh.name
}
EOF_END

print_success "outputs.tf created successfully!"

echo -e "\n${GREEN}✓ TASK 2 COMPLETED: Terraform configuration defined!${NC}"

# =============================================================================
# TASK 3: APPLYING THE TERRAFORM CONFIGURATION
# =============================================================================
print_task "3. Applying the Terraform Configuration"

print_step "Step 3.1: Initialize Terraform"
print_status "Running terraform init..."
terraform init

print_success "Terraform initialized successfully!"

print_step "Step 3.2: Plan Terraform Changes"
print_status "Running terraform plan..."
terraform plan

print_success "Terraform plan completed successfully!"

print_step "Step 3.3: Apply Terraform Configuration"
print_status "Running terraform apply with auto-approve..."
terraform apply --auto-approve

print_success "Terraform configuration applied successfully!"

echo -e "\n${GREEN}✓ TASK 3 COMPLETED: Firewall rule created successfully!${NC}"

print_success "Lab completed successfully!"

print_success "All lab tasks completed successfully! 🎉"