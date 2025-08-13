#!/bin/bash

# Extract, Analyze, and Translate Text from Images with Cloud ML APIs - Fast Script
# Based on your efficient approach

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

print_step() {
    echo -e "\n${PURPLE}════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════════════${NC}"
}

# =============================================================================
# SETUP AND API KEY CREATION
# =============================================================================
print_step "Setup and API Key Creation"

print_status "Checking authentication..."
gcloud auth list

print_status "Enabling required APIs..."
gcloud services enable vision.googleapis.com
gcloud services enable translate.googleapis.com
gcloud services enable language.googleapis.com
gcloud services enable apikeys.googleapis.com

print_status "Creating API key..."
gcloud alpha services api-keys create --display-name="servicekey"
KEY_NAME=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=servicekey")
API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")

print_status "Setting up project..."
export PROJECT_ID=$(gcloud config list --format 'value(core.project)')
echo -e "${CYAN}Project ID: ${WHITE}$PROJECT_ID${NC}"
echo -e "${CYAN}API Key: ${WHITE}${API_KEY:0:20}...${NC}"

print_success "Setup completed!"

# =============================================================================
# CLOUD STORAGE AND IMAGE SETUP
# =============================================================================
print_step "Cloud Storage and Image Setup"

print_status "Creating Cloud Storage bucket..."
gsutil mb gs://$PROJECT_ID

print_status "Downloading image from your GitHub repository..."
curl -O https://raw.githubusercontent.com/3QClouds/arcade/main/Agustus/Level%201/Extract%2C%20Analyze%2C%20and%20Translate%20Text%20from%20Images%20with%20the%20Cloud%20ML%20APIs/sign.jpg

print_status "Uploading image to Cloud Storage..."
gsutil cp sign.jpg gs://$PROJECT_ID/sign.jpg

print_status "Making image publicly readable..."
gsutil acl ch -u AllUsers:R gs://$PROJECT_ID/sign.jpg

print_success "Image setup completed!"

# =============================================================================
# VISION API - TEXT DETECTION
# =============================================================================
print_step "Vision API - Text Detection"

print_status "Creating OCR request..."
touch ocr-request.json
tee ocr-request.json <<EOF_CP
{
  "requests": [
      {
        "image": {
          "source": {
              "gcsImageUri": "gs://$PROJECT_ID/sign.jpg"
          }
        },
        "features": [
          {
            "type": "TEXT_DETECTION",
            "maxResults": 10
          }
        ]
      }
  ]
}
EOF_CP

print_status "Calling Vision API for text detection..."
curl -s -X POST -H "Content-Type: application/json" --data-binary @ocr-request.json  https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}

print_status "Saving OCR response..."
curl -s -X POST -H "Content-Type: application/json" --data-binary @ocr-request.json  https://vision.googleapis.com/v1/images:annotate?key=${API_KEY} -o ocr-response.json

print_success "Text detection completed!"

# =============================================================================
# TRANSLATION API
# =============================================================================
print_step "Translation API"

print_status "Creating translation request template..."
touch translation-request.json
tee translation-request.json <<EOF_CP
{
  "q": "your_text_here", 
  "target": "en"
}
EOF_CP

print_status "Extracting text from OCR response and updating translation request..."
STR=$(jq .responses[0].textAnnotations[0].description ocr-response.json) && STR="${STR//\"}" && sed -i "s|your_text_here|$STR|g" translation-request.json

print_status "Calling Translation API..."
curl -s -X POST -H "Content-Type: application/json" --data-binary @translation-request.json https://translation.googleapis.com/language/translate/v2?key=${API_KEY} -o translation-response.json

print_status "Translation response:"
cat translation-response.json

print_success "Translation completed!"

# =============================================================================
# NATURAL LANGUAGE API
# =============================================================================
print_step "Natural Language API"

print_status "Creating Natural Language request template..."
touch nl-request.json
tee nl-request.json <<EOF_CP
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"your_text_here"
  },
  "encodingType":"UTF8"
}
EOF_CP

print_status "Extracting translated text and updating NL request..."
STR=$(jq .data.translations[0].translatedText  translation-response.json) && STR="${STR//\"}" && sed -i "s|your_text_here|$STR|g" nl-request.json

print_status "Calling Natural Language API for entity analysis..."
curl "https://language.googleapis.com/v1/documents:analyzeEntities?key=${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" --data-binary @nl-request.json

print_success "Natural Language analysis completed!"

# =============================================================================
# SUMMARY
# =============================================================================
print_step "Lab Summary"

echo -e "\n${CYAN}Files Created:${NC}"
echo -e "${WHITE}• sign.jpg - Downloaded image${NC}"
echo -e "${WHITE}• ocr-request.json - Vision API request${NC}"
echo -e "${WHITE}• ocr-response.json - Vision API response${NC}"
echo -e "${WHITE}• translation-request.json - Translation API request${NC}"
echo -e "${WHITE}• translation-response.json - Translation API response${NC}"
echo -e "${WHITE}• nl-request.json - Natural Language API request${NC}"

echo -e "\n${CYAN}APIs Used:${NC}"
echo -e "${WHITE}• Vision API - Text detection from image${NC}"
echo -e "${WHITE}• Translation API - Text translation${NC}"
echo -e "${WHITE}• Natural Language API - Entity analysis${NC}"

echo -e "\n${CYAN}Cloud Storage:${NC}"
echo -e "${WHITE}• Bucket: gs://$PROJECT_ID${NC}"
echo -e "${WHITE}• Image: gs://$PROJECT_ID/sign.jpg${NC}"

print_success "🎉 All tasks completed successfully!"

echo -e "\n${YELLOW}Note: Check all responses above for the extracted text, translation, and entity analysis results.${NC}"