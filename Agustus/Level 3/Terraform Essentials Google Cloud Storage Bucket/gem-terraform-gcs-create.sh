#!/bin/bash

# Terraform with Google Cloud Storage State Backend Lab - Complete Script
# This script automates the setup of Terraform with GCS backend for state management

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
# TASK 1: CONFIGURE GOOGLE CLOUD SDK
# =============================================================================
print_task "1. Configure Google Cloud SDK"

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

print_step "Step 1.4: Verify Configuration"
print_status "Verifying gcloud configuration..."
echo -e "${YELLOW}Current gcloud configuration:${NC}"
gcloud config list
print_success "Google Cloud SDK configuration completed!"

echo -e "\n${GREEN}✓ TASK 1 COMPLETED: Google Cloud SDK configured successfully!${NC}"

# =============================================================================
# TASK 2: CREATE CLOUD STORAGE BUCKET FOR TERRAFORM STATE
# =============================================================================
print_task "2. Create Cloud Storage Bucket for Terraform State"

print_step "Step 2.1: Create Terraform State Bucket"
print_status "Creating Cloud Storage bucket for Terraform state..."
BUCKET_NAME="$PROJECT_ID-tf-state"
echo -e "${CYAN}Bucket Name: ${WHITE}$BUCKET_NAME${NC}"

gcloud storage buckets create gs://"$PROJECT_ID"-tf-state \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --uniform-bucket-level-access

print_success "Terraform state bucket created successfully!"

print_step "Step 2.2: Enable Versioning on State Bucket"
print_status "Enabling object versioning on the state bucket..."
gsutil versioning set on gs://"$PROJECT_ID"-tf-state
print_success "Object versioning enabled successfully!"

print_step "Step 2.3: Verify State Bucket"
print_status "Verifying state bucket creation..."
gsutil ls gs://"$PROJECT_ID"-tf-state
echo -e "${CYAN}State bucket gs://$PROJECT_ID-tf-state is ready for use${NC}"

echo -e "\n${GREEN}✓ TASK 2 COMPLETED: Terraform state bucket created and configured!${NC}"

# =============================================================================
# TASK 3: CREATE A TERRAFORM CONFIGURATION FILE
# =============================================================================
print_task "3. Create a Terraform Configuration File"

print_step "Step 3.1: Create Terraform Directory"
print_status "Creating terraform-gcs directory..."
mkdir -p terraform-gcs
cd terraform-gcs
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
  project = "$PROJECT_ID"
  region  = "$REGION"
}

resource "google_storage_bucket" "default" {
  name          = "$PROJECT_ID-my-terraform-bucket"
  location      = "$REGION"
  force_destroy = true

  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
}
EOF

print_success "main.tf configuration file created successfully!"

print_step "Step 3.3: Display Terraform Configuration"
print_status "Displaying the created Terraform configuration..."
echo -e "${YELLOW}Contents of main.tf:${NC}"
cat main.tf

echo -e "\n${GREEN}✓ TASK 3 COMPLETED: Terraform configuration file created!${NC}"

# =============================================================================
# TASK 4: INITIALIZE TERRAFORM
# =============================================================================
print_task "4. Initialize Terraform"

print_step "Step 4.1: Initialize Terraform"
print_status "Running terraform init to initialize Terraform..."
terraform init
print_success "Terraform initialized successfully!"

print_step "Step 4.2: Plan Terraform Changes"
print_status "Running terraform plan to review planned changes..."
echo -e "${YELLOW}Terraform will show what resources will be created:${NC}"
terraform plan
print_success "Terraform plan completed successfully!"

print_step "Step 4.3: Apply Terraform Configuration"
print_status "Running terraform apply to create resources..."
terraform apply -auto-approve
print_success "Terraform apply completed successfully!"

print_step "Step 4.4: Display Terraform State"
print_status "Displaying current Terraform state..."
terraform show
print_success "Terraform state displayed successfully!"

echo -e "\n${GREEN}✓ TASK 4 COMPLETED: Terraform initialized and resources created!${NC}"

# =============================================================================
# TASK 5: VERIFY BUCKET CREATION
# =============================================================================
print_task "5. Verify Bucket Creation"

print_step "Step 5.1: Verify Terraform-Created Bucket"
print_status "Verifying that the Terraform-managed bucket was created..."
TERRAFORM_BUCKET="$PROJECT_ID-my-terraform-bucket"
echo -e "${CYAN}Terraform Bucket Name: ${WHITE}$TERRAFORM_BUCKET${NC}"

gsutil ls gs://"$PROJECT_ID"-my-terraform-bucket
print_success "Terraform-managed bucket verified successfully!"

print_step "Step 5.2: List All Project Buckets"
print_status "Listing all Cloud Storage buckets in the project..."
echo -e "${YELLOW}All buckets in project $PROJECT_ID:${NC}"
gsutil ls

print_step "Step 5.3: Verify State Storage"
print_status "Checking Terraform state in the backend bucket..."
echo -e "${YELLOW}Contents of state bucket:${NC}"
gsutil ls gs://"$PROJECT_ID"-tf-state/terraform/

print_step "Step 5.4: Display Bucket Details"
print_status "Displaying details of the Terraform-managed bucket..."
gsutil ls -L gs://"$PROJECT_ID"-my-terraform-bucket

print_step "Step 5.5: Configuration Summary"
print_status "Displaying final configuration summary..."

echo -e "\n${CYAN}Created Resources:${NC}"
echo -e "${WHITE}• State Bucket: gs://$PROJECT_ID-tf-state${NC}"
echo -e "${WHITE}• Terraform-Managed Bucket: gs://$PROJECT_ID-my-terraform-bucket${NC}"
echo -e "${WHITE}• Terraform Configuration: ./terraform-gcs/main.tf${NC}"

echo -e "\n${CYAN}Key Features Configured:${NC}"
echo -e "${WHITE}• Remote State Backend: GCS bucket with versioning${NC}"
echo -e "${WHITE}• Terraform Provider: Google Cloud Platform${NC}"
echo -e "${WHITE}• Resource Management: Cloud Storage bucket with versioning${NC}"

echo -e "\n${CYAN}Terraform Workflow Demonstrated:${NC}"
echo -e "${WHITE}• terraform init: Initialize and configure backend${NC}"
echo -e "${WHITE}• terraform plan: Preview changes${NC}"
echo -e "${WHITE}• terraform apply: Create resources${NC}"
echo -e "${WHITE}• terraform show: Display current state${NC}"

echo -e "\n${GREEN}✓ TASK 5 COMPLETED: All resources verified successfully!${NC}"

print_success "All lab tasks completed successfully! 🎉"

print_step "Additional Information"
echo -e "${CYAN}You can now:${NC}"
echo -e "${WHITE}• Modify main.tf to add more resources${NC}"
echo -e "${WHITE}• Run 'terraform plan' to see changes${NC}"
echo -e "${WHITE}• Run 'terraform apply' to apply changes${NC}"
echo -e "${WHITE}• Run 'terraform destroy' to clean up resources${NC}"
echo -e "${WHITE}• Check the state bucket for collaboration${NC}"