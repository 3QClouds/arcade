#!/bin/bash

# HashiCorp Vault Basics Lab - Automated Portion
# Tasks 1-6 can be automated, Task 7 requires manual Web UI interaction

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

print_task() {
    echo -e "\n${CYAN}▶ TASK: $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════${NC}"
}

print_manual() {
    echo -e "\n${RED}⚠️  MANUAL TASK REQUIRED: $1${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════════════════${NC}"
}

# Get project information
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${CYAN}Project ID: ${WHITE}$PROJECT_ID${NC}"

# =============================================================================
# TASK 1: INSTALL VAULT (AUTOMATED)
# =============================================================================
print_task "1. Install Vault (AUTOMATED)"

print_step "Step 1.1: Update System and Install Dependencies"
print_status "Updating system packages..."
sudo apt update && sudo apt install -y curl gnupg lsb-release

print_step "Step 1.2: Add HashiCorp GPG Key"
print_status "Adding HashiCorp GPG key..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

print_step "Step 1.3: Add HashiCorp Repository"
print_status "Adding HashiCorp repository..."
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

print_step "Step 1.4: Install Vault"
print_status "Installing Vault..."
sudo apt-get update
sudo apt-get install vault -y

print_step "Step 1.5: Verify Installation"
print_status "Verifying Vault installation..."
vault --version

print_success "Task 1 completed - Vault installed successfully!"

# =============================================================================
# TASK 2: START VAULT SERVER (SEMI-AUTOMATED)
# =============================================================================
print_task "2. Start Vault Server (SEMI-AUTOMATED)"

print_step "Step 2.1: Start Vault Dev Server in Background"
print_status "Starting Vault development server..."
nohup vault server -dev > vault_output.log 2>&1 &
VAULT_PID=$!

print_status "Waiting for server to start..."
sleep 5

print_step "Step 2.2: Extract Server Information"
print_status "Extracting server configuration..."

# Wait for the log file to contain the necessary information
sleep 5

# Extract VAULT_ADDR, Unseal Key, and Root Token
export VAULT_ADDR='http://127.0.0.1:8200'
UNSEAL_KEY=$(grep "Unseal Key:" vault_output.log | awk -F': ' '{print $2}' | tr -d ' ')
ROOT_TOKEN=$(grep "Root Token:" vault_output.log | awk -F': ' '{print $2}' | tr -d ' ')

echo -e "${CYAN}Vault Address: ${WHITE}$VAULT_ADDR${NC}"
echo -e "${CYAN}Unseal Key: ${WHITE}$UNSEAL_KEY${NC}"
echo -e "${CYAN}Root Token: ${WHITE}$ROOT_TOKEN${NC}"

export VAULT_TOKEN="$ROOT_TOKEN"

print_step "Step 2.3: Verify Server Status"
print_status "Checking server status..."
vault status

print_success "Task 2 completed - Vault server running!"

# =============================================================================
# TASK 3: CREATE YOUR FIRST SECRET (AUTOMATED)
# =============================================================================
print_task "3. Create Your First Secret (AUTOMATED)"

print_step "Step 3.1: Verify No Existing Secrets"
print_status "Checking for existing secrets..."
vault kv get secret/hello || echo "No secrets found (expected)"

print_step "Step 3.2: Write First Secret"
print_status "Writing first secret..."
vault kv put secret/hello foo=world

print_step "Step 3.3: Write Multiple Secrets"
print_status "Writing multiple secrets..."
vault kv put secret/hello foo=world excited=yes

print_step "Step 3.4: Read Secrets"
print_status "Reading secrets..."
vault kv get secret/hello

print_step "Step 3.5: Read Specific Fields"
print_status "Reading specific fields..."
vault kv get -field=excited secret/hello
vault kv get -field=foo secret/hello

print_step "Step 3.6: JSON Output and File Creation"
print_status "Creating secret file for checkpoint..."
vault kv get -format=json secret/hello | jq -r .data.data.excited > secret.txt
gsutil cp secret.txt gs://$PROJECT_ID

print_step "Step 3.7: Delete Secret"
print_status "Deleting secret..."
vault kv delete secret/hello

print_step "Step 3.8: Secret Versions"
print_status "Creating versioned secrets..."
vault kv put secret/example test=version01
vault kv put secret/example test=version02
vault kv put secret/example test=version03

print_status "Reading specific version..."
vault kv get -version=2 secret/example

print_status "Deleting specific version..."
vault kv delete -versions=2 secret/example

print_status "Undeleting version..."
vault kv undelete -versions=2 secret/example

print_status "Permanently destroying version..."
vault kv destroy -versions=2 secret/example

vault kv get -version=2 secret/example

print_success "Task 3 completed - Secrets management demonstrated!"

# =============================================================================
# TASK 4: SECRETS ENGINES (AUTOMATED)
# =============================================================================
print_task "4. Secrets Engines (AUTOMATED)"

print_step "Step 4.1: Test Invalid Path"
print_status "Testing invalid path (should fail)..."
vault kv put foo/bar a=b || echo "Expected failure - path not mounted"

print_step "Step 4.2: Enable New Secrets Engine"
print_status "Enabling kv secrets engine at custom path..."
vault secrets enable -path=kv kv

print_step "Step 4.3: List Secrets Engines"
print_status "Listing all secrets engines..."
vault secrets list

print_step "Step 4.4: Use New Secrets Engine"
print_status "Creating secrets in new engine..."
vault kv put kv/hello target=world
vault kv get kv/hello

vault kv put kv/my-secret value="s3c(eT"
vault kv get kv/my-secret

print_step "Step 4.5: Export Secret for Checkpoint"
print_status "Creating my-secret file for checkpoint..."
vault kv get -format=json kv/my-secret | jq -r .data.value > my-secret.txt
gsutil cp my-secret.txt gs://$PROJECT_ID

print_step "Step 4.6: Clean Up"
print_status "Deleting secrets and listing remaining..."
vault kv delete kv/my-secret
vault kv list kv/

print_step "Step 4.7: Disable Secrets Engine"
print_status "Disabling secrets engine..."
vault secrets disable kv/

print_success "Task 4 completed - Secrets engines management demonstrated!"

# =============================================================================
# TASK 5: AUTHENTICATION (AUTOMATED)
# =============================================================================
print_task "5. Authentication (AUTOMATED)"

print_step "Step 5.1: Token Authentication"
print_status "Creating new token..."
NEW_TOKEN=$(vault token create -format=json | jq -r '.auth.client_token')
echo -e "${CYAN}New Token: ${WHITE}$NEW_TOKEN${NC}"

print_status "Logging in with new token..."
vault login $NEW_TOKEN

print_step "Step 5.2: Create Another Token"
print_status "Creating second token..."
SECOND_TOKEN=$(vault token create -format=json | jq -r '.auth.client_token')
echo -e "${CYAN}Second Token: ${WHITE}$SECOND_TOKEN${NC}"

print_step "Step 5.3: Revoke Token"
print_status "Revoking first token..."
vault token revoke $NEW_TOKEN

print_status "Testing revoked token (should fail)..."
vault login $NEW_TOKEN || echo "Expected failure - token revoked"

print_success "Task 5 completed - Token authentication demonstrated!"

# =============================================================================
# TASK 6: AUTH METHODS (AUTOMATED)
# =============================================================================
print_task "6. Auth Methods (AUTOMATED)"

print_step "Step 6.1: Enable Userpass Auth Method"
print_status "Enabling userpass authentication..."
vault auth enable userpass

print_step "Step 6.2: Create User"
print_status "Creating admin user..."
vault write auth/userpass/users/admin password=password! policies=admin

print_step "Step 6.3: Login with Username/Password"
print_status "Logging in with userpass..."
vault login -method=userpass username=admin password=password!

print_step "Step 6.4: Test Custom Path"
print_status "Testing auth method at custom path..."
vault auth enable -path=my-login userpass
vault auth disable userpass
vault auth disable my-login

print_success "Task 6 completed - Auth methods demonstrated!"

# =============================================================================
# MANUAL TASK NOTIFICATION
# =============================================================================
print_manual "7. Use the Vault Web UI"

echo -e "${RED}The following steps require manual interaction with the Web UI:${NC}"
echo -e "${WHITE}1. Open Cloud Shell Web Preview on port 8200${NC}"
echo -e "${WHITE}2. Login with Root Token: ${ROOT_TOKEN}${NC}"
echo -e "${WHITE}3. Enable Transit secrets engine${NC}"
echo -e "${WHITE}4. Create encryption key 'my-key'${NC}"
echo -e "${WHITE}5. Encrypt plaintext 'Learn Vault!'${NC}"
echo -e "${WHITE}6. Decrypt the ciphertext${NC}"
echo -e "${WHITE}7. Decode base64 and save to file${NC}"

echo -e "\n${YELLOW}Web UI Access Instructions:${NC}"
echo -e "${WHITE}• Click Web Preview icon in Cloud Shell${NC}"
echo -e "${WHITE}• Change port to 8200${NC}"
echo -e "${WHITE}• Use Root Token: ${ROOT_TOKEN}${NC}"

echo -e "\n${YELLOW}After completing Web UI tasks, run these commands:${NC}"
echo -e "${WHITE}# Replace <your_base64_string> with actual base64 from UI${NC}"
echo -e "${WHITE}echo '<your_base64_string>' | base64 --decode > decrypted-string.txt${NC}"
echo -e "${WHITE}gsutil cp decrypted-string.txt gs://$PROJECT_ID${NC}"

print_success "🎉 Automated portion completed!"
echo -e "\n${CYAN}Summary of Automated Tasks:${NC}"
echo -e "${WHITE}✓ Task 1: Vault Installation${NC}"
echo -e "${WHITE}✓ Task 2: Vault Server Setup${NC}" 
echo -e "${WHITE}✓ Task 3: Secret Management${NC}"
echo -e "${WHITE}✓ Task 4: Secrets Engines${NC}"
echo -e "${WHITE}✓ Task 5: Token Authentication${NC}"
echo -e "${WHITE}✓ Task 6: Auth Methods${NC}"
echo -e "${RED}⚠ Task 7: Manual Web UI Required${NC}"