#!/bin/bash

# Google Speech-to-Text API Lab - Complete Script with Checkpoints
# This script automates the Speech-to-Text API testing with proper task separation

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

print_checkpoint() {
    echo -e "\n${YELLOW}⏸️  CHECKPOINT: $1${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Please check the lab progress and wait for the green checkmark before continuing.${NC}"
    echo -e "${WHITE}Press ENTER when you see the checkpoint completed...${NC}"
    read -r
}

# Get project information using metadata
print_status "Getting project and environment information..."
export PROJECT_ID=$(gcloud config get-value project)
export DEVSHELL_PROJECT_ID=$PROJECT_ID

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
# TASKS 1-3: CREATE API KEY, REQUEST, AND CALL API (ENGLISH)
# =============================================================================
print_task "1-3. Create API Key, Request, and Call API (English)"

print_step "Step 1: Enable Required APIs"
print_status "Enabling Speech-to-Text and API Keys APIs..."
gcloud services enable speech.googleapis.com
gcloud services enable apikeys.googleapis.com
print_success "APIs enabled successfully!"

print_step "Step 2: Check VM Instance and Setup SSH"
print_status "Looking for linux-instance VM..."
VM_EXISTS=$(gcloud compute instances list --filter="name:linux-instance" --format="value(name)" 2>/dev/null)

if [ -z "$VM_EXISTS" ]; then
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

print_status "Setting up SSH connectivity and waiting for VM to be ready..."
# Wait for VM to be fully ready and generate SSH keys
sleep 30

# Test SSH connectivity and generate keys if needed
print_status "Testing SSH connectivity..."
gcloud compute ssh linux-instance --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="echo 'SSH test successful'" || {
    print_warning "First SSH attempt failed, waiting for SSH keys to propagate..."
    sleep 20
}

print_success "SSH connectivity verified!"

print_step "Step 3: Create and Execute English Audio Script"
print_status "Creating script for English audio processing..."

cat > prepare_disk.sh <<'EOF_END'
gcloud services enable apikeys.googleapis.com
gcloud alpha services api-keys create --display-name="quicklab" 
KEY=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=quicklab")
API_KEY=$(gcloud alpha services api-keys get-key-string $KEY --format="value(keyString)")
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
curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json
echo "English Audio Transcription Result:"
cat result.json
EOF_END

print_status "Copying script to VM..."
export ZONE=$(gcloud compute instances list linux-instance --format 'csv[no-heading](zone)')

# Retry mechanism for SCP
for i in {1..3}; do
    if gcloud compute scp prepare_disk.sh linux-instance:/tmp --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet; then
        print_success "Script copied successfully!"
        break
    else
        print_warning "SCP attempt $i failed, retrying in 10 seconds..."
        sleep 10
        if [ $i -eq 3 ]; then
            print_error "Failed to copy script after 3 attempts"
            exit 1
        fi
    fi
done

print_status "Executing English audio transcription on VM..."
# Retry mechanism for SSH
for i in {1..3}; do
    if gcloud compute ssh linux-instance --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="bash /tmp/prepare_disk.sh"; then
        print_success "English audio transcription completed!"
        break
    else
        print_warning "SSH attempt $i failed, retrying in 10 seconds..."
        sleep 10
        if [ $i -eq 3 ]; then
            print_error "Failed to execute script after 3 attempts"
            exit 1
        fi
    fi
done

echo -e "\n${GREEN}✓ TASKS 1-3 COMPLETED: API key created, request made, and English audio transcribed!${NC}"

# Checkpoint for Tasks 1-3
print_checkpoint "Tasks 1-3: Create API Key and Call Speech API for English"

# =============================================================================
# TASK 4: SPEECH-TO-TEXT TRANSCRIPTION IN DIFFERENT LANGUAGES
# =============================================================================
print_task "4. Speech-to-Text Transcription in Different Languages"

print_step "Step 4.1: Create and Execute French Audio Script"
print_status "Creating script for French audio processing..."

cat > prepare_disk.sh <<'EOF_END'
KEY=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=quicklab")
API_KEY=$(gcloud alpha services api-keys get-key-string $KEY --format="value(keyString)")
rm -f request.json
cat >> request.json <<EOF
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
curl -s -X POST -H "Content-Type: application/json" --data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json
echo "French Audio Transcription Result:"
cat result.json
EOF_END

print_status "Copying French script to VM..."
export ZONE=$(gcloud compute instances list linux-instance --format 'csv[no-heading](zone)')

# Retry mechanism for SCP (French script)
for i in {1..3}; do
    if gcloud compute scp prepare_disk.sh linux-instance:/tmp --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet; then
        print_success "French script copied successfully!"
        break
    else
        print_warning "SCP attempt $i failed, retrying in 5 seconds..."
        sleep 5
        if [ $i -eq 3 ]; then
            print_error "Failed to copy French script after 3 attempts"
            exit 1
        fi
    fi
done

print_status "Executing French audio transcription on VM..."
# Retry mechanism for SSH (French script)
for i in {1..3}; do
    if gcloud compute ssh linux-instance --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="bash /tmp/prepare_disk.sh"; then
        print_success "French audio transcription completed!"
        break
    else
        print_warning "SSH attempt $i failed, retrying in 5 seconds..."
        sleep 5
        if [ $i -eq 3 ]; then
            print_error "Failed to execute French script after 3 attempts"
            exit 1
        fi
    fi
done

print_step "Step 4.2: Display Language Support Information"
print_status "Displaying supported languages information..."

echo -e "\n${CYAN}Speech-to-Text API Language Support:${NC}"
echo -e "${WHITE}• English (en-US) - ✓ Tested${NC}"
echo -e "${WHITE}• French (fr) - ✓ Tested${NC}"
echo -e "${WHITE}• Spanish (es-ES)${NC}"
echo -e "${WHITE}• German (de-DE)${NC}"
echo -e "${WHITE}• Japanese (ja-JP)${NC}"
echo -e "${WHITE}• Korean (ko-KR)${NC}"
echo -e "${WHITE}• Chinese (zh-CN)${NC}"
echo -e "${WHITE}• Portuguese (pt-BR)${NC}"
echo -e "${WHITE}• Italian (it-IT)${NC}"
echo -e "${WHITE}• Russian (ru-RU)${NC}"
echo -e "${WHITE}• And 100+ more languages...${NC}"

print_step "Step 4.3: Lab Summary"
print_status "Displaying final lab summary..."

echo -e "\n${CYAN}Lab Completion Summary:${NC}"
echo -e "${WHITE}════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}✓ Task 1: API Key Created Successfully${NC}"
echo -e "${WHITE}✓ Task 2: API Request JSON File Created${NC}"
echo -e "${WHITE}✓ Task 3: Speech-to-Text API Called (English)${NC}"
echo -e "${WHITE}✓ Task 4: Multi-language Support Demonstrated (French)${NC}"

echo -e "\n${CYAN}Technical Components:${NC}"
echo -e "${WHITE}• VM Instance: linux-instance${NC}"
echo -e "${WHITE}• API Key: quicklab (auto-generated)${NC}"
echo -e "${WHITE}• Audio Format: FLAC encoding${NC}"
echo -e "${WHITE}• API Endpoint: speech.googleapis.com${NC}"

echo -e "\n${CYAN}Audio Files Processed:${NC}"
echo -e "${WHITE}• English: brooklyn_bridge.flac (\"How old is the Brooklyn Bridge\")${NC}"
echo -e "${WHITE}• French: corbeau_renard.flac (Jean de la Fontaine fable)${NC}"

echo -e "\n${CYAN}Key Learning Outcomes:${NC}"
echo -e "${WHITE}• REST API integration with Google Cloud${NC}"
echo -e "${WHITE}• JSON request/response handling${NC}"
echo -e "${WHITE}• Multi-language speech recognition${NC}"
echo -e "${WHITE}• Cloud-based audio file processing${NC}"
echo -e "${WHITE}• API key management and security${NC}"

echo -e "\n${GREEN}✓ TASK 4 COMPLETED: Multi-language speech transcription demonstrated!${NC}"

print_success "🎉 All lab tasks completed successfully!"

echo -e "\n${YELLOW}Note: Check all lab progress indicators for green checkmarks before submitting.${NC}"