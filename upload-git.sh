#!/bin/bash

# GitHub Script Creator - Phiên bản đơn giản nhưng an toàn
# Giữ logic gốc, thêm SSH setup tự động

# Colors cho output đẹp hơn
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hàm log đơn giản
log() {
    case "$1" in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $2" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $2" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $2" ;;
    esac
}

# Hàm kiểm tra và tạo SSH key nếu cần
setup_ssh_key() {
    log "INFO" "Kiểm tra SSH key..."
    
    # Kiểm tra xem đã có SSH key chưa
    if [ -f "$HOME/.ssh/id_ed25519" ] || [ -f "$HOME/.ssh/id_rsa" ]; then
        log "INFO" "Đã có SSH key"
        return 0
    fi
    
    log "WARN" "Chưa có SSH key. Đang tạo SSH key mới..."
    
    # Lấy email từ git config hoặc hỏi user
    email=$(git config --global user.email 2>/dev/null || echo "")
    if [ -z "$email" ]; then
        read -p "Nhập email GitHub của bạn: " email
        git config --global user.email "$email"
    fi
    
    # Tạo SSH key Ed25519
    ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519" -N ""
    
    if [ $? -eq 0 ]; then
        log "INFO" "✅ Đã tạo SSH key thành công!"
        
        # Hiển thị public key
        echo
        echo "📋 QUAN TRỌNG: Copy SSH key này và thêm vào GitHub:"
        echo "🔗 Truy cập: https://github.com/settings/keys"
        echo
        echo -e "${BLUE}$(cat ~/.ssh/id_ed25519.pub)${NC}"
        echo
        
        # Auto copy to clipboard nếu có thể
        if command -v clip.exe >/dev/null 2>&1; then
            cat ~/.ssh/id_ed25519.pub | clip.exe
            log "INFO" "✅ Đã copy SSH key vào clipboard!"
        fi
        
        echo "Các bước thêm SSH key:"
        echo "1. Truy cập https://github.com/settings/keys"
        echo "2. Click 'New SSH key'"
        echo "3. Paste key ở trên vào ô 'Key'"
        echo "4. Click 'Add SSH key'"
        echo
        read -p "Nhấn Enter sau khi đã thêm SSH key vào GitHub..."
        
    else
        log "ERROR" "Không thể tạo SSH key"
        return 1
    fi
}

# Hàm test SSH connection
test_ssh_connection() {
    log "INFO" "Kiểm tra kết nối SSH với GitHub..."
    
    # Start ssh-agent nếu cần
    if ! pgrep -x "ssh-agent" > /dev/null; then
        eval "$(ssh-agent -s)" > /dev/null
    fi
    
    # Add SSH key
    ssh-add ~/.ssh/id_ed25519 2>/dev/null || ssh-add ~/.ssh/id_rsa 2>/dev/null
    
    # Test connection
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        log "INFO" "🎉 SSH connection thành công!"
        return 0
    else
        log "WARN" "SSH connection thất bại. Có thể cần thêm SSH key vào GitHub."
        return 1
    fi
}

# Hàm kiểm tra và thiết lập GitHub authentication
setup_github_auth() {
    log "INFO" "Thiết lập xác thực GitHub..."
    
    # Ưu tiên SSH key trước
    if setup_ssh_key && test_ssh_connection; then
        log "INFO" "Sử dụng SSH authentication"
        return 0
    fi
    
    # Fallback sang GitHub CLI nếu có
    if command -v gh >/dev/null 2>&1; then
        if gh auth status >/dev/null 2>&1; then
            log "INFO" "GitHub CLI đã được xác thực"
            return 0
        else
            read -p "Bạn có muốn đăng nhập GitHub CLI không? (y/n): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                gh auth login
                return $?
            fi
        fi
    fi
    
    # Fallback cuối: hướng dẫn user
    log "WARN" "Không thể thiết lập xác thực tự động"
    echo
    echo "Các phương án khác:"
    echo "1. Cài GitHub CLI: winget install GitHub.cli"
    echo "2. Sử dụng HTTPS với Personal Access Token"
    echo "   - Tạo token: https://github.com/settings/tokens"
    echo "   - Dùng username + token thay password"
    echo
    read -p "Tiếp tục với HTTPS? (y/n): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi
    
    exit 1
}

# Hàm kiểm tra cấu hình Git
check_git_config() {
    log "INFO" "Kiểm tra cấu hình Git..."
    
    if ! git config --get user.name &> /dev/null || ! git config --get user.email &> /dev/null; then
        echo "Vui lòng nhập thông tin Git của bạn:"
        read -p "Nhập tên của bạn: " git_name
        read -p "Nhập email GitHub của bạn: " git_email
        
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        log "INFO" "Đã cập nhật cấu hình Git"
    else
        log "INFO" "Cấu hình Git OK"
    fi
}

# Hàm kiểm tra kết nối internet
check_internet_connection() {
    log "INFO" "Kiểm tra kết nối internet..."
    if ping -c 1 github.com &> /dev/null; then
        log "INFO" "Kết nối internet OK"
        return 0
    else
        log "ERROR" "Không có kết nối internet"
        return 1
    fi
}

# Hàm kiểm tra kết nối GitHub với retry
check_github_connection() {
    local repo_url="$1"
    local max_attempts=3
    local attempt=1
    
    log "INFO" "Kiểm tra kết nối GitHub..."
    
    while [ $attempt -le $max_attempts ]; do
        if git ls-remote "$repo_url" &> /dev/null; then
            log "INFO" "Kết nối GitHub thành công"
            return 0
        else
            log "WARN" "Lần thử $attempt/$max_attempts: Không thể kết nối"
            if [ $attempt -lt $max_attempts ]; then
                echo "Đang thử lại sau 3 giây..."
                sleep 3
            fi
            attempt=$((attempt + 1))
        fi
    done
    
    log "ERROR" "Không thể kết nối đến repository sau $max_attempts lần thử"
    echo "Vui lòng kiểm tra:"
    echo "1. URL repository có chính xác không"
    echo "2. Bạn có quyền truy cập repository không"
    echo "3. Repository có tồn tại không"
    return 1
}

# ============================ MAIN SCRIPT ============================

echo "🚀 GitHub Script Creator - Phiên bản đơn giản"
echo "=============================================="

# Thiết lập GitHub authentication
setup_github_auth

# Kiểm tra cấu hình Git
check_git_config

# Nhập tên file .sh cần tạo
while true; do
    echo
    echo "Nhập tên file .sh cần tạo (không cần nhập đuôi .sh):"
    read file_name
    
    if [ -z "$file_name" ]; then
        log "ERROR" "Tên file không được để trống"
        continue
    fi
    
    folder_name="${file_name}-folder"
    script_file="${file_name}.sh"
    
    # Kiểm tra nếu file hoặc thư mục đã tồn tại
    if [ -d "$folder_name" ] || [ -f "$folder_name/$script_file" ]; then
        log "WARN" "Thư mục hoặc file đã tồn tại. Vui lòng chọn tên khác"
    else
        break
    fi
done

# Tạo thư mục và file
log "INFO" "Tạo thư mục: $folder_name"
mkdir -p "$folder_name"
cd "$folder_name"

# Tạo template script
cat > "$script_file" << 'EOF'
#!/bin/bash

# =============================================================================
# Script Name: [TÊN SCRIPT]
# Description: [MÔ TẢ SCRIPT]
# Author: [TÊN TÁC GIẢ]
# Created: [NGÀY TẠO]
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Main function
main() {
    echo "Hello World!"
    echo "Script đang chạy..."
    
    # Thêm code của bạn ở đây
    
    echo "Hoàn thành!"
}

# Run main function
main "$@"
EOF

# Replace placeholders
sed -i "s/\[NGÀY TẠO\]/$(date +%Y-%m-%d)/g" "$script_file"
log "INFO" "Đã tạo file $script_file với template cơ bản"

# Mở file trong editor để sửa
echo
log "INFO" "Mở editor để chỉnh sửa file..."
echo "💡 Tip: Thay thế [TÊN SCRIPT], [MÔ TẢ SCRIPT], [TÊN TÁC GIẢ] trong file"
echo

# Sử dụng editor ưa thích
if command -v code >/dev/null 2>&1; then
    code "$script_file"
    read -p "Nhấn Enter sau khi đã chỉnh sửa xong trong VS Code..."
elif command -v vim >/dev/null 2>&1; then
    vim "$script_file"
else
    nano "$script_file"
fi

# Kiểm tra nếu user đã lưu file
if [ -s "$script_file" ]; then
    log "INFO" "Đã lưu file $script_file"
else
    log "ERROR" "File $script_file rỗng. Hủy thao tác"
    exit 1
fi

# Đặt quyền thực thi cho file
chmod +x "$script_file"
log "INFO" "Đã đặt quyền thực thi cho file"

# Khởi tạo Git
log "INFO" "Khởi tạo Git repository..."
git init > /dev/null

# Thêm file vào Git
git add "$script_file"
git commit -m "Thêm script $script_file

- Tạo ngày: $(date '+%Y-%m-%d %H:%M:%S')
- Tác giả: $(git config user.name)" > /dev/null

log "INFO" "Đã commit file vào Git"

# Thêm remote repository
while true; do
    echo
    read -p "Nhập URL repository GitHub của bạn: " repo_url
    
    if [ -z "$repo_url" ]; then
        log "ERROR" "URL không được để trống"
        continue
    fi
    
    # Kiểm tra kết nối internet trước
    if ! check_internet_connection; then
        read -p "Bạn có muốn thử lại không? (y/n): " retry
        [ "$retry" != "y" ] && exit 1
        continue
    fi
    
    # Kiểm tra kết nối GitHub
    if check_github_connection "$repo_url"; then
        if git remote add origin "$repo_url" 2>/dev/null; then
            log "INFO" "Đã thêm remote repository thành công"
            break
        else
            log "WARN" "Remote đã tồn tại, đang cập nhật..."
            git remote set-url origin "$repo_url"
            break
        fi
    else
        read -p "Bạn có muốn thử lại không? (y/n): " retry
        [ "$retry" != "y" ] && exit 1
    fi
done

# Push lên repository
log "INFO" "Đang đẩy code lên GitHub..."
git branch -M main

if git push -u origin main; then
    echo
    log "INFO" "🎉 Hoàn thành! Script đã được đẩy lên GitHub"
    log "INFO" "📁 Thư mục: $(pwd)"
    log "INFO" "📄 File: $script_file"
    log "INFO" "🔗 Repository: $repo_url"
else
    log "ERROR" "Có lỗi khi đẩy code lên GitHub"
    echo
    echo "Có thể do:"
    echo "1. SSH key chưa được add vào GitHub"
    echo "2. Không có quyền push vào repository"
    echo "3. Repository không tồn tại"
    exit 1
fi
