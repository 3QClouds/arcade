#!/bin/bash

# Google Speech-to-Text API Lab - Complete Script
# This script automates the Speech-to-Text API testing with multiple languages

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
# TASK 1: CREATE AN API KEY
# =============================================================================
print_task "1. Create an API Key"

print_step "Step 1.1: Enable Required APIs"
print_status "Enabling Speech-to-Text API and API Keys API..."
gcloud services enable speech.googleapis.com
gcloud services enable apikeys.googleapis.com
print_success "APIs enabled successfully!"

print_step "Step 1.2: Find VM Instance"
print_status "Looking for linux-instance VM..."
VM_INSTANCE=$(gcloud compute instances list --format="value(name)" --filter="name:linux-instance")

if [ -z "$VM_INSTANCE" ]; then
    print_warning "linux-instance not found, creating one..."
    gcloud compute instances create linux-instance \
        --zone=$ZONE \
        --machine-type=e2-micro \
        --image-family=debian-11 \
        --image-project=debian-cloud \
        --boot-disk-size=10GB \
        --boot-disk-type=pd-standard
    print_success "linux-instance created successfully!"
else
    print_success "Found existing linux-instance VM!"
fi

# Get the zone of the VM instance
export VM_ZONE=$(gcloud compute instances list linux-instance --format='csv[no-heading](zone)')
echo -e "${CYAN}VM Zone: ${WHITE}$VM_ZONE${NC}"

echo -e "\n${GREEN}✓ TASK 1 COMPLETED: Environment prepared!${NC}"

# =============================================================================
# TASK 2: CREATE API REQUEST AND CALL API
# =============================================================================
print_task "2. Create API Request and Call API"

print_step "Step 2.1: Create Script for English Audio Processing"
print_status "Creating script for English audio API call..."

cat > prepare_english.sh <<'EOF_END'
cd /home/$(whoami)
echo "Working directory: $(pwd)"

echo "Creating API key..."
gcloud alpha services api-keys create --display-name="quicklab" 
KEY=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=quicklab")
API_KEY=$(gcloud alpha services api-keys get-key-string $KEY --format="value(keyString)")

echo "API Key created: ${API_KEY:0:20}..."

echo "Creating request.json for English audio..."
cat > request.json <<EOF
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "en-US"
  },
  "audio": {
      "uri":"gs://cloud-samples-data/speech/brooklyn_bridge.flac"
  }
}
EOF

echo "Request file created:"
cat request.json

echo "Calling Speech-to-Text API for English..."
curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json

echo "English API Response:"
cat result.json

echo "Files in current directory:"
ls -la *.json

echo "Setting proper permissions..."
chmod 644 request.json result.json
EOF_END

print_step "Step 2.2: Execute English Audio Processing on VM"
print_status "Copying script to VM and executing..."

gcloud compute scp prepare_english.sh linux-instance:/tmp --project=$PROJECT_ID --zone=$VM_ZONE --quiet
gcloud compute ssh linux-instance --project=$PROJECT_ID --zone=$VM_ZONE --quiet --command="bash /tmp/prepare_english.sh"

print_success "English audio processing completed!"

echo -e "\n${GREEN}✓ TASK 2 COMPLETED: English Speech-to-Text API called successfully!${NC}"

# =============================================================================
# TASK 3: SPEECH-TO-TEXT TRANSCRIPTION IN DIFFERENT LANGUAGES
# =============================================================================
print_task "3. Speech-to-Text Transcription in Different Languages"

print_step "Step 3.1: Create Script for French Audio Processing"
print_status "Creating script for French audio API call..."

cat > prepare_french.sh <<'EOF_END'
cd /home/$(whoami)
echo "Working directory: $(pwd)"

echo "Getting existing API key..."
KEY=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=quicklab")
API_KEY=$(gcloud alpha services api-keys get-key-string $KEY --format="value(keyString)")

echo "Using API Key: ${API_KEY:0:20}..."

echo "Creating request.json for French audio..."
rm -f request.json
cat > request.json <<EOF
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "fr"
  },
  "audio": {
      "uri":"gs://cloud-samples-data/speech/corbeau_renard.flac"
  }
}
EOF

echo "French request file created:"
cat request.json

echo "Calling Speech-to-Text API for French..."
curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json

echo "French API Response:"
cat result.json

echo "Files in current directory:"
ls -la *.json

echo "Setting proper permissions..."
chmod 644 request.json result.json
EOF_END

print_step "Step 3.2: Execute French Audio Processing on VM"
print_status "Copying script to VM and executing..."

gcloud compute scp prepare_french.sh linux-instance:/tmp --project=$PROJECT_ID --zone=$VM_ZONE --quiet
gcloud compute ssh linux-instance --project=$PROJECT_ID --zone=$VM_ZONE --quiet --command="bash /tmp/prepare_french.sh"

print_success "French audio processing completed!"

print_step "Step 3.3: Display Lab Summary"
print_status "Displaying lab completion summary..."

echo -e "\n${CYAN}Lab Summary:${NC}"
echo -e "${WHITE}✓ API Key: Created automatically on VM${NC}"
echo -e "${WHITE}✓ VM Instance: linux-instance (in zone $VM_ZONE)${NC}"
echo -e "${WHITE}✓ English Audio: brooklyn_bridge.flac processed${NC}"
echo -e "${WHITE}✓ French Audio: corbeau_renard.flac processed${NC}"
echo -e "${WHITE}✓ Method: Script copy and execution via SSH${NC}"

echo -e "\n${CYAN}API Calls Made:${NC}"
echo -e "${WHITE}• English: gs://cloud-samples-data/speech/brooklyn_bridge.flac${NC}"
echo -e "${WHITE}• French: gs://cloud-samples-data/speech/corbeau_renard.flac${NC}"

echo -e "\n${CYAN}Key Features Demonstrated:${NC}"
echo -e "${WHITE}• Automatic API key creation${NC}"
echo -e "${WHITE}• Multi-language speech recognition${NC}"
echo -e "${WHITE}• Script deployment to VM${NC}"
echo -e "${WHITE}• JSON request/response handling${NC}"

echo -e "\n${GREEN}✓ TASK 3 COMPLETED: Multi-language transcription demonstrated!${NC}"

print_success "All lab tasks completed successfully! 🎉"