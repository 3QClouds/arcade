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

print_step "Step 1.1: Set Project Configuration"
print_status "Setting project ID..."
gcloud config set project "$PROJECT_ID"
echo -e "${CYAN}Active project set to: ${WHITE}$PROJECT_ID${NC}"

print_status "Setting default region..."
gcloud config set compute/region "$REGION"
echo -e "${CYAN}Default region set to: ${WHITE}$REGION${NC}"

print_status "Setting default zone..."
gcloud config set compute/zone "$ZONE"
echo -e "${CYAN}Default zone set to: ${WHITE}$ZONE${NC}"

print_step "Step 1.2: Enable Required APIs"
print_status "Enabling IAM API..."
gcloud services enable iam.googleapis.com

print_status "Enabling Compute Engine API..."
gcloud services enable compute.googleapis.com

print_success "Google Cloud project configured successfully!"

echo -e "\n${GREEN}✓ TASK 1 COMPLETED: Project configuration finished!${NC}"

# =============================================================================
# TASK 2: CREATE CLOUD STORAGE BUCKET FOR TERRAFORM STATE
# =============================================================================
print_task "2. Create a Cloud Storage Bucket for Terraform State"

print_step "Step 2.1: Create Terraform State Bucket"
BUCKET_NAME="$PROJECT_ID-tf-state"
print_status "Creating Cloud Storage bucket: $BUCKET_NAME"

gcloud storage buckets create gs://"$BUCKET_NAME" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --uniform-bucket-level-access

print_success "Terraform state bucket created successfully!"

print_step "Step 2.2: Enable Bucket Versioning"
print_status "Enabling versioning on the bucket..."
gsutil versioning set on gs://"$BUCKET_NAME"

print_success "Bucket versioning enabled successfully!"

echo -e "\n${GREEN}✓ TASK 2 COMPLETED: Terraform state bucket ready!${NC}"

# =============================================================================
# TASK 3: DEFINING THE FIREWALL RULE IN TERRAFORM
# =============================================================================
print_task "3. Defining the Firewall Rule in Terraform"

print_step "Step 3.1: Create Terraform Directory"
print_status "Creating terraform-firewall directory..."
mkdir -p terraform-firewall
cd terraform-firewall

print_success "Terraform directory created and active!"

print_step "Step 3.2: Create Terraform Configuration Files"
print_status "Creating firewall.tf file..."

cat > firewall.tf <<EOF
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
EOF

print_success "firewall.tf created successfully!"

print_status "Creating variables.tf file..."

cat > variables.tf <<EOF
variable "project_id" {
  type = string
  default = "$PROJECT_ID"
}

variable "bucket_name" {
  type = string
  default = "$PROJECT_ID-tf-state"
}

variable "region" {
  type = string
  default = "$REGION"
}
EOF

print_success "variables.tf created successfully!"

print_status "Creating outputs.tf file..."

cat > outputs.tf <<EOF
output "firewall_name" {
  value = google_compute_firewall.allow_ssh.name
}
EOF

print_success "outputs.tf created successfully!"

print_step "Step 3.3: Create Main Terraform Configuration"
print_status "Creating main.tf with provider configuration..."

cat > main.tf <<EOF
terraform {
  required_version = ">= 0.14"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
EOF

print_success "main.tf created successfully!"

print_step "Step 3.4: Display Created Files"
print_status "Terraform configuration files created:"
ls -la *.tf

echo -e "\n${GREEN}✓ TASK 3 COMPLETED: Terraform configuration defined!${NC}"

# =============================================================================
# TASK 4: APPLYING THE TERRAFORM CONFIGURATION
# =============================================================================
print_task "4. Applying the Terraform Configuration"

print_step "Step 4.1: Initialize Terraform"
print_status "Running terraform init..."
terraform init

print_success "Terraform initialized successfully!"

print_step "Step 4.2: Plan Terraform Changes"
print_status "Running terraform plan..."
terraform plan

print_success "Terraform plan completed successfully!"

print_step "Step 4.3: Apply Terraform Configuration"
print_status "Running terraform apply..."
echo -e "${YELLOW}Automatically approving the apply...${NC}"
terraform apply -auto-approve

print_success "Terraform configuration applied successfully!"

print_step "Step 4.4: Verify Firewall Rule Creation"
print_status "Verifying firewall rule in Google Cloud..."
gcloud compute firewall-rules describe allow-ssh-from-anywhere

print_status "Listing all firewall rules containing 'ssh'..."
gcloud compute firewall-rules list --filter="name~'ssh'"

print_success "Firewall rule verification completed!"

echo -e "\n${GREEN}✓ TASK 4 COMPLETED: Firewall rule created and verified!${NC}"

# =============================================================================
# TASK 5: CLEANING UP RESOURCES
# =============================================================================
print_task "5. Cleaning Up Resources"

print_step "Step 5.1: Display Current Resources"
print_status "Showing current Terraform-managed resources..."
terraform show

print_step "Step 5.2: Plan Resource Destruction"
print_status "Planning resource destruction..."
terraform plan -destroy

print_step "Step 5.3: Destroy Resources"
print_status "Destroying Terraform-managed resources..."
echo -e "${YELLOW}Automatically approving the destruction...${NC}"
terraform destroy -auto-approve

print_success "Resources destroyed successfully!"

print_step "Step 5.4: Verify Resource Cleanup"
print_status "Verifying firewall rule has been removed..."
gcloud compute firewall-rules describe allow-ssh-from-anywhere 2>&1 || echo -e "${GREEN}Expected: Firewall rule successfully removed${NC}"

print_step "Step 5.5: Clean Up Directory"
print_status "Returning to parent directory..."
cd ..

print_warning "Terraform directory remains: terraform-firewall/"
print_warning "You can manually remove it with: rm -rf terraform-firewall/"

echo -e "\n${GREEN}✓ TASK 5 COMPLETED: Resources cleaned up successfully!${NC}"

print_success "All lab tasks completed successfully! 🎉"