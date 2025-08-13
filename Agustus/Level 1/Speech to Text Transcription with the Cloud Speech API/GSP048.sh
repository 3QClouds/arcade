#!/bin/bash

# Google Speech-to-Text API Lab - Fast Script (2 minutes)
# Simple and efficient approach

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

print_step() {
    echo -e "\n${PURPLE}════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════════════${NC}"
}

print_checkpoint() {
    echo -e "\n${YELLOW}⏸️  CHECKPOINT: $1${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Check the lab progress for green checkmark before continuing.${NC}"
    echo -e "${WHITE}Press ENTER when checkpoint completed...${NC}"
    read -r
}

# Get project information
export PROJECT_ID=$(gcloud config get-value project)
export DEVSHELL_PROJECT_ID=$PROJECT_ID

echo -e "${CYAN}Project ID: ${WHITE}$PROJECT_ID${NC}"

# =============================================================================
# TASKS 1-3: ENGLISH AUDIO PROCESSING
# =============================================================================
print_step "Tasks 1-3: Create API Key and Process English Audio"

print_status "Creating English audio processing script..."

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

cat result.json

EOF_END

print_status "Executing on linux-instance..."

export ZONE=$(gcloud compute instances list linux-instance --format 'csv[no-heading](zone)')

gcloud compute scp prepare_disk.sh linux-instance:/tmp --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet

gcloud compute ssh linux-instance --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="bash /tmp/prepare_disk.sh"

print_success "English audio processing completed!"

# Checkpoint for Tasks 1-3
print_checkpoint "Tasks 1-3 Complete - Check Score"

# =============================================================================
# TASK 4: FRENCH AUDIO PROCESSING
# =============================================================================
print_step "Task 4: Process French Audio"

print_status "Creating French audio processing script..."

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

cat result.json

EOF_END

print_status "Executing French audio processing on linux-instance..."

export ZONE=$(gcloud compute instances list linux-instance --format 'csv[no-heading](zone)')

gcloud compute scp prepare_disk.sh linux-instance:/tmp --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet

gcloud compute ssh linux-instance --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="bash /tmp/prepare_disk.sh"

print_success "French audio processing completed!"

print_success "🎉 All tasks completed successfully!"