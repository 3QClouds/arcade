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
# TASK 4: CREATE A POLICY (SEMI-AUTOMATED)
# =============================================================================
print_task "4. Create a Policy (SEMI-AUTOMATED)"

print_manual "4a. Manual Web UI Policy Creation"

echo -e "${RED}MANUAL STEPS - Web UI Policy Creation:${NC}"
echo -e "${WHITE}1. Open Cloud Shell Web Preview on port 8200${NC}"
echo -e "${WHITE}2. Login with Root Token: ${ROOT_TOKEN}${NC}"
echo -e "${WHITE}3. Go to Policies > Create ACL policy${NC}"
echo -e "${WHITE}4. Name: demo-policy${NC}"
echo -e "${WHITE}5. Policy content (step 1):${NC}"
cat <<'EOF'
path "sys/mounts" {
    capabilities = ["read"]
}
EOF

echo -e "${WHITE}6. Click Create policy${NC}"
echo -e "${WHITE}7. Go to Access > userpass > example-user > Edit user${NC}"
echo -e "${WHITE}8. Under Tokens > Generated Token's Policies > Add 'demo-policy'${NC}"
echo -e "${WHITE}9. Click Save${NC}"

echo -e "\n${YELLOW}After completing Web UI steps above, press ENTER to continue with automated testing...${NC}"
read -r

print_step "Step 4.1: Test Initial Policy (AUTOMATED)"
print_status "Testing policy after Web UI creation..."

# Login with example-user to get new token with demo-policy
vault login -method=userpass username=example-user password=password!

print_status "Testing sys/mounts access (should work now)..."
vault secrets list

print_status "Getting current token for capabilities check..."
CURRENT_TOKEN=$(vault print token)
echo -e "${CYAN}Current Token: ${WHITE}$CURRENT_TOKEN${NC}"

print_status "Checking token capabilities for sys/mounts..."
vault token capabilities $CURRENT_TOKEN sys/mounts

print_status "Testing sys/policies/acl access (should fail)..."
vault token capabilities $CURRENT_TOKEN sys/policies/acl
vault policy list || echo -e "${GREEN}Expected: Permission denied${NC}"

print_step "Step 4.2: Manual Policy Update Required"

echo -e "\n${RED}MANUAL STEPS - Update Policy in Web UI:${NC}"
echo -e "${WHITE}1. Go back to Vault Web UI${NC}"
echo -e "${WHITE}2. Go to Policies > demo-policy${NC}"
echo -e "${WHITE}3. Click Edit policy${NC}"
echo -e "${WHITE}4. Add this to the existing policy content:${NC}"
cat <<'EOF'
path "sys/policies/acl" {
    capabilities = ["read", "list"]
}
EOF

echo -e "${WHITE}5. Click Save${NC}"

echo -e "\n${YELLOW}After updating policy in Web UI, press ENTER to continue with automated testing...${NC}"
read -r

print_step "Step 4.3: Test Updated Policy (AUTOMATED)"
print_status "Testing updated policy capabilities..."

print_status "Testing sys/policies/acl access (should work now)..."
vault policy list

print_status "Checking updated token capabilities..."
vault token capabilities $CURRENT_TOKEN sys/policies/acl

print_step "Step 4.4: Export Results for Checkpoint (AUTOMATED)"
print_status "Exporting results for checkpoint verification..."

vault policy list > policies.txt
vault token capabilities $CURRENT_TOKEN sys/policies/acl > token_capabilities.txt

gsutil cp *.txt gs://$PROJECT_ID

print_success "Task 4 completed - Policy created, associated, and tested!"

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