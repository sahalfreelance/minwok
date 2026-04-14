#!/bin/sh
# ================================================
#   Mine Bot Manager — Interactive Terminal Menu
#   Supports: Alpine Linux & Ubuntu/Debian
# ================================================

# ---- Warna ----
R='\033[0;31m'  # Merah
G='\033[0;32m'  # Hijau
Y='\033[0;33m'  # Kuning
B='\033[0;34m'  # Biru
C='\033[0;36m'  # Cyan
W='\033[1;37m'  # Putih tebal
D='\033[0m'     # Reset

MINE_DIR="$HOME/mine-skill"
AWP_SKILL="$HOME/.gemini/skills/awp"
TOKEN_FILE="$HOME/.openclaw/workspace/session_token.txt"
WALLET_FILE="$HOME/.openclaw/workspace/wallet_info.txt"
VENV="$MINE_DIR/.venv/bin/python"

# ---- Default datasets ----
DEFAULT_DS="ds_wikipedia,ds_arxiv,ds_linkedin_jobs,ds_linkedin_company,ds_linkedin_posts,ds_linkedin_profiles,ds_amazon_reviews,ds_basic_amazon_products_active"

# ============================================================
# HELPERS
# ============================================================

print_header() {
    clear
    echo "${C}================================================${D}"
    echo "${W}   Mine Bot Manager — minework.net${D}"
    echo "${C}================================================${D}"
    echo ""
}

print_ok()   { echo "${G}[OK]${D} $1"; }
print_err()  { echo "${R}[ERR]${D} $1"; }
print_info() { echo "${Y}[INFO]${D} $1"; }
print_step() { echo "${B}[>>]${D} $1"; }

detect_os() {
    if [ -f /etc/alpine-release ]; then
        echo "alpine"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "debian"
    fi
}

require_mine_dir() {
    if [ ! -d "$MINE_DIR" ]; then
        print_err "Mine Skill belum diinstall. Jalankan opsi [1] Full Setup dulu."
        return 1
    fi
    return 0
}

read_token() {
    if [ -f "$TOKEN_FILE" ]; then
        cat "$TOKEN_FILE"
    else
        echo ""
    fi
}

pause() {
    echo ""
    printf "Tekan Enter untuk lanjut..."
    read _
}

# ============================================================
# 1. FULL SETUP
# ============================================================

do_full_setup() {
    print_header
    echo "${W}=== Full Install & Setup ===${D}"
    echo ""
    OS=$(detect_os)
    print_info "OS terdeteksi: $OS"
    echo ""

    # Install deps
    print_step "Menginstall dependencies..."
    if [ "$OS" = "alpine" ]; then
        apk add --no-cache nodejs npm git python3 python3-dev py3-pip curl bash
    else
        apt-get update -qq
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>/dev/null
        apt-get install -y nodejs git python3 python3-pip python3-venv curl
    fi

    print_step "Verifikasi versi..."
    echo "  node    : $(node --version 2>/dev/null || echo 'tidak ditemukan')"
    echo "  npm     : $(npm --version 2>/dev/null || echo 'tidak ditemukan')"
    echo "  python3 : $(python3 --version 2>/dev/null || echo 'tidak ditemukan')"
    echo "  git     : $(git --version 2>/dev/null | head -1 || echo 'tidak ditemukan')"
    echo ""

    # Install AWP Wallet
    print_step "Menginstall AWP Wallet..."
    npm install -g https://github.com/awp-core/awp-wallet
    print_ok "AWP Wallet: $(awp-wallet --version 2>/dev/null || echo 'installed')"

    # Install AWP Skill
    print_step "Menginstall AWP Skill..."
    mkdir -p "$HOME/.gemini/skills"
    if [ -d "$AWP_SKILL" ]; then
        print_info "Sudah ada, skip clone."
    else
        git clone https://github.com/awp-core/awp-skill "$AWP_SKILL"
    fi

    # Clone mine-skill
    print_step "Cloning Mine Skill..."
    if [ -d "$MINE_DIR" ]; then
        print_info "Sudah ada, pull update..."
        cd "$MINE_DIR" && git pull
    else
        git clone https://github.com/awp-worknet/mine-skill "$MINE_DIR"
    fi

    # Bootstrap
    print_step "Bootstrap environment..."
    cd "$MINE_DIR"
    PYTHON_BIN=/usr/bin/python3 bash scripts/bootstrap.sh

    # Init wallet
    print_step "Inisialisasi wallet..."
    mkdir -p "$HOME/.openclaw/workspace"
    awp-wallet init

    WALLET_ADDR=$(awp-wallet receive 2>/dev/null | python3 -c \
        "import sys,json; print(json.load(sys.stdin)['eoaAddress'])" 2>/dev/null)
    echo "$WALLET_ADDR" > "$WALLET_FILE"
    print_ok "Wallet: $WALLET_ADDR"

    # Unlock & simpan token
    print_step "Unlock wallet (86400 detik)..."
    TOKEN=$(awp-wallet unlock --scope full --duration 86400 2>/dev/null | python3 -c \
        "import sys,json; print(json.load(sys.stdin)['sessionToken'])" 2>/dev/null)
    echo "$TOKEN" > "$TOKEN_FILE"
    print_ok "Token: $TOKEN"

    # Register on-chain
    print_step "Mendaftarkan agent on-chain..."
    python3 "$AWP_SKILL/scripts/relay-start.py" --token "$TOKEN" --mode principal

    # Setup mine env
    print_step "Setup mine environment..."
    cd "$MINE_DIR"
    "$VENV" scripts/run_tool.py setup

    echo ""
    echo "${G}================================================${D}"
    echo "${G} Setup selesai!${D}"
    echo "${G}================================================${D}"
    echo "  Wallet : $WALLET_ADDR"
    echo "  Token  : $TOKEN"
    echo ""
    echo "Lanjutkan ke opsi [3] untuk mulai mining."
    pause
}

# ============================================================
# 2. INIT WALLET SAJA
# ============================================================

do_init_wallet() {
    print_header
    echo "${W}=== Init Wallet ===${D}"
    echo ""
    mkdir -p "$HOME/.openclaw/workspace"

    print_step "Inisialisasi wallet baru..."
    awp-wallet init

    WALLET_ADDR=$(awp-wallet receive 2>/dev/null | python3 -c \
        "import sys,json; print(json.load(sys.stdin)['eoaAddress'])" 2>/dev/null)
    echo "$WALLET_ADDR" > "$WALLET_FILE"
    print_ok "Wallet address: $WALLET_ADDR"
    pause
}

# ============================================================
# 3. PILIH DATASET & START MINING
# ============================================================

pick_datasets() {
    echo ""
    echo "${W}Pilih dataset (pisah koma, atau Enter untuk pakai semua):${D}"
    echo ""
    echo "  1) ds_wikipedia"
    echo "  2) ds_arxiv"
    echo "  3) ds_linkedin_jobs"
    echo "  4) ds_linkedin_company"
    echo "  5) ds_linkedin_posts"
    echo "  6) ds_linkedin_profiles"
    echo "  7) ds_amazon_reviews"
    echo "  8) ds_basic_amazon_products_active"
    echo ""
    printf "Nomor (cth: 1,2,3) atau Enter=semua: "
    read DS_INPUT

    if [ -z "$DS_INPUT" ]; then
        echo "$DEFAULT_DS"
        return
    fi

    RESULT=""
    IFS=',' 
    for NUM in $DS_INPUT; do
        NUM=$(echo "$NUM" | tr -d ' ')
        case "$NUM" in
            1) DS="ds_wikipedia" ;;
            2) DS="ds_arxiv" ;;
            3) DS="ds_linkedin_jobs" ;;
            4) DS="ds_linkedin_company" ;;
            5) DS="ds_linkedin_posts" ;;
            6) DS="ds_linkedin_profiles" ;;
            7) DS="ds_amazon_reviews" ;;
            8) DS="ds_basic_amazon_products_active" ;;
            *) DS="" ;;
        esac
        if [ -n "$DS" ]; then
            if [ -z "$RESULT" ]; then RESULT="$DS"
            else RESULT="$RESULT,$DS"
            fi
        fi
    done
    unset IFS

    if [ -z "$RESULT" ]; then echo "$DEFAULT_DS"
    else echo "$RESULT"
    fi
}

do_start_mining() {
    print_header
    echo "${W}=== Start Mining ===${D}"
    require_mine_dir || { pause; return; }

    TOKEN=$(read_token)
    if [ -z "$TOKEN" ]; then
        print_info "Token belum ada. Refresh token dulu..."
        do_refresh_token
        TOKEN=$(read_token)
    fi

    DATASETS=$(pick_datasets)
    echo ""
    print_info "Datasets: $DATASETS"

    print_step "Menghubungkan relay..."
    python3 "$AWP_SKILL/scripts/relay-start.py" --token "$TOKEN" --mode principal

    print_step "Menjalankan mining agent..."
    cd "$MINE_DIR"
    "$VENV" scripts/run_tool.py agent-start "$DATASETS"

    print_ok "Mining berjalan!"
    pause
}

# ============================================================
# 4. STOP MINING
# ============================================================

do_stop_mining() {
    print_header
    echo "${W}=== Stop Mining ===${D}"
    require_mine_dir || { pause; return; }

    print_step "Mengirim sinyal stop..."
    cd "$MINE_DIR"
    "$VENV" scripts/run_tool.py agent-control stop
    print_ok "Agent dihentikan."
    pause
}

# ============================================================
# 5. CEK STATUS
# ============================================================

do_status() {
    print_header
    echo "${W}=== Status Mining ===${D}"
    require_mine_dir || { pause; return; }

    cd "$MINE_DIR"
    "$VENV" scripts/run_tool.py agent-control status

    echo ""
    WALLET=$(cat "$WALLET_FILE" 2>/dev/null || echo "-")
    TOKEN=$(read_token)
    print_info "Wallet : $WALLET"
    print_info "Token  : ${TOKEN:-tidak ada}"
    pause
}

# ============================================================
# 6. REFRESH TOKEN
# ============================================================

do_refresh_token() {
    print_header
    echo "${W}=== Refresh Token ===${D}"
    echo ""
    mkdir -p "$HOME/.openclaw/workspace"

    print_step "Unlock wallet (86400 detik)..."
    TOKEN=$(awp-wallet unlock --scope full --duration 86400 2>/dev/null | python3 -c \
        "import sys,json; print(json.load(sys.stdin)['sessionToken'])" 2>/dev/null)

    if [ -z "$TOKEN" ]; then
        print_err "Gagal mendapatkan token. Pastikan wallet sudah diinit."
        pause
        return
    fi

    echo "$TOKEN" > "$TOKEN_FILE"
    print_ok "Token baru: $TOKEN"
    print_info "Tersimpan di: $TOKEN_FILE"

    echo ""
    printf "Pasang token ke relay sekarang? (y/n): "
    read CONFIRM
    if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
        print_step "Memasang token..."
        python3 "$AWP_SKILL/scripts/relay-start.py" --token "$TOKEN" --mode principal
        print_ok "Token terpasang."
    fi
    pause
}

# ============================================================
# 7. EXPORT WALLET
# ============================================================

do_export_wallet() {
    print_header
    echo "${W}=== Export Wallet ===${D}"
    echo ""
    echo "${R}PERINGATAN: Seed phrase bersifat sangat rahasia.${D}"
    echo "${R}Jangan bagikan ke siapapun!${D}"
    echo ""
    printf "Lanjutkan export? (y/n): "
    read CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "Dibatalkan."
        pause
        return
    fi

    mkdir -p "$HOME/.openclaw/workspace"
    print_step "Export wallet..."
    awp-wallet export | tee "$HOME/.openclaw/workspace/wallet_export.txt"
    print_ok "Tersimpan di: $HOME/.openclaw/workspace/wallet_export.txt"
    print_info "Jaga file ini baik-baik!"
    pause
}

# ============================================================
# 8. UPDATE MINE SKILL
# ============================================================

do_update() {
    print_header
    echo "${W}=== Update Mine Skill ===${D}"
    require_mine_dir || { pause; return; }

    print_step "Pull update mine-skill..."
    cd "$MINE_DIR" && git pull

    print_step "Pull update awp-skill..."
    if [ -d "$AWP_SKILL" ]; then
        cd "$AWP_SKILL" && git pull
    fi

    print_step "Update AWP Wallet..."
    npm install -g https://github.com/awp-core/awp-wallet

    print_step "Re-run bootstrap..."
    cd "$MINE_DIR"
    PYTHON_BIN=/usr/bin/python3 bash scripts/bootstrap.sh

    print_ok "Update selesai."
    pause
}

# ============================================================
# MAIN MENU
# ============================================================

main_menu() {
    while true; do
        print_header

        WALLET=$(cat "$WALLET_FILE" 2>/dev/null | cut -c1-12 || echo "-")
        TOKEN=$(read_token | cut -c1-16 || echo "-")

        echo "  Wallet : ${WALLET:--}..."
        echo "  Token  : ${TOKEN:--}..."
        echo ""
        echo "${C}------------------------------------------------${D}"
        echo "${W}  SETUP${D}"
        echo "${C}------------------------------------------------${D}"
        echo "  1) Full Install & Setup"
        echo "  2) Init Wallet Saja"
        echo "  8) Update Mine Skill"
        echo ""
        echo "${C}------------------------------------------------${D}"
        echo "${W}  MINING${D}"
        echo "${C}------------------------------------------------${D}"
        echo "  3) Pilih Dataset & Start Mining"
        echo "  4) Stop Mining"
        echo "  5) Cek Status"
        echo ""
        echo "${C}------------------------------------------------${D}"
        echo "${W}  WALLET${D}"
        echo "${C}------------------------------------------------${D}"
        echo "  6) Refresh Token (86400s)"
        echo "  7) Export Wallet"
        echo ""
        echo "${C}------------------------------------------------${D}"
        echo "  0) Keluar"
        echo "${C}------------------------------------------------${D}"
        echo ""
        printf "Pilih opsi [0-8]: "
        read CHOICE

        case "$CHOICE" in
            1) do_full_setup ;;
            2) do_init_wallet ;;
            3) do_start_mining ;;
            4) do_stop_mining ;;
            5) do_status ;;
            6) do_refresh_token ;;
            7) do_export_wallet ;;
            8) do_update ;;
            0) echo ""; echo "${G}Sampai jumpa!${D}"; echo ""; exit 0 ;;
            *) print_err "Pilihan tidak valid." ; sleep 1 ;;
        esac
    done
}

main_menu
