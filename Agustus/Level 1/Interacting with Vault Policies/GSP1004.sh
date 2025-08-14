#!/bin/bash

# HashiCorp Vault Policies Lab - Automated Portion
# Tasks 1-3, 5-7 can be automated, Task 4 requires manual Web UI interaction

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

print_checkpoint() {
    echo -e "\n${YELLOW}⏸️  CHECKPOINT: $1${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Check lab progress for green checkmark before continuing.${NC}"
    echo -e "${WHITE}Press ENTER when checkpoint completed...${NC}"
    read -r
}

# Get project information
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${CYAN}Project ID: ${WHITE}$PROJECT_ID${NC}"

# =============================================================================
# TASK 1: INSTALL VAULT (AUTOMATED)
# =============================================================================
print_task "1. Install Vault (AUTOMATED)"

print_step "Step 1.1: Add HashiCorp GPG Key"
print_status "Adding HashiCorp GPG key..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -

print_step "Step 1.2: Add HashiCorp Repository"
print_status "Adding HashiCorp repository..."
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

print_step "Step 1.3: Install Vault"
print_status "Installing Vault..."
sudo apt-get update
sudo apt-get install vault -y

print_step "Step 1.4: Verify Installation"
print_status "Verifying Vault installation..."
vault --version

print_success "Task 1 completed - Vault installed successfully!"

# =============================================================================
# TASK 2: START VAULT SERVER (AUTOMATED)
# =============================================================================
print_task "2. Start Vault Server (AUTOMATED)"

print_step "Step 2.1: Start Vault Dev Server in Background"
print_status "Starting Vault development server..."
nohup vault server -dev > vault_output.log 2>&1 &
VAULT_PID=$!

print_status "Waiting for server to start..."
sleep 5

print_step "Step 2.2: Extract Server Information"
print_status "Extracting server configuration..."
sleep 5

export VAULT_ADDR='http://127.0.0.1:8200'
UNSEAL_KEY=$(grep "Unseal Key:" vault_output.log | awk -F': ' '{print $2}' | tr -d ' ')
ROOT_TOKEN=$(grep "Root Token:" vault_output.log | awk -F': ' '{print $2}' | tr -d ' ')

echo -e "${CYAN}Vault Address: ${WHITE}$VAULT_ADDR${NC}"
echo -e "${CYAN}Root Token: ${WHITE}$ROOT_TOKEN${NC}"

export VAULT_TOKEN="$ROOT_TOKEN"

print_step "Step 2.3: Verify Server Status"
print_status "Checking server status..."
vault status

print_success "Task 2 completed - Vault server running!"

# =============================================================================
# TASK 3: VAULT POLICIES OVERVIEW (AUTOMATED)
# =============================================================================
print_task "3. Vault Policies Overview (AUTOMATED)"

print_step "Step 3.1: Login with Root Token"
print_status "Logging in with root token..."
vault login token=$ROOT_TOKEN

print_step "Step 3.2: Test Root Policy Capabilities"
print_status "Testing root policy - listing secrets engines..."
vault secrets list

print_step "Step 3.3: Create Test User"
print_status "Enabling userpass auth and creating test user..."
vault auth enable userpass
vault write auth/userpass/users/example-user password=password!

print_step "Step 3.4: Test Default Policy Limitations"
print_status "Logging in as example-user (default policy only)..."
vault login -method=userpass username=example-user password=password!

print_status "Testing default policy limitations..."
vault secrets list || echo -e "${GREEN}Expected: Permission denied with default policy${NC}"

print_success "Task 3 completed - Policy differences demonstrated!"

# =============================================================================
# TASK 4: CREATE A POLICY (FULL MANUAL - NEW CLOUD SHELL REQUIRED)
# =============================================================================
print_task "4. Create a Policy (FULL MANUAL)"

print_manual "IMPORTANT: Task 4 Must Be Done Manually in NEW Cloud Shell"

echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
echo -e "${RED}           TASK 4 REQUIRES MANUAL COMPLETION${NC}" 
echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}INSTRUCTIONS:${NC}"
echo -e "${WHITE}1. KEEP THIS CLOUD SHELL RUNNING (do not close)${NC}"
echo -e "${WHITE}2. Open a NEW Cloud Shell tab/window${NC}"
echo -e "${WHITE}3. Complete Task 4 manually in the new shell${NC}"
echo -e "${WHITE}4. Return here when you get green checkmark ✓${NC}"

print_step "Manual Task 4 Instructions"

echo -e "${CYAN}In your NEW Cloud Shell:${NC}"

echo -e "\n${YELLOW}Step 1: Access Vault Web UI${NC}"
echo -e "${WHITE}• Click Web Preview icon in Cloud Shell toolbar${NC}"
echo -e "${WHITE}• Click 'Change port' → Set to 8200${NC}"
echo -e "${WHITE}• Click 'Change and Preview'${NC}"
echo -e "${WHITE}• Login with Root Token: ${ROOT_TOKEN}${NC}"

echo -e "\n${YELLOW}Step 2: Create demo-policy${NC}"
echo -e "${WHITE}• Click 'Policies' from home page${NC}"
echo -e "${WHITE}• Click 'Create ACL policy'${NC}"
echo -e "${WHITE}• Name: demo-policy${NC}"
echo -e "${WHITE}• Policy content (EXACTLY):${NC}"

echo -e "${GREEN}path \"sys/mounts\" {${NC}"
echo -e "${GREEN}    capabilities = [\"read\"]${NC}"
echo -e "${GREEN}}${NC}"

echo -e "${WHITE}• Click 'Create policy'${NC}"

echo -e "\n${YELLOW}Step 3: Associate with User${NC}"
echo -e "${WHITE}• Click 'Back to main navigation'${NC}"
echo -e "${WHITE}• Click 'Access' → 'userpass'${NC}"
echo -e "${WHITE}• Click ⋯ next to 'example-user' → 'Edit user'${NC}"
echo -e "${WHITE}• Click 'Tokens' tab${NC}"
echo -e "${WHITE}• Add 'demo-policy' to Generated Token's Policies${NC}"
echo -e "${WHITE}• Click 'Save'${NC}"

echo -e "\n${YELLOW}Step 4: Test in Cloud Shell${NC}"
echo -e "${WHITE}In your NEW Cloud Shell terminal:${NC}"

echo -e "${GREEN}# Set Vault address${NC}"
echo -e "${WHITE}export VAULT_ADDR='http://127.0.0.1:8200'${NC}"

echo -e "${GREEN}# Login as example-user${NC}"
echo -e "${WHITE}vault login -method=userpass username=example-user password=password!${NC}"

echo -e "${GREEN}# Test sys/mounts access (should work)${NC}"
echo -e "${WHITE}vault secrets list${NC}"

echo -e "${GREEN}# Get your token${NC}"
echo -e "${WHITE}CURRENT_TOKEN=\$(vault print token)${NC}"
echo -e "${WHITE}echo \"Token: \$CURRENT_TOKEN\"${NC}"

echo -e "${GREEN}# Check capabilities (should show 'read')${NC}"
echo -e "${WHITE}vault token capabilities \$CURRENT_TOKEN sys/mounts${NC}"

echo -e "${GREEN}# Check policies access (should show 'deny')${NC}"
echo -e "${WHITE}vault token capabilities \$CURRENT_TOKEN sys/policies/acl${NC}"

echo -e "${GREEN}# Try to list policies (should fail)${NC}"
echo -e "${WHITE}vault policy list${NC}"

echo -e "\n${YELLOW}Step 5: Update Policy${NC}"
echo -e "${WHITE}Return to Vault Web UI:${NC}"
echo -e "${WHITE}• Go to Policies → demo-policy${NC}"
echo -e "${WHITE}• Click 'Edit policy'${NC}"
echo -e "${WHITE}• Update to include BOTH paths:${NC}"

echo -e "${GREEN}path \"sys/mounts\" {${NC}"
echo -e "${GREEN}    capabilities = [\"read\"]${NC}"
echo -e "${GREEN}}${NC}"
echo -e "${GREEN}${NC}"
echo -e "${GREEN}path \"sys/policies/acl\" {${NC}"
echo -e "${GREEN}    capabilities = [\"read\", \"list\"]${NC}"
echo -e "${GREEN}}${NC}"

echo -e "${WHITE}• Click 'Save'${NC}"

echo -e "\n${YELLOW}Step 6: Test Updated Policy${NC}"
echo -e "${WHITE}In Cloud Shell (no need to re-login):${NC}"

echo -e "${GREEN}# Test policy list (should work now)${NC}"
echo -e "${WHITE}vault policy list${NC}"

echo -e "${GREEN}# Check updated capabilities (should show 'list, read')${NC}"
echo -e "${WHITE}vault token capabilities \$CURRENT_TOKEN sys/policies/acl${NC}"

echo -e "\n${YELLOW}Step 7: Create Required Files${NC}"
echo -e "${WHITE}Create checkpoint files:${NC}"

echo -e "${GREEN}# Export policy list${NC}"
echo -e "${WHITE}vault policy list > policies.txt${NC}"

echo -e "${GREEN}# Export token capabilities${NC}"
echo -e "${WHITE}vault token capabilities \$CURRENT_TOKEN sys/policies/acl > token_capabilities.txt${NC}"

echo -e "${GREEN}# Upload to Cloud Storage${NC}"
echo -e "${WHITE}export PROJECT_ID=\$(gcloud config get-value project)${NC}"
echo -e "${WHITE}gsutil cp *.txt gs://\$PROJECT_ID${NC}"

echo -e "\n${YELLOW}Step 8: Verify Checkpoint${NC}"
echo -e "${WHITE}• Check 'Check my progress' for green checkmark ✓${NC}"
echo -e "${WHITE}• Should show: 'Create policies' completed${NC}"

echo -e "\n${RED}═══════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}IMPORTANT REMINDER:${NC}"
echo -e "${WHITE}• Complete ALL steps above in NEW Cloud Shell${NC}"
echo -e "${WHITE}• Get green checkmark ✓ for Task 4${NC}"
echo -e "${WHITE}• Return here and press ENTER to continue${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"

echo -e "\n${CYAN}When you've completed Task 4 manually and got the green checkmark, press ENTER...${NC}"
read -r

print_success "Task 4 completed manually! Continuing with automated tasks..."

# =============================================================================
# TASK 5: MANAGING POLICIES (AUTOMATED)
# =============================================================================
print_task "5. Managing Policies (AUTOMATED)"

print_step "Step 5.1: Login with Root Token"
print_status "Logging in with root token for policy management..."
vault login $ROOT_TOKEN

print_step "Step 5.2: List Policies"
print_status "Listing all policies..."
vault read sys/policy

print_step "Step 5.3: Create Policy File"
print_status "Creating example-policy.hcl file..."
tee example-policy.hcl <<EOF
# List, create, update, and delete key/value secrets
path "secret/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage secrets engines
path "sys/mounts/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List existing secrets engines.
path "sys/mounts"
{
  capabilities = ["read"]
}
EOF

print_step "Step 5.4: Create Policy via CLI"
print_status "Creating policy via CLI..."
vault policy write example-policy example-policy.hcl

print_step "Step 5.5: Update Policy"
print_status "Updating policy to include auth methods..."
tee example-policy.hcl <<EOF
# List, create, update, and delete key/value secrets
path "secret/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage secrets engines
path "sys/mounts/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List existing secrets engines.
path "sys/mounts"
{
  capabilities = ["read"]
}

# List auth methods
path "sys/auth"
{
  capabilities = ["read"]
}
EOF

vault write sys/policy/example-policy policy=@example-policy.hcl
gsutil cp example-policy.hcl gs://$PROJECT_ID

print_step "Step 5.6: Delete Policy"
print_status "Deleting example policy..."
vault delete sys/policy/example-policy

vault policy list

print_success "Task 5 completed - Policy management demonstrated!"

# =============================================================================
# TASK 6: ASSOCIATING POLICIES (AUTOMATED)
# =============================================================================
print_task "6. Associating Policies (AUTOMATED)"

print_step "Step 6.1: Create User with Policies"
print_status "Creating user with associated policies..."
vault write auth/userpass/users/firstname-lastname \
    password="s3cr3t!" \
    policies="default, demo-policy"

print_step "Step 6.2: Authenticate with New User"
print_status "Logging in with new user..."
vault login -method="userpass" username="firstname-lastname" password="s3cr3t!"

print_step "Step 6.3: Create Token with Policies"
print_status "Logging back as root and creating token with policies..."
vault login $ROOT_TOKEN
vault token create -policy=dev-readonly -policy=logs

print_success "Task 6 completed - Policy association demonstrated!"

# =============================================================================
# TASK 7: POLICIES FOR SECRETS (AUTOMATED)
# =============================================================================
print_task "7. Policies for Secrets (AUTOMATED)"

print_step "Step 7.1: Create Users for Different Roles"
print_status "Creating users with different policy requirements..."
vault write auth/userpass/users/admin password="admin123" policies="admin"
vault write auth/userpass/users/app-dev password="appdev123" policies="appdev"
vault write auth/userpass/users/security password="security123" policies="security"

print_step "Step 7.2: Create Admin Policy"
print_status "Creating admin policy..."
tee admin-policy.hcl <<EOF
# Read system health check
path "sys/health"
{
  capabilities = ["read", "sudo"]
}

# Create and manage ACL policies broadly across Vault
# List existing policies
path "sys/policies/acl"
{
  capabilities = ["list"]
}

# Create and manage ACL policies
path "sys/policies/acl/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Enable and manage authentication methods broadly across Vault
# Manage auth methods broadly across Vault
path "auth/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Create, update, and delete auth methods
path "sys/auth/*"
{
  capabilities = ["create", "update", "delete", "sudo"]
}

# List auth methods
path "sys/auth"
{
  capabilities = ["read"]
}

# Enable and manage the key/value secrets engine at secret/ path
# List, create, update, and delete key/value secrets
path "secret/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage secrets engines
path "sys/mounts/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List existing secrets engines.
path "sys/mounts"
{
  capabilities = ["read"]
}
EOF

vault policy write admin admin-policy.hcl

print_step "Step 7.3: Create AppDev Policy"
print_status "Creating appdev policy..."
tee appdev-policy.hcl <<EOF
# List, create, update, and delete key/value secrets
path "secret/+/appdev/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Create, read, and update secrets engines
path "sys/mounts/*"
{
  capabilities = ["create", "read", "update"]
}

# List existing secrets engines.
path "sys/mounts"
{
  capabilities = ["read"]
}
EOF

vault policy write appdev appdev-policy.hcl

print_step "Step 7.4: Create Security Policy"
print_status "Creating security policy..."
tee security-policy.hcl <<EOF
# List existing policies
path "sys/policies/acl"
{
  capabilities = ["list"]
}

# Create and manage ACL policies
path "sys/policies/acl/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage secrets engines
path "sys/mounts/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List existing secrets engines.
path "sys/mounts"
{
  capabilities = ["read"]
}

# List, create, update, and delete key/value secrets
path "secret/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Deny access to secret/admin
path "secret/data/admin" {
    capabilities = ["deny"]
}
path "secret/data/admin/*" {
    capabilities = ["deny"]
}

# Deny list access to secret/admin
path "secret/metadata/admin" {
    capabilities = ["deny"]
}
path "secret/metadata/admin/*" {
    capabilities = ["deny"]
}
EOF

vault policy write security security-policy.hcl

print_step "Step 7.5: Create Test Secrets"
print_status "Creating test secrets for different paths..."
vault kv put secret/security/first username=password
vault kv put secret/security/second username=password
vault kv put secret/appdev/first username=password
vault kv put secret/appdev/beta-app/second username=password
vault kv put secret/admin/first admin=password
vault kv put secret/admin/supersecret/second admin=password

print_step "Step 7.6: Test AppDev User"
print_status "Testing app-dev user capabilities..."
vault login -method="userpass" username="app-dev" password="appdev123"

vault kv get secret/appdev/first
vault kv get secret/appdev/beta-app/second
vault kv put secret/appdev/appcreds credentials=creds123
vault kv destroy -versions=1 secret/appdev/appcreds

print_status "Testing app-dev restrictions (should fail)..."
vault kv get secret/security/first || echo -e "${GREEN}Expected: Permission denied${NC}"
vault kv list secret/ || echo -e "${GREEN}Expected: Permission denied${NC}"

print_step "Step 7.7: Test Security User"
print_status "Testing security user capabilities..."
vault login -method="userpass" username="security" password="security123"

vault kv get secret/security/first
vault kv get secret/security/second
vault kv put secret/security/supersecure/bigsecret secret=idk
vault kv destroy -versions=1 secret/security/supersecure/bigsecret
vault kv get secret/appdev/first
vault kv list secret/
vault secrets enable -path=supersecret kv

print_status "Testing security restrictions (should fail)..."
vault kv get secret/admin/first || echo -e "${GREEN}Expected: Permission denied${NC}"
vault kv list secret/admin || echo -e "${GREEN}Expected: Permission denied${NC}"

print_step "Step 7.8: Test Admin User"
print_status "Testing admin user capabilities..."
vault login -method="userpass" username="admin" password="admin123"

vault kv get secret/admin/first
vault kv get secret/security/first
vault kv put secret/webserver/credentials web=awesome
vault kv destroy -versions=1 secret/webserver/credentials
vault kv get secret/appdev/first
vault kv list secret/appdev/
vault policy list

print_step "Step 7.9: Final Setup"
print_status "Completing final setup tasks..."
vault policy list > policies-update.txt
gsutil cp policies-update.txt gs://$PROJECT_ID

vault auth enable gcp
vault auth list

print_success "Task 7 completed - All policy scenarios tested!"

print_success "🎉 All automated tasks completed!"

echo -e "\n${CYAN}Summary of Completed Tasks:${NC}"
echo -e "${WHITE}✓ Task 1: Vault Installation${NC}"
echo -e "${WHITE}✓ Task 2: Vault Server Setup${NC}" 
echo -e "${WHITE}✓ Task 3: Policy Overview${NC}"
echo -e "${RED}⚠ Task 4: Manual Web UI Policy Creation${NC}"
echo -e "${WHITE}✓ Task 5: Policy Management CLI${NC}"
echo -e "${WHITE}✓ Task 6: Policy Association${NC}"
echo -e "${WHITE}✓ Task 7: Comprehensive Policy Testing${NC}"

echo -e "\n${YELLOW}Root Token for Web UI: ${WHITE}$ROOT_TOKEN${NC}"
echo -e "${YELLOW}Vault Address: ${WHITE}$VAULT_ADDR${NC}"