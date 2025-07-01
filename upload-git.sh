#!/bin/bash

# Script tự động upload code lên GitHub
# Phiên bản cải tiến với xử lý lỗi tốt hơn

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hàm hiển thị thông báo có màu
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Hàm kiểm tra và cài đặt dependencies
check_dependencies() {
    print_message $BLUE "Kiểm tra các công cụ cần thiết..."
    
    # Kiểm tra Git
    if ! command -v git &> /dev/null; then
        print_message $RED "Git chưa được cài đặt. Vui lòng cài đặt Git trước."
        exit 1
    fi
    
    # Kiểm tra GitHub CLI (tùy chọn)
    if command -v gh &> /dev/null; then
        print_message $GREEN "GitHub CLI đã được cài đặt."
        GH_CLI_AVAILABLE=true
    else
        print_message $YELLOW "GitHub CLI chưa được cài đặt. Sẽ sử dụng phương thức truyền thống."
        GH_CLI_AVAILABLE=false
    fi
}

# Hàm kiểm tra kết nối internet
check_internet_connection() {
    print_message $BLUE "Kiểm tra kết nối internet..."
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_message $GREEN "Kết nối internet OK."
        return 0
    else
        print_message $RED "Không có kết nối internet. Vui lòng kiểm tra mạng của bạn."
        return 1
    fi
}

# Hàm cấu hình Git user
setup_git_config() {
    print_message $BLUE "Kiểm tra cấu hình Git..."
    
    # Kiểm tra user.name
    if ! git config --get user.name &> /dev/null; then
        print_message $YELLOW "Chưa có cấu hình user.name"
        while true; do
            read -p "Nhập tên của bạn: " git_name
            if [[ -n "$git_name" ]]; then
                git config --global user.name "$git_name"
                break
            else
                print_message $RED "Tên không được để trống!"
            fi
        done
    fi
    
    # Kiểm tra user.email
    if ! git config --get user.email &> /dev/null; then
        print_message $YELLOW "Chưa có cấu hình user.email"
        while true; do
            read -p "Nhập email GitHub của bạn: " git_email
            if [[ "$git_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                git config --global user.email "$git_email"
                break
            else
                print_message $RED "Email không hợp lệ! Vui lòng nhập lại."
            fi
        done
    fi
    
    print_message $GREEN "Cấu hình Git hoàn tất:"
    print_message $GREEN "  Tên: $(git config --get user.name)"
    print_message $GREEN "  Email: $(git config --get user.email)"
}

# Hàm cấu hình GitHub authentication
setup_github_auth() {
    print_message $BLUE "Cấu hình xác thực GitHub..."
    
    if [[ "$GH_CLI_AVAILABLE" == true ]]; then
        # Sử dụng GitHub CLI
        if ! gh auth status &> /dev/null; then
            print_message $YELLOW "Chưa đăng nhập GitHub CLI. Đang khởi động quá trình đăng nhập..."
            gh auth login
        else
            print_message $GREEN "Đã đăng nhập GitHub CLI."
        fi
    else
        # Sử dụng Personal Access Token
        if ! git config --get credential.helper &> /dev/null; then
            print_message $YELLOW "Cấu hình credential helper..."
            git config --global credential.helper store
        fi
        
        print_message $YELLOW "Để đẩy code lên GitHub, bạn cần:"
        print_message $YELLOW "1. Tạo Personal Access Token tại: https://github.com/settings/tokens"
        print_message $YELLOW "2. Chọn scope: 'repo' và 'workflow'"
        print_message $YELLOW "3. Sử dụng token này thay vì mật khẩu khi được yêu cầu"
    fi
}

# Hàm tạo repository GitHub (nếu có GitHub CLI)
create_github_repo() {
    local repo_name=$1
    
    if [[ "$GH_CLI_AVAILABLE" == true ]]; then
        print_message $BLUE "Tạo repository GitHub..."
        read -p "Bạn có muốn tạo repository mới trên GitHub không? (y/n): " create_repo
        
        if [[ "$create_repo" == "y" || "$create_repo" == "Y" ]]; then
            read -p "Repository có public không? (y/n): " is_public
            
            if [[ "$is_public" == "y" || "$is_public" == "Y" ]]; then
                gh repo create "$repo_name" --public --source=. --remote=origin --push
            else
                gh repo create "$repo_name" --private --source=. --remote=origin --push
            fi
            
            print_message $GREEN "Repository đã được tạo và code đã được đẩy lên!"
            return 0
        fi
    fi
    return 1
}

# Hàm kiểm tra repository có tồn tại
check_repo_exists() {
    local repo_url=$1
    print_message $BLUE "Kiểm tra repository..."
    
    if git ls-remote "$repo_url" &> /dev/null; then
        print_message $GREEN "Repository tồn tại và có thể truy cập."
        return 0
    else
        print_message $RED "Không thể truy cập repository. Kiểm tra:"
        print_message $RED "1. URL có chính xác không"
        print_message $RED "2. Repository có tồn tại không"
        print_message $RED "3. Bạn có quyền truy cập không"
        return 1
    fi
}

# Hàm xử lý Git repository
handle_git_repository() {
    local project_dir=$1
    
    cd "$project_dir"
    
    # Kiểm tra xem có phải Git repository chưa
    if [[ ! -d ".git" ]]; then
        print_message $BLUE "Khởi tạo Git repository..."
        git init
        
        # Tạo .gitignore cơ bản
        cat > .gitignore << EOF
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp
*.swo

# Node.js
node_modules/
npm-debug.log*

# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
env/
venv/

# Logs
*.log
EOF
        print_message $GREEN "Đã tạo .gitignore"
    fi
    
    # Add và commit files
    print_message $BLUE "Thêm files vào Git..."
    git add .
    
    # Kiểm tra xem có thay đổi gì không
    if git diff --staged --quiet; then
        print_message $YELLOW "Không có thay đổi nào để commit."
        return 1
    fi
    
    # Commit với message tự động hoặc do người dùng nhập
    read -p "Nhập commit message (Enter để dùng message mặc định): " commit_msg
    if [[ -z "$commit_msg" ]]; then
        commit_msg="Update code - $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    git commit -m "$commit_msg"
    print_message $GREEN "Commit thành công: $commit_msg"
}

# Hàm đẩy code lên GitHub
push_to_github() {
    local repo_url=$1
    
    print_message $BLUE "Đẩy code lên GitHub..."
    
    # Kiểm tra remote origin
    if ! git remote get-url origin &> /dev/null; then
        print_message $BLUE "Thêm remote origin..."
        git remote add origin "$repo_url"
    else
        # Cập nhật remote URL nếu khác
        current_url=$(git remote get-url origin)
        if [[ "$current_url" != "$repo_url" ]]; then
            print_message $YELLOW "Cập nhật remote URL..."
            git remote set-url origin "$repo_url"
        fi
    fi
    
    # Kiểm tra branch hiện tại
    current_branch=$(git branch --show-current)
    if [[ -z "$current_branch" ]]; then
        current_branch="main"
        git checkout -b main
    fi
    
    print_message $BLUE "Đẩy branch '$current_branch' lên GitHub..."
    
    # Thử push với retry mechanism
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if git push -u origin "$current_branch"; then
            print_message $GREEN "Đẩy code thành công!"
            return 0
        else
            print_message $RED "Lần thử $attempt/$max_attempts thất bại."
            
            if [[ $attempt -lt $max_attempts ]]; then
                print_message $YELLOW "Thử lại sau 3 giây..."
                sleep 3
                
                # Thử pull trước khi push lại
                print_message $BLUE "Thử đồng bộ với remote..."
                git pull origin "$current_branch" --rebase 2>/dev/null || true
            fi
            
            attempt=$((attempt + 1))
        fi
    done
    
    print_message $RED "Không thể đẩy code sau $max_attempts lần thử."
    print_message $YELLOW "Có thể bạn cần:"
    print_message $YELLOW "1. Kiểm tra quyền truy cập repository"
    print_message $YELLOW "2. Đảm bảo đã cấu hình xác thực đúng"
    print_message $YELLOW "3. Kiểm tra xung đột merge"
    return 1
}

# Hàm main
main() {
    print_message $GREEN "=== SCRIPT TỰ ĐỘNG UPLOAD CODE LÊN GITHUB ==="
    
    # Kiểm tra dependencies
    check_dependencies
    
    # Kiểm tra kết nối internet
    if ! check_internet_connection; then
        exit 1
    fi
    
    # Cấu hình Git
    setup_git_config
    
    # Cấu hình GitHub auth
    setup_github_auth
    
    # Nhập thông tin project
    while true; do
        read -p "Nhập tên thư mục project: " project_name
        if [[ -n "$project_name" ]]; then
            break
        else
            print_message $RED "Tên project không được để trống!"
        fi
    done
    
    # Tạo hoặc sử dụng thư mục hiện tại
    if [[ "$project_name" == "." ]]; then
        project_dir=$(pwd)
        project_name=$(basename "$project_dir")
    else
        project_dir="$project_name"
        if [[ ! -d "$project_dir" ]]; then
            print_message $BLUE "Tạo thư mục $project_dir..."
            mkdir -p "$project_dir"
            
            # Tạo file mẫu
            echo "# $project_name" > "$project_dir/README.md"
            echo "Project được tạo tự động bằng script upload GitHub" >> "$project_dir/README.md"
        fi
    fi
    
    # Xử lý Git repository
    if ! handle_git_repository "$project_dir"; then
        print_message $YELLOW "Không có gì để upload."
        exit 0
    fi
    
    # Thử tạo repository với GitHub CLI trước
    if ! create_github_repo "$project_name"; then
        # Nếu không thể tạo tự động, yêu cầu URL repository
        while true; do
            read -p "Nhập URL repository GitHub (https://github.com/username/repo.git): " repo_url
            
            if [[ -n "$repo_url" ]]; then
                if check_repo_exists "$repo_url"; then
                    if push_to_github "$repo_url"; then
                        break
                    fi
                fi
            else
                print_message $RED "URL không được để trống!"
            fi
            
            read -p "Bạn có muốn thử lại không? (y/n): " retry
            if [[ "$retry" != "y" && "$retry" != "Y" ]]; then
                exit 1
            fi
        done
    fi
    
    # Thông báo hoàn tất
    print_message $GREEN "=== HOÀN TẤT ==="
    print_message $GREEN "Code đã được đẩy lên GitHub thành công!"
    
    if [[ "$GH_CLI_AVAILABLE" == true ]]; then
        repo_url=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$repo_url" ]]; then
            print_message $GREEN "Repository URL: $repo_url"
            print_message $BLUE "Mở repository trên trình duyệt? (y/n)"
            read -p "> " open_browser
            if [[ "$open_browser" == "y" || "$open_browser" == "Y" ]]; then
                gh repo view --web
            fi
        fi
    fi
}

# Chạy script
main "$@"
