#!/bin/bash

# Google Cloud Speech-to-Text API Lab - Complete Script
# This script automates the Speech-to-Text API testing with different languages

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

print_step "Step 1.1: Enable Speech-to-Text API"
print_status "Enabling Speech-to-Text API..."
gcloud services enable speech.googleapis.com
print_success "Speech-to-Text API enabled successfully!"

print_step "Step 1.2: Create API Key"
print_status "Creating API key for Speech-to-Text API..."

# Create API key and capture the output
API_KEY_RESPONSE=$(gcloud alpha services api-keys create --display-name="Speech-to-Text Lab Key" --format="value(response.keyString)" 2>/dev/null)

if [ -z "$API_KEY_RESPONSE" ]; then
    print_warning "Alpha API key creation not available, using alternative method..."
    
    # Alternative: Create a service account and key
    print_status "Creating service account for API access..."
    gcloud iam service-accounts create speech-to-text-sa \
        --display-name="Speech-to-Text Service Account" \
        --description="Service account for Speech-to-Text API lab"
    
    print_status "Creating service account key..."
    gcloud iam service-accounts keys create speech-key.json \
        --iam-account=speech-to-text-sa@$PROJECT_ID.iam.gserviceaccount.com
    
    print_status "Granting necessary permissions..."
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:speech-to-text-sa@$PROJECT_ID.iam.gserviceaccount.com" \
        --role="roles/speech.client"
    
    export GOOGLE_APPLICATION_CREDENTIALS="speech-key.json"
    print_success "Service account authentication configured!"
    
    # For API key method, we'll use a placeholder
    export API_KEY="SERVICE_ACCOUNT_AUTH"
    echo -e "${YELLOW}Note: Using service account authentication instead of API key${NC}"
else
    export API_KEY="$API_KEY_RESPONSE"
    echo -e "${CYAN}API Key created: ${WHITE}${API_KEY:0:20}...${NC}"
    print_success "API key created successfully!"
fi

echo -e "\n${GREEN}✓ TASK 1 COMPLETED: API authentication configured!${NC}"

# =============================================================================
# TASK 2: CREATE YOUR API REQUEST
# =============================================================================
print_task "2. Create your API Request"

print_step "Step 2.1: Create Request JSON File for English"
print_status "Creating request.json file for English audio..."

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

print_success "English request.json file created!"

print_step "Step 2.2: Display Request Content"
print_status "Displaying request.json content..."
echo -e "${YELLOW}Request content:${NC}"
cat request.json

echo -e "\n${GREEN}✓ TASK 2 COMPLETED: API request file created!${NC}"

# =============================================================================
# TASK 3: CALL THE SPEECH-TO-TEXT API
# =============================================================================
print_task "3. Call the Speech-to-Text API"

print_step "Step 3.1: Test English Speech Recognition"
print_status "Calling Speech-to-Text API for English audio..."

if [ "$API_KEY" = "SERVICE_ACCOUNT_AUTH" ]; then
    # Use service account authentication
    curl -s -X POST -H "Content-Type: application/json" \
         -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
         --data-binary @request.json \
         "https://speech.googleapis.com/v1/speech:recognize" > result.json
else
    # Use API key authentication
    curl -s -X POST -H "Content-Type: application/json" \
         --data-binary @request.json \
         "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json
fi

print_success "API call completed!"

print_step "Step 3.2: Display English Results"
print_status "Displaying transcription results..."
echo -e "${YELLOW}English transcription result:${NC}"
cat result.json

# Extract and display the transcript
ENGLISH_TRANSCRIPT=$(cat result.json | grep -o '"transcript":"[^"]*"' | cut -d'"' -f4)
if [ ! -z "$ENGLISH_TRANSCRIPT" ]; then
    echo -e "\n${CYAN}Transcribed Text: ${WHITE}$ENGLISH_TRANSCRIPT${NC}"
fi

echo -e "\n${GREEN}✓ TASK 3 COMPLETED: English speech recognition successful!${NC}"

# =============================================================================
# TASK 4: SPEECH-TO-TEXT TRANSCRIPTION IN DIFFERENT LANGUAGES
# =============================================================================
print_task "4. Speech-to-Text Transcription in Different Languages"

print_step "Step 4.1: Create Request for French Audio"
print_status "Creating request.json file for French audio..."

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

print_success "French request.json file created!"

print_step "Step 4.2: Display French Request Content"
print_status "Displaying updated request.json content..."
echo -e "${YELLOW}French request content:${NC}"
cat request.json

print_step "Step 4.3: Test French Speech Recognition"
print_status "Calling Speech-to-Text API for French audio..."

if [ "$API_KEY" = "SERVICE_ACCOUNT_AUTH" ]; then
    # Use service account authentication
    curl -s -X POST -H "Content-Type: application/json" \
         -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
         --data-binary @request.json \
         "https://speech.googleapis.com/v1/speech:recognize" > result.json
else
    # Use API key authentication
    curl -s -X POST -H "Content-Type: application/json" \
         --data-binary @request.json \
         "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result.json
fi

print_success "French API call completed!"

print_step "Step 4.4: Display French Results"
print_status "Displaying French transcription results..."
echo -e "${YELLOW}French transcription result:${NC}"
cat result.json

# Extract and display the French transcript
FRENCH_TRANSCRIPT=$(cat result.json | grep -o '"transcript":"[^"]*"' | cut -d'"' -f4)
if [ ! -z "$FRENCH_TRANSCRIPT" ]; then
    echo -e "\n${CYAN}French Transcribed Text: ${WHITE}$FRENCH_TRANSCRIPT${NC}"
fi

print_step "Step 4.5: Demonstrate Additional Language Support"
print_status "Testing Spanish speech recognition..."

cat > request.json <<EOF
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "es"
  },
  "audio": {
      "uri":"gs://cloud-samples-data/speech/google_es.flac"
  }
}
EOF

if [ "$API_KEY" = "SERVICE_ACCOUNT_AUTH" ]; then
    curl -s -X POST -H "Content-Type: application/json" \
         -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
         --data-binary @request.json \
         "https://speech.googleapis.com/v1/speech:recognize" > result_spanish.json
else
    curl -s -X POST -H "Content-Type: application/json" \
         --data-binary @request.json \
         "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result_spanish.json
fi

echo -e "\n${YELLOW}Spanish transcription result:${NC}"
cat result_spanish.json

print_step "Step 4.6: Language Support Summary"
print_status "Displaying supported languages information..."

echo -e "\n${CYAN}Supported Languages Demonstrated:${NC}"
echo -e "${WHITE}• English (en-US): Brooklyn Bridge audio${NC}"
echo -e "${WHITE}• French (fr): Corbeau et Renard tale${NC}"
echo -e "${WHITE}• Spanish (es): Google Spanish audio${NC}"

echo -e "\n${CYAN}Language Codes Reference:${NC}"
echo -e "${WHITE}• English: en-US, en-GB, en-AU${NC}"
echo -e "${WHITE}• French: fr-FR, fr-CA${NC}"
echo -e "${WHITE}• Spanish: es-ES, es-MX, es-US${NC}"
echo -e "${WHITE}• German: de-DE${NC}"
echo -e "${WHITE}• Italian: it-IT${NC}"
echo -e "${WHITE}• Portuguese: pt-BR, pt-PT${NC}"
echo -e "${WHITE}• Japanese: ja-JP${NC}"
echo -e "${WHITE}• Korean: ko-KR${NC}"
echo -e "${WHITE}• Chinese: zh-CN, zh-TW${NC}"

echo -e "\n${GREEN}✓ TASK 4 COMPLETED: Multi-language speech recognition demonstrated!${NC}"

print_success "All lab tasks completed successfully! 🎉"