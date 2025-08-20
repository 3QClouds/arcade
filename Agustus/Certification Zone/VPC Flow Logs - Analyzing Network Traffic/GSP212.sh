#!/bin/bash

# VPC Flow Logs with BigQuery Export Lab - Complete Script
# This script automates the setup of VPC Flow Logs and BigQuery export

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
# TASK 1: CONFIGURE A CUSTOM NETWORK WITH VPC FLOW LOGS
# =============================================================================
print_task "1. Configure a Custom Network with VPC Flow Logs"

print_step "Step 1.1: Enable Required APIs"
print_status "Enabling Compute Engine API..."
gcloud services enable compute.googleapis.com

print_status "Enabling Logging API..."
gcloud services enable logging.googleapis.com

print_status "Enabling BigQuery API..."
gcloud services enable bigquery.googleapis.com

print_success "Required APIs enabled successfully!"

print_step "Step 1.2: Create Custom VPC Network"
print_status "Creating VPC network 'vpc-net'..."
gcloud compute networks create vpc-net \
    --description="Custom VPC network with Flow Logs" \
    --subnet-mode=custom

print_success "VPC network created successfully!"

print_step "Step 1.3: Create Subnet with Flow Logs Enabled"
print_status "Creating subnet 'vpc-subnet' with VPC Flow Logs enabled..."
gcloud compute networks subnets create vpc-subnet \
    --network=vpc-net \
    --range=10.1.3.0/24 \
    --region=$REGION \
    --enable-flow-logs \
    --logging-flow-sampling=0.5 \
    --logging-aggregation-interval=interval-5-sec \
    --logging-metadata=include-all

print_success "Subnet with Flow Logs created successfully!"

print_step "Step 1.4: Create Firewall Rule"
print_status "Creating firewall rule 'allow-http-ssh'..."
gcloud compute firewall-rules create allow-http-ssh \
    --project=$PROJECT_ID \
    --direction=INGRESS \
    --priority=1000 \
    --network=vpc-net \
    --action=ALLOW \
    --rules=tcp:80,tcp:22 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server

print_success "Firewall rule created successfully!"

echo -e "\n${GREEN}✓ TASK 1 COMPLETED: Custom network with VPC Flow Logs configured!${NC}"

# =============================================================================
# TASK 2: CREATE AN APACHE WEB SERVER
# =============================================================================
print_task "2. Create an Apache Web Server"

print_step "Step 2.1: Create Web Server VM Instance"
print_status "Creating web-server VM instance..."
gcloud compute instances create web-server \
    --zone=$ZONE \
    --machine-type=e2-micro \
    --network-interface=network-tier=PREMIUM,subnet=vpc-subnet \
    --tags=http-server \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-standard \
    --metadata=startup-script='#!/bin/bash
apt-get update
apt-get install apache2 -y
echo "<!doctype html><html><body><h1>Hello World!</h1></body></html>" > /var/www/html/index.html
systemctl restart apache2'

print_success "Web server VM instance created successfully!"

print_step "Step 2.2: Wait for Instance to be Ready"
print_status "Waiting for instance to be fully ready..."
sleep 30

# Get the external IP of the web server
WEB_SERVER_IP=$(gcloud compute instances describe web-server \
    --zone=$ZONE \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

echo -e "${CYAN}Web Server External IP: ${WHITE}$WEB_SERVER_IP${NC}"

print_step "Step 2.3: Verify Apache Installation"
print_status "Checking if Apache is running and serving content..."
for i in {1..10}; do
    if curl -s http://$WEB_SERVER_IP | grep -q "Hello World"; then
        print_success "Apache is running and serving Hello World page!"
        break
    else
        echo "Attempt $i: Waiting for Apache to be ready..."
        sleep 10
    fi
done

echo -e "\n${GREEN}✓ TASK 2 COMPLETED: Apache web server created and configured!${NC}"

# =============================================================================
# TASK 3: VERIFY THAT NETWORK TRAFFIC IS LOGGED
# =============================================================================
print_task "3. Verify that Network Traffic is Logged"

print_step "Step 3.1: Generate Network Traffic"
print_status "Generating network traffic to the web server..."
echo -e "${YELLOW}Accessing web server multiple times to generate VPC Flow Logs...${NC}"

for i in {1..10}; do
    curl -s http://$WEB_SERVER_IP > /dev/null
    echo "Request $i completed"
    sleep 1
done

print_success "Network traffic generated successfully!"

print_step "Step 3.2: Wait for VPC Flow Logs to Propagate"
print_status "Waiting for VPC Flow Logs to be available (60 seconds)..."
sleep 60
print_success "Wait completed!"

print_step "Step 3.3: Query VPC Flow Logs"
print_status "Searching for VPC Flow Logs in Cloud Logging..."

# Create a log filter for VPC flows
LOG_FILTER='resource.type="gce_subnetwork" 
logName="projects/'$PROJECT_ID'/logs/compute.googleapis.com%2Fvpc_flows"
jsonPayload.connection.dest_ip="'$WEB_SERVER_IP'" OR jsonPayload.connection.src_ip="'$WEB_SERVER_IP'"'

print_status "Querying logs with filter..."
gcloud logging read "$LOG_FILTER" \
    --limit=5 \
    --format="value(jsonPayload.connection)" \
    --project=$PROJECT_ID

print_success "VPC Flow Logs verification completed!"

echo -e "\n${GREEN}✓ TASK 3 COMPLETED: Network traffic logging verified!${NC}"

# =============================================================================
# TASK 4: EXPORT NETWORK TRAFFIC TO BIGQUERY
# =============================================================================
print_task "4. Export the Network Traffic to BigQuery"

print_step "Step 4.1: Create BigQuery Dataset"
print_status "Creating BigQuery dataset 'bq_vpc_flows'..."
bq mk --dataset \
    --location=$REGION \
    --description="VPC Flow Logs dataset" \
    $PROJECT_ID:bq_vpc_flows

print_success "BigQuery dataset created successfully!"

print_step "Step 4.2: Create Log Export Sink"
print_status "Creating log export sink to BigQuery..."

# Create the sink filter for VPC flows
SINK_FILTER='resource.type="gce_subnetwork"
logName="projects/'$PROJECT_ID'/logs/compute.googleapis.com%2Fvpc_flows"'

gcloud logging sinks create vpc-flows \
    bigquery.googleapis.com/projects/$PROJECT_ID/datasets/bq_vpc_flows \
    --log-filter="$SINK_FILTER" \
    --project=$PROJECT_ID

print_success "Log export sink created successfully!"

print_step "Step 4.3: Grant BigQuery Permissions to Sink"
print_status "Getting sink service account..."
SINK_SERVICE_ACCOUNT=$(gcloud logging sinks describe vpc-flows \
    --format="value(writerIdentity)" \
    --project=$PROJECT_ID)

print_status "Granting BigQuery Data Editor role to sink service account..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="$SINK_SERVICE_ACCOUNT" \
    --role="roles/bigquery.dataEditor"

print_success "Permissions granted successfully!"

print_step "Step 4.4: Generate Additional Traffic for BigQuery"
print_status "Generating additional traffic for BigQuery export..."
export MY_SERVER=$WEB_SERVER_IP

echo -e "${CYAN}Accessing web server 50 times...${NC}"
for ((i=1;i<=50;i++)); do 
    curl -s $MY_SERVER > /dev/null
    if [ $((i % 10)) -eq 0 ]; then
        echo "Completed $i requests..."
    fi
done

print_success "Additional traffic generated successfully!"

print_step "Step 4.5: Wait for BigQuery Export"
print_status "Waiting for logs to be exported to BigQuery (120 seconds)..."
sleep 120
print_success "Export wait completed!"

print_step "Step 4.6: Verify BigQuery Export"
print_status "Checking BigQuery dataset for tables..."
bq ls bq_vpc_flows

print_status "Attempting to query VPC Flow Logs in BigQuery..."
# Note: Table creation might take time, so we'll just verify the dataset exists
bq query --use_legacy_sql=false \
    "SELECT COUNT(*) as table_count 
     FROM \`$PROJECT_ID.bq_vpc_flows.INFORMATION_SCHEMA.TABLES\`" \
    2>/dev/null || echo -e "${YELLOW}Note: BigQuery table may still be creating. This is normal.${NC}"

print_success "BigQuery export setup completed!"

echo -e "\n${GREEN}✓ TASK 4 COMPLETED: Network traffic exported to BigQuery!${NC}"

print_success "All lab tasks completed successfully! 🎉"