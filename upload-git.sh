#!/bin/bash

# =============================================================================
# GITHUB SCRIPT CREATOR - Phiên bản tối ưu
# Tác giả: Your Name
# Mô tả: Tạo và đẩy script bash lên GitHub một cách an toàn và hiệu quả
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ======================== CONSTANTS & VARIABLES ========================
# Handle script executed via curl | bash
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    readonly SCRIPT_DIR="$(pwd)"
fi

readonly CONFIG_FILE="$HOME/.github_script_config"
# Use Windows-compatible temp path
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    readonly LOG_FILE="$HOME/github_script_$(date +%Y%m%d_%H%M%S).log"
else
    readonly LOG_FILE="/tmp/github_script_$(date +%Y%m%d_%H%M%S).log"
fi

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Default values
DEFAULT_EDITOR="${EDITOR:-nano}"
DEFAULT_BRANCH="main"

# ======================== UTILITY FUNCTIONS ========================

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $message" | tee -a "$LOG_FILE" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$LOG_FILE" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $message" | tee -a "$LOG_FILE" ;;
    esac
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    
    printf "\r${BLUE}["
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $((width - filled)) | tr ' ' '░'
    printf "] %d%%${NC}" $percentage
    
    if [ $current -eq $total ]; then
        echo
    fi
}

# Cleanup function
cleanup() {
    log "INFO" "Đang dọn dẹp tài nguyên..."
    # Remove temp files if needed
    local temp_pattern="temp_script_$"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        [ -f "$HOME/$temp_pattern" ] && rm -f "$HOME/$temp_pattern"
    else
        [ -f "/tmp/$temp_pattern" ] && rm -f "/tmp/$temp_pattern" 
    fi
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

# ======================== VALIDATION FUNCTIONS ========================

# Validate GitHub URL
validate_github_url() {
    local url="$1"
    
    if [[ ! "$url" =~ ^https://github\.com/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+\.git$ ]] && 
       [[ ! "$url" =~ ^git@github\.com:[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+\.git$ ]]; then
        log "ERROR" "URL không hợp lệ! Format: https://github.com/user/repo.git hoặc git@github.com:user/repo.git"
        return 1
    fi
    return 0
}

# Validate file name
validate_filename() {
    local filename="$1"
    
    if [[ ! "$filename" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log "ERROR" "Tên file chỉ được chứa chữ cái, số, dấu gạch dưới và dấu gạch ngang"
        return 1
    fi
    
    if [ ${#filename} -gt 50 ]; then
        log "ERROR" "Tên file quá dài (tối đa 50 ký tự)"
        return 1
    fi
    
    return 0
}

# ======================== CONFIGURATION FUNCTIONS ========================

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log "INFO" "Đã tải cấu hình từ $CONFIG_FILE"
    fi
}

# Save configuration
save_config() {
    local git_name="$1"
    local git_email="$2"
    
    cat > "$CONFIG_FILE" << EOF
# GitHub Script Creator Configuration
DEFAULT_AUTHOR="$git_name"
DEFAULT_EMAIL="$git_email"
DEFAULT_EDITOR="$DEFAULT_EDITOR"
LAST_UPDATED="$(date)"
EOF
    log "INFO" "Đã lưu cấu hình vào $CONFIG_FILE"
}

# ======================== GITHUB FUNCTIONS ========================

# Check if GitHub CLI is available and authenticated
check_github_cli() {
    if command -v gh >/dev/null 2>&1; then
        if gh auth status >/dev/null 2>&1; then
            log "INFO" "GitHub CLI đã được xác thực"
            return 0
        else
            log "WARN" "GitHub CLI chưa được xác thực"
            read -p "Bạn có muốn đăng nhập GitHub CLI không? (y/n): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                gh auth login
                return $?
            fi
        fi
    else
        log "WARN" "GitHub CLI không được cài đặt"
    fi
    return 1
}

# Check SSH connection to GitHub
check_ssh_github() {
    log "INFO" "Kiểm tra kết nối SSH với GitHub..."
    
    # For Windows Git Bash, may need different approach
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        if ssh -o ConnectTimeout=10 -o BatchMode=yes -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            log "INFO" "SSH connection với GitHub thành công"
            return 0
        fi
    else
        if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            log "INFO" "SSH connection với GitHub thành công"
            return 0
        fi
    fi
    
    log "WARN" "SSH connection với GitHub thất bại"
    return 1
}

# Setup authentication method
setup_auth() {
    log "INFO" "Thiết lập phương thức xác thực..."
    
    # Try GitHub CLI first
    if check_github_cli; then
        return 0
    fi
    
    # Try SSH
    if check_ssh_github; then
        return 0
    fi
    
    # Fallback instructions
    echo
    log "WARN" "Không tìm thấy phương thức xác thực nào!"
    echo "Vui lòng chọn một trong các cách sau:"
    echo "1. Cài đặt GitHub CLI: https://cli.github.com/"
    echo "2. Thiết lập SSH key: https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
    echo
    read -p "Nhấn Enter để tiếp tục sau khi thiết lập xác thực..." -r
    
    return 1
}

# ======================== GIT FUNCTIONS ========================

# Setup Git configuration
setup_git_config() {
    local git_name git_email
    
    # Try to get from existing config
    git_name=$(git config --global user.name 2>/dev/null || echo "${DEFAULT_AUTHOR:-}")
    git_email=$(git config --global user.email 2>/dev/null || echo "${DEFAULT_EMAIL:-}")
    
    if [ -z "$git_name" ] || [ -z "$git_email" ]; then
        log "INFO" "Thiết lập thông tin Git..."
        
        if [ -z "$git_name" ]; then
            read -p "Nhập tên của bạn: " git_name
        fi
        
        if [ -z "$git_email" ]; then
            read -p "Nhập email GitHub của bạn: " git_email
        fi
        
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        
        # Save to config for next time
        save_config "$git_name" "$git_email"
    fi
    
    log "INFO" "Git config: $git_name <$git_email>"
}

# ======================== FILE MANAGEMENT FUNCTIONS ========================

# Get unique filename
get_unique_filename() {
    local base_name="$1"
    local counter=1
    local folder_name="${base_name}-folder"
    
    while [ -d "$folder_name" ]; do
        folder_name="${base_name}-${counter}-folder"
        counter=$((counter + 1))
    done
    
    echo "$folder_name"
}

# Create script template
create_script_template() {
    local script_file="$1"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash

# =============================================================================
# SCRIPT NAME
# Mô tả: Mô tả ngắn gọn về script
# Tác giả: Your Name
# Ngày tạo: $(date +%Y-%m-%d)
# =============================================================================

set -euo pipefail

# Hàm chính
main() {
    echo "Hello World!"
    # Thêm code của bạn ở đây
}

# Chạy hàm chính nếu script được execute trực tiếp
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

    # Replace date placeholder
    sed -i "s/\$(date +%Y-%m-%d)/$(date +%Y-%m-%d)/g" "$script_file"
}

# ======================== MAIN WORKFLOW FUNCTIONS ========================

# Get file name from user
get_filename() {
    local filename
    
    while true; do
        echo
        read -p "Nhập tên file script (không cần .sh): " filename
        
        if [ -z "$filename" ]; then
            log "ERROR" "Tên file không được để trống"
            continue
        fi
        
        if validate_filename "$filename"; then
            echo "$filename"
            return 0
        fi
    done
}

# Get repository URL
get_repo_url() {
    local repo_url
    
    while true; do
        echo
        read -p "Nhập URL repository GitHub: " repo_url
        
        if [ -z "$repo_url" ]; then
            log "ERROR" "URL không được để trống"
            continue
        fi
        
        if validate_github_url "$repo_url"; then
            echo "$repo_url"
            return 0
        fi
    done
}

# Test repository connection
test_repo_connection() {
    local repo_url="$1"
    local max_attempts=3
    local attempt=1
    
    log "INFO" "Kiểm tra kết nối repository..."
    
    while [ $attempt -le $max_attempts ]; do
        show_progress $attempt $max_attempts
        
        if timeout 10 git ls-remote "$repo_url" >/dev/null 2>&1; then
            log "INFO" "Kết nối repository thành công"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log "WARN" "Lần thử $attempt/$max_attempts thất bại, thử lại sau 3 giây..."
            sleep 3
        fi
        
        attempt=$((attempt + 1))
    done
    
    log "ERROR" "Không thể kết nối đến repository sau $max_attempts lần thử"
    return 1
}

# Main workflow
main_workflow() {
    local filename folder_name script_file repo_url
    local total_steps=8
    local current_step=0
    
    echo
    echo "🚀 GITHUB SCRIPT CREATOR - Phiên bản tối ưu"
    echo "=================================================="
    
    # Step 1: Load config
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps
    load_config
    
    # Step 2: Setup authentication
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps
    if ! setup_auth; then
        log "WARN" "Tiếp tục mà không xác thực (có thể gặp lỗi khi push)"
    fi
    
    # Step 3: Setup Git config
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps
    setup_git_config
    
    # Step 4: Get filename
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps
    filename=$(get_filename)
    folder_name=$(get_unique_filename "$filename")
    script_file="${filename}.sh"
    
    # Step 5: Create directory and file
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps
    log "INFO" "Tạo thư mục: $folder_name"
    mkdir -p "$folder_name"
    cd "$folder_name"
    
    create_script_template "$script_file"
    chmod +x "$script_file"
    log "INFO" "Đã tạo file $script_file với template cơ bản"
    
    # Step 6: Edit file
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps
    log "INFO" "Mở editor để chỉnh sửa file..."
    
    if ! "$DEFAULT_EDITOR" "$script_file"; then
        log "ERROR" "Có lỗi khi chỉnh sửa file"
        exit 1
    fi
    
    if [ ! -s "$script_file" ]; then
        log "ERROR" "File rỗng hoặc không được lưu"
        exit 1
    fi
    
    # Step 7: Git operations
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps
    
    git init >/dev/null 2>&1
    git add "$script_file"
    git commit -m "Thêm script $script_file

- Tạo bởi GitHub Script Creator
- Ngày tạo: $(date '+%Y-%m-%d %H:%M:%S')
- Tác giả: $(git config user.name)" >/dev/null 2>&1
    
    # Step 8: Push to GitHub
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps
    
    repo_url=$(get_repo_url)
    
    if ! test_repo_connection "$repo_url"; then
        log "ERROR" "Không thể kết nối đến repository"
        exit 1
    fi
    
    git remote add origin "$repo_url" 2>/dev/null || true
    git branch -M "$DEFAULT_BRANCH"
    
    log "INFO" "Đang đẩy code lên GitHub..."
    if git push -u origin "$DEFAULT_BRANCH" 2>&1 | tee -a "$LOG_FILE"; then
        echo
        log "INFO" "🎉 Hoàn thành! Script đã được đẩy lên GitHub thành công"
        log "INFO" "📁 Thư mục: $(pwd)"
        log "INFO" "📄 File: $script_file"
        log "INFO" "🔗 Repository: $repo_url"
    else
        log "ERROR" "Có lỗi khi đẩy code lên GitHub"
        exit 1
    fi
}

# ======================== COMMAND LINE INTERFACE ========================

# Show help
show_help() {
    cat << EOF
GitHub Script Creator - Phiên bản tối ưu

CÁCH DÙNG:
    $0 [OPTIONS]

CÁC TÙRY CHỌN:
    -h, --help          Hiển thị hướng dẫn này
    -n, --name NAME     Tên file script (không cần .sh)
    -r, --repo URL      URL repository GitHub
    -e, --editor EDITOR Editor để chỉnh sửa (mặc định: nano)
    -v, --verbose       Hiển thị thông tin chi tiết
    --version           Hiển thị phiên bản

VÍ DỤ:
    $0                                  # Chế độ interactive
    $0 -n backup-script                 # Tạo script với tên cụ thể
    $0 -n test -r https://github.com/user/repo.git

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--name)
                if [ -n "${2:-}" ]; then
                    PRESET_FILENAME="$2"
                    shift 2
                else
                    log "ERROR" "Thiếu tên file cho option -n/--name"
                    exit 1
                fi
                ;;
            -r|--repo)
                if [ -n "${2:-}" ]; then
                    PRESET_REPO="$2"
                    shift 2
                else
                    log "ERROR" "Thiếu URL repository cho option -r/--repo"
                    exit 1
                fi
                ;;
            -e|--editor)
                if [ -n "${2:-}" ]; then
                    DEFAULT_EDITOR="$2"
                    shift 2
                else
                    log "ERROR" "Thiếu tên editor cho option -e/--editor"
                    exit 1
                fi
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            --version)
                echo "GitHub Script Creator v2.0"
                exit 0
                ;;
            *)
                log "ERROR" "Tùy chọn không hợp lệ: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ======================== MAIN EXECUTION ========================

main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Create log file
    touch "$LOG_FILE"
    log "INFO" "Bắt đầu script - Log file: $LOG_FILE"
    
    # Run main workflow
    main_workflow
    
    # Final cleanup
    log "INFO" "Script hoàn thành thành công!"
}

# Execute main function if script is run directly
# Handle both normal execution and curl | bash execution
if [[ -z "${BASH_SOURCE[0]:-}" ]] || [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
