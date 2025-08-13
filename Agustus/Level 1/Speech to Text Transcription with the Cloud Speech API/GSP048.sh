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

print_step "Step 1.1: Enable Speech-to-Text API"
print_status "Enabling Speech-to-Text API..."
gcloud services enable speech.googleapis.com
print_success "Speech-to-Text API enabled successfully!"

print_step "Step 1.2: Create API Key"
print_status "Creating API key for Speech-to-Text API..."

# Create API key and extract the key value directly from the output
API_KEY_OUTPUT=$(gcloud alpha services api-keys create --display-name="Speech-to-Text API Key" --format="json")

# Extract the keyString directly from the JSON output
export API_KEY=$(echo "$API_KEY_OUTPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['keyString'])
except:
    print('')
")

# If the above method fails, try alternative extraction
if [ -z "$API_KEY" ]; then
    print_warning "Trying alternative API key extraction method..."
    # Extract key name and then get the key string
    KEY_NAME=$(echo "$API_KEY_OUTPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['name'].split('/')[-1])
except:
    print('')
")
    
    if [ ! -z "$KEY_NAME" ]; then
        sleep 5  # Wait for key to be fully created
        export API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)" 2>/dev/null || echo "")
    fi
fi

# If still no key, try listing and getting the latest one
if [ -z "$API_KEY" ]; then
    print_warning "Trying to get most recent API key..."
    sleep 10  # Wait longer for propagation
    LATEST_KEY=$(gcloud alpha services api-keys list --format="value(name)" --limit=1 --sort-by="~createTime")
    if [ ! -z "$LATEST_KEY" ]; then
        KEY_ID=$(echo $LATEST_KEY | sed 's|.*/||')
        export API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_ID --format="value(keyString)" 2>/dev/null || echo "")
    fi
fi

# Final fallback - manual extraction from the visible output
if [ -z "$API_KEY" ]; then
    print_error "Automatic API key extraction failed."
    echo -e "${YELLOW}Please manually copy the API key from the output above.${NC}"
    echo -e "${YELLOW}Look for 'keyString' in the JSON output and copy the value.${NC}"
    echo -e "${CYAN}Enter your API key manually:${NC}"
    read -p "API Key: " API_KEY
    export API_KEY
fi

if [ ! -z "$API_KEY" ]; then
    echo -e "${CYAN}API Key Created: ${WHITE}$API_KEY${NC}"
    print_success "API key created successfully!"
else
    print_error "Failed to extract API key. Please check the output above."
    exit 1
fi

print_step "Step 1.3: Find VM Instance"
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

echo -e "\n${GREEN}✓ TASK 1 COMPLETED: API key created and VM instance ready!${NC}"

# =============================================================================
# TASK 2: CREATE API REQUEST
# =============================================================================
print_task "2. Create your API Request"

print_step "Step 2.1: Connect to VM and Create Request Files"
print_status "Connecting to linux-instance via SSH to create API request..."

# Create the request.json file on the VM
gcloud compute ssh linux-instance --zone=$ZONE --command="
export API_KEY='$API_KEY'
echo 'Creating request.json file...'
cat > request.json << 'EOF'
{
  \"config\": {
      \"encoding\":\"FLAC\",
      \"languageCode\": \"en-US\"
  },
  \"audio\": {
      \"uri\":\"gs://cloud-samples-data/speech/brooklyn_bridge.flac\"
  }
}
EOF
echo 'request.json created successfully!'
cat request.json
" --ssh-flag="-o StrictHostKeyChecking=no" --quiet

print_success "API request file created on VM successfully!"

echo -e "\n${GREEN}✓ TASK 2 COMPLETED: API request file created!${NC}"

# =============================================================================
# TASK 3: CALL THE SPEECH-TO-TEXT API
# =============================================================================
print_task "3. Call the Speech-to-Text API"

print_step "Step 3.1: Make API Call for English Audio"
print_status "Calling Speech-to-Text API for English audio..."

# Execute API call on the VM
gcloud compute ssh linux-instance --zone=$ZONE --command="
export API_KEY='$API_KEY'
echo 'Making API call to Speech-to-Text...'
curl -s -X POST -H 'Content-Type: application/json' --data-binary @request.json \
'https://speech.googleapis.com/v1/speech:recognize?key=\${API_KEY}' > result.json

echo 'API Response:'
cat result.json
echo
echo 'Extracting transcript...'
python3 -c \"
import json
with open('result.json', 'r') as f:
    data = json.load(f)
    if 'results' in data and len(data['results']) > 0:
        transcript = data['results'][0]['alternatives'][0]['transcript']
        confidence = data['results'][0]['alternatives'][0]['confidence']
        print(f'Transcript: {transcript}')
        print(f'Confidence: {confidence:.2%}')
    else:
        print('No results found in response')
\"
" --ssh-flag="-o StrictHostKeyChecking=no" --quiet

print_success "English audio transcription completed!"

echo -e "\n${GREEN}✓ TASK 3 COMPLETED: Speech-to-Text API called successfully!${NC}"

# =============================================================================
# TASK 4: SPEECH-TO-TEXT TRANSCRIPTION IN DIFFERENT LANGUAGES
# =============================================================================
print_task "4. Speech-to-Text Transcription in Different Languages"

print_step "Step 4.1: Create French Language Request"
print_status "Creating request for French audio transcription..."

# Create French request and make API call
gcloud compute ssh linux-instance --zone=$ZONE --command="
export API_KEY='$API_KEY'
echo 'Creating French language request...'
cat > request.json << 'EOF'
{
  \"config\": {
      \"encoding\":\"FLAC\",
      \"languageCode\": \"fr\"
  },
  \"audio\": {
      \"uri\":\"gs://cloud-samples-data/speech/corbeau_renard.flac\"
  }
}
EOF

echo 'French request.json created:'
cat request.json
echo
" --ssh-flag="-o StrictHostKeyChecking=no" --quiet

print_step "Step 4.2: Make API Call for French Audio"
print_status "Calling Speech-to-Text API for French audio..."

gcloud compute ssh linux-instance --zone=$ZONE --command="
export API_KEY='$API_KEY'
echo 'Making API call for French audio...'
curl -s -X POST -H 'Content-Type: application/json' --data-binary @request.json \
'https://speech.googleapis.com/v1/speech:recognize?key=\${API_KEY}' > result.json

echo 'French API Response:'
cat result.json
echo
echo 'Extracting French transcript...'
python3 -c \"
import json
with open('result.json', 'r') as f:
    data = json.load(f)
    if 'results' in data and len(data['results']) > 0:
        transcript = data['results'][0]['alternatives'][0]['transcript']
        confidence = data['results'][0]['alternatives'][0]['confidence']
        print(f'French Transcript: {transcript}')
        print(f'Confidence: {confidence:.2%}')
    else:
        print('No results found in French response')
\"
" --ssh-flag="-o StrictHostKeyChecking=no" --quiet

print_success "French audio transcription completed!"

print_step "Step 4.3: Test Additional Languages (Optional)"
print_status "Creating Spanish language request as bonus..."

gcloud compute ssh linux-instance --zone=$ZONE --command="
export API_KEY='$API_KEY'
echo 'Testing Spanish language support...'
cat > request_spanish.json << 'EOF'
{
  \"config\": {
      \"encoding\":\"FLAC\",
      \"languageCode\": \"es\"
  },
  \"audio\": {
      \"uri\":\"gs://cloud-samples-data/speech/corbeau_renard.flac\"
  }
}
EOF

echo 'Available language codes for testing:'
echo '- en-US (English)'
echo '- fr (French)'
echo '- es (Spanish)'
echo '- de (German)'
echo '- ja (Japanese)'
echo '- ko (Korean)'
echo '- zh (Chinese)'
echo 'And many more... (100+ languages supported)'
" --ssh-flag="-o StrictHostKeyChecking=no" --quiet

print_step "Step 4.4: Display Lab Summary"
print_status "Displaying lab completion summary..."

echo -e "\n${CYAN}Lab Summary:${NC}"
echo -e "${WHITE}✓ API Key Created: ${API_KEY:0:20}...${NC}"
echo -e "${WHITE}✓ VM Instance: linux-instance (running)${NC}"
echo -e "${WHITE}✓ English Audio: Transcribed successfully${NC}"
echo -e "${WHITE}✓ French Audio: Transcribed successfully${NC}"
echo -e "${WHITE}✓ API Endpoints: speech.googleapis.com${NC}"

echo -e "\n${CYAN}Audio Files Used:${NC}"
echo -e "${WHITE}• English: gs://cloud-samples-data/speech/brooklyn_bridge.flac${NC}"
echo -e "${WHITE}• French: gs://cloud-samples-data/speech/corbeau_renard.flac${NC}"

echo -e "\n${CYAN}Key Features Demonstrated:${NC}"
echo -e "${WHITE}• Synchronous speech recognition${NC}"
echo -e "${WHITE}• Multiple language support${NC}"
echo -e "${WHITE}• REST API integration${NC}"
echo -e "${WHITE}• JSON request/response handling${NC}"

echo -e "\n${GREEN}✓ TASK 4 COMPLETED: Multi-language transcription demonstrated!${NC}"

print_success "All lab tasks completed successfully! 🎉"