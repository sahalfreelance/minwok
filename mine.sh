#!/bin/sh
# ================================================
# Mine Bot Auto Setup Script
# Dibuat untuk: AWP/Mine Mining Bot
# Support: Alpine Linux & Ubuntu/Debian
# ================================================

echo "================================================"
echo " Mine Bot Auto Setup"
echo "================================================"

# Detect OS
if [ -f /etc/alpine-release ]; then
    OS="alpine"
    echo "Detected: Alpine Linux"
elif [ -f /etc/debian_version ]; then
    OS="debian"
    echo "Detected: Ubuntu/Debian"
else
    OS="unknown"
    echo "Unknown OS, trying debian mode..."
    OS="debian"
fi

# Install dependencies
echo ""
echo "Step 1: Installing dependencies..."
if [ "$OS" = "alpine" ]; then
    apk add --no-cache nodejs npm git python3 python3-dev py3-pip curl bash
else
    apt-get update -qq
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs git python3 python3-pip python3-venv curl
fi

# Verify versions
echo ""
echo "Step 2: Verifying installations..."
node --version
npm --version
python3 --version
git --version

# Install awp-wallet
echo ""
echo "Step 3: Installing AWP Wallet..."
npm install -g https://github.com/awp-core/awp-wallet
awp-wallet --version

# Install AWP Skill
echo ""
echo "Step 4: Installing AWP Skill..."
mkdir -p ~/.gemini/skills
git clone https://github.com/awp-core/awp-skill ~/.gemini/skills/awp

# Clone mine-skill
echo ""
echo "Step 5: Cloning Mine Skill..."
cd ~
git clone https://github.com/awp-worknet/mine-skill
cd mine-skill

# Bootstrap
echo ""
echo "Step 6: Running bootstrap..."
PYTHON_BIN=/usr/bin/python3 bash scripts/bootstrap.sh

# Init wallet
echo ""
echo "Step 7: Initializing wallet..."
awp-wallet init

# Get wallet address
WALLET_ADDR=$(awp-wallet receive | python3 -c "import sys,json; print(json.load(sys.stdin)['eoaAddress'])")
echo "Wallet agent address: $WALLET_ADDR"

# Unlock wallet
echo ""
echo "Step 8: Unlocking wallet..."
TOKEN=$(awp-wallet unlock --scope full --duration 86400 | python3 -c "import sys,json; print(json.load(sys.stdin)['sessionToken'])")
echo "Session token: $TOKEN"

# Register on-chain
echo ""
echo "Step 9: Registering on-chain..."
python3 ~/.gemini/skills/awp/scripts/relay-start.py --token $TOKEN --mode principal

# Setup mine
echo ""
echo "Step 10: Setup mine environment..."
cd ~/mine-skill
.venv/bin/python scripts/run_tool.py setup

# Start mining
echo ""
echo "Step 11: Starting mining..."
.venv/bin/python scripts/run_tool.py agent-start ds_wikipedia,ds_linkedin_jobs,ds_linkedin_posts,ds_linkedin_profiles,ds_amazon_reviews,ds_basic_amazon_products_active,ds_wikipedia,ds_arxiv 

echo ""
echo "================================================"
echo " Setup Complete!"
echo " Wallet agent: $WALLET_ADDR"
echo " Mining: Wikipedia + LinkedIn"
echo "================================================"
echo ""
echo "Useful Commands:"
echo "  Check status : cd ~/mine-skill && .venv/bin/python scripts/run_tool.py agent-control status"
echo "  Stop mining  : .venv/bin/python scripts/run_tool.py agent-control stop"
echo "  Start mining : .venv/bin/python scripts/run_tool.py agent-start ds_wikipedia,ds_linkedin_company"
echo "  Setup ulang  : .venv/bin/python scripts/run_tool.py setup"
