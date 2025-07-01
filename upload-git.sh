#!/bin/bash

# Script tự động upload code lên GitHub - Phiên bản cải tiến
# Xử lý tốt hơn các vấn đề về mạng

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Hàm kiểm tra kết nối internet cải tiến
check_internet_connection() {
    print_message $BLUE "Kiểm tra kết nối internet..."
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com" "github.com")
    local connected=false
    
    for host in "${test_hosts[@]}"; do
        print_message $YELLOW "Thử kết nối đến $host..."
        
        # Thử ping với timeout ngắn
        if timeout 5 ping -c 1 "$host" &> /dev/null; then
            print_message $GREEN "Kết nối thành công đến $host"
            connected=true
            break
        elif timeout 10 curl -s --head "https://$host" &> /dev/null; then
            print_message $GREEN "Kết nối HTTP thành công đến $host"
            connected=true
            break
        else
            print_message $YELLOW "Không thể kết nối đến $host"
        fi
    done
    
    if [[ "$connected" == true ]]; then
        print_message $GREEN "Kết nối internet OK."
        return 0
    else
        print_message $RED "Không có kết nối internet."
        print_message $YELLOW "Gợi ý khắc phục:"
        print_message $YELLOW "1. Kiểm tra cáp mạng/WiFi"
        print_message $YELLOW "2. Kiểm tra cài đặt proxy/VPN"
        print_message $YELLOW "3. Thử kết nối mạng khác"
        print_message $YELLOW "4. Khởi động lại router"
        
        read -p "Bạn có muốn tiếp tục mà không kiểm tra internet? (y/n): " skip_internet
        if [[ "$skip_internet" == "y" || "$skip_internet" == "Y" ]]; then
            print_message $YELLOW "Bỏ qua kiểm tra internet..."
            return 0
        else
            return 1
        fi
    fi
}

# Hàm kiểm tra dependencies
check_dependencies() {
    print_message $BLUE "Kiểm tra các công cụ cần thiết..."
    
    # Kiểm tra Git
    if ! command -v git &> /dev/null; then
        print_message $RED "Git chưa được cài đặt."
        print_message $YELLOW "Cài đặt Git:"
        print_message $YELLOW "Ubuntu/Debian: sudo apt update && sudo apt install git"
        print_message $YELLOW "CentOS/RHEL: sudo yum install git"
        print_message $YELLOW "macOS: brew install git"
        exit 1
    else
        print_message $GREEN "Git đã được cài đặt: $(git --version)"
    fi
    
    # Kiểm tra curl
    if ! command -v curl &> /dev/null; then
        print_message $YELLOW "curl chưa được cài đặt, sẽ sử dụng wget thay thế."
        if ! command -v wget &> /dev/null; then
            print_message $RED "Cần cài đặt curl hoặc wget để kiểm tra kết nối."
        fi
    fi
    
    # Kiểm tra GitHub CLI
    if command -v gh &> /dev/null; then
        print_message $GREEN "GitHub CLI đã được cài đặt: $(gh --version | head -1)"
        GH_CLI_AVAILABLE=true
    else
        print_message $YELLOW "GitHub CLI chưa được cài đặt."
        print_message $YELLOW "Để cài đặt: https://cli.github.com/"
        GH_CLI_AVAILABLE=false
    fi
}

# Hàm cấu hình Git user
setup_git_config() {
    print_message $BLUE "Kiểm tra cấu hình Git..."
    
    local git_name=$(git config --get user.name 2>/dev/null)
    local git_email=$(git config --get user.email 2>/dev/null)
    
    if [[ -z "$git_name" ]]; then
        print_message $YELLOW "Chưa có cấu hình user.name"
        while true; do
            read -p "Nhập tên của bạn: " new_git_name
            if [[ -n "$new_git_name" ]]; then
                git config --global user.name "$new_git_name"
                print_message $GREEN "Đã cấu hình user.name: $new_git_name"
                break
            else
                print_message $RED "Tên không được để trống!"
            fi
        done
    else
        print_message $GREEN "User.name: $git_name"
    fi
    
    if [[ -z "$git_email" ]]; then
        print_message $YELLOW "Chưa có cấu hình user.email"
        while true; do
            read -p "Nhập email GitHub của bạn: " new_git_email
            if [[ "$new_git_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                git config --global user.email "$new_git_email"
                print_message $GREEN "Đã cấu hình user.email: $new_git_email"
                break
            else
                print_message $RED "Email không hợp lệ! Vui lòng nhập lại."
            fi
        done
    else
        print_message $GREEN "User.email: $git_email"
    fi
}

# Hàm cấu hình GitHub authentication
setup_github_auth() {
    print_message $BLUE "Cấu hình xác thực GitHub..."
    
    if [[ "$GH_CLI_AVAILABLE" == true ]]; then
        if ! gh auth status &> /dev/null; then
            print_message $YELLOW "Chưa đăng nhập GitHub CLI."
            print_message $BLUE "Đang khởi động quá trình đăng nhập..."
            
            # Thử đăng nhập với browser
            if gh auth login --web; then
                print_message $GREEN "Đăng nhập GitHub CLI thành công!"
            else
                print_message $YELLOW "Đăng nhập web thất bại, thử phương thức token..."
                gh auth login --with-token
            fi
        else
            print_message $GREEN "Đã đăng nhập GitHub CLI."
        fi
    else
        # Cấu hình credential helper
        git config --global credential.helper store
        
        print_message $YELLOW "Để đẩy code lên GitHub, bạn cần Personal Access Token:"
        print_message $YELLOW "1. Truy cập: https://github.com/settings/tokens"
        print_message $YELLOW "2. Click 'Generate new token (classic)'"
        print_message $YELLOW "3. Chọn scope: 'repo' và 'workflow'"
        print_message $YELLOW "4. Copy token và dùng thay mật khẩu khi push"
        print_message $YELLOW ""
        print_message $BLUE "Token sẽ được lưu tự động sau lần đầu sử dụng."
    fi
}

# Hàm tạo repository trên GitHub
create_github_repo() {
    local repo_name=$1
    
    if [[ "$GH_CLI_AVAILABLE" == true ]]; then
        print_message $BLUE "Tạo repository GitHub với GitHub CLI..."
        
        read -p "Bạn có muốn tạo repository mới '$repo_name' trên GitHub không? (y/n): " create_repo
        
        if [[ "$create_repo" == "y" || "$create_repo" == "Y" ]]; then
            read -p "Repository có public không? (y/n): " is_public
            
            local visibility_flag="--private"
            if [[ "$is_public" == "y" || "$is_public" == "Y" ]]; then
                visibility_flag="--public"
            fi
            
            if gh repo create "$repo_name" $visibility_flag --source=. --remote=origin; then
                print_message $GREEN "Repository '$repo_name' đã được tạo!"
                
                # Push code
                if git push -u origin main 2>/dev/null || git push -u origin master; then
                    print_message $GREEN "Code đã được đẩy lên repository!"
                    return 0
                else
                    print_message $YELLOW "Repository đã tạo nhưng push thất bại. Thử push thủ công."
                fi
            else
                print_message $RED "Không thể tạo repository. Có thể tên đã tồn tại."
            fi
        fi
    fi
    return 1
}

# Hàm xử lý Git repository
handle_git_repository() {
    local project_dir=$1
    
    cd "$project_dir" || exit 1
    
    # Khởi tạo Git nếu chưa có
    if [[ ! -d ".git" ]]; then
        print_message $BLUE "Khởi tạo Git repository..."
        git init
        
        # Tạo .gitignore
        if [[ ! -f ".gitignore" ]]; then
            print_message $BLUE "Tạo .gitignore..."
            cat > .gitignore << 'EOF'
# OS files
.DS_Store
.DS_Store?
._*
Thumbs.db
ehthumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Logs
*.log
npm-debug.log*

# Dependencies
node_modules/
__pycache__/
*.pyc
venv/
env/

# Build outputs
dist/
build/
*.o
*.exe
EOF
        fi
    fi
    
    # Kiểm tra branch chính
    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' 2>/dev/null)
    if [[ -z "$default_branch" ]]; then
        default_branch=$(git branch --show-current 2>/dev/null)
        if [[ -z "$default_branch" ]]; then
            default_branch="main"
            git checkout -b main 2>/dev/null || git branch -M main
        fi
    fi
    
    # Add files
    print_message $BLUE "Thêm files vào Git..."
    git add .
    
    # Kiểm tra staged changes
    if git diff --staged --quiet; then
        print_message $YELLOW "Không có thay đổi nào để commit."
        
        # Kiểm tra untracked files
        if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
            print_message $YELLOW "Có files chưa được track. Thử add lại..."
            git add -A
        fi
        
        if git diff --staged --quiet; then
            return 1
        fi
    fi
    
    # Commit
    read -p "Nhập commit message (Enter để dùng mặc định): " commit_msg
    if [[ -z "$commit_msg" ]]; then
        commit_msg="Auto commit - $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    git commit -m "$commit_msg"
    print_message $GREEN "Commit thành công: $commit_msg"
    return 0
}

# Hàm đẩy code lên GitHub
push_to_github() {
    local repo_url=$1
    
    # Thêm remote nếu chưa có
    if ! git remote get-url origin &> /dev/null; then
        print_message $BLUE "Thêm remote origin..."
        git remote add origin "$repo_url"
    fi
    
    # Lấy branch hiện tại
    local current_branch=$(git branch --show-current)
    
    print_message $BLUE "Đẩy code lên GitHub (branch: $current_branch)..."
    
    # Thử push với các phương án khác nhau
    local success=false
    
    # Phương án 1: Push thông thường
    if git push -u origin "$current_branch"; then
        success=true
    # Phương án 2: Force push (cẩn thận)
    elif [[ "$current_branch" == "main" ]] || [[ "$current_branch" == "master" ]]; then
        print_message $YELLOW "Push thông thường thất bại. Thử force push..."
        read -p "Bạn có chắc muốn force push không? (y/n): " force_confirm
        if [[ "$force_confirm" == "y" ]]; then
            if git push -u origin "$current_branch" --force; then
                success=true
            fi
        fi
    fi
    
    if [[ "$success" == true ]]; then
        print_message $GREEN "Đẩy code thành công!"
        return 0
    else
        print_message $RED "Không thể đẩy code."
        print_message $YELLOW "Khắc phục:"
        print_message $YELLOW "1. Kiểm tra quyền truy cập repository"
        print_message $YELLOW "2. Đảm bảo repository tồn tại"
        print_message $YELLOW "3. Kiểm tra token/credentials"
        return 1
    fi
}

# Offline mode - không cần internet
offline_mode() {
    print_message $YELLOW "=== CHẾđộ OFFLINE ==="
    print_message $BLUE "Thiết lập Git repository cục bộ..."
    
    read -p "Nhập tên project: " project_name
    if [[ -z "$project_name" ]]; then
        project_name="my-project"
    fi
    
    mkdir -p "$project_name"
    cd "$project_name"
    
    # Tạo README nếu chưa có
    if [[ ! -f "README.md" ]]; then
        echo "# $project_name" > README.md
        echo "" >> README.md
        echo "Project được tạo tự động." >> README.md
    fi
    
    if handle_git_repository "."; then
        print_message $GREEN "Git repository đã được thiết lập!"
        print_message $YELLOW "Để đẩy lên GitHub khi có mạng:"
        print_message $YELLOW "1. git remote add origin <repo-url>"
        print_message $YELLOW "2. git push -u origin main"
    fi
}

# Hàm main
main() {
    print_message $GREEN "=== SCRIPT TỰ ĐỘNG UPLOAD CODE LÊN GITHUB ==="
    print_message $GREEN "Phiên bản cải tiến - Xử lý offline"
    
    # Kiểm tra dependencies
    check_dependencies
    
    # Cấu hình Git (không cần internet)
    setup_git_config
    
    # Kiểm tra internet
    if ! check_internet_connection; then
        print_message $YELLOW "Chạy ở chế độ offline?"
        read -p "(y/n): " run_offline
        if [[ "$run_offline" == "y" || "$run_offline" == "Y" ]]; then
            offline_mode
            exit 0
        else
            exit 1
        fi
    fi
    
    # Cấu hình GitHub auth
    setup_github_auth
    
    # Xử lý project
    read -p "Nhập tên project (hoặc '.' cho thư mục hiện tại): " project_name
    
    if [[ "$project_name" == "." ]]; then
        project_dir=$(pwd)
        project_name=$(basename "$project_dir")
    else
        project_dir="$project_name"
        if [[ ! -d "$project_dir" ]]; then
            mkdir -p "$project_dir"
            echo "# $project_name" > "$project_dir/README.md"
        fi
    fi
    
    # Xử lý Git
    if ! handle_git_repository "$project_dir"; then
        print_message $YELLOW "Không có gì để upload."
        exit 0
    fi
    
    # Thử tạo repo tự động trước
    if ! create_github_repo "$project_name"; then
        # Nhập URL thủ công
        while true; do
            read -p "Nhập URL repository GitHub: " repo_url
            if [[ -n "$repo_url" ]]; then
                if push_to_github "$repo_url"; then
                    break
                fi
            fi
            
            read -p "Thử lại? (y/n): " retry
            if [[ "$retry" != "y" ]]; then
                exit 1
            fi
        done
    fi
    
    print_message $GREEN "=== HOÀN TẤT ==="
    print_message $GREEN "Code đã được xử lý thành công!"
}

# Chạy script
main "$@"
