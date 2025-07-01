#!/bin/bash

# Script tự động upload code lên GitHub - Phiên bản tối ưu
# Author: mun0602
# Date: 2025-07-01

# Hàm kiểm tra và thiết lập GitHub authentication
setup_github_auth() {
    echo "Kiểm tra cấu hình GitHub..."
    
    # Kiểm tra xem đã có token GitHub chưa
    if ! git config --get github.token &> /dev/null; then
        echo "Chưa tìm thấy token GitHub. Vui lòng thiết lập:"
        echo "1. Truy cập https://github.com/settings/tokens"
        echo "2. Tạo token mới với quyền 'repo'"
        read -p "Nhập token GitHub của bạn: " github_token
        
        # Lưu token vào git config
        git config --global github.token "$github_token"
        echo "Đã lưu token GitHub."
    fi
    
    # Kiểm tra cấu hình Git cơ bản
    if ! git config --get user.name &> /dev/null || ! git config --get user.email &> /dev/null; then
        echo "Vui lòng nhập thông tin Git của bạn:"
        read -p "Nhập tên của bạn: " git_name
        read -p "Nhập email GitHub của bạn: " git_email
        
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        echo "Đã cập nhật thông tin Git."
    fi
}

# Hàm kiểm tra kết nối internet
check_internet_connection() {
    echo "Kiểm tra kết nối internet..."
    if ping -c 1 github.com &> /dev/null; then
        echo "Kết nối internet OK."
        return 0
    else
        echo "Không có kết nối internet. Vui lòng kiểm tra mạng của bạn."
        return 1
    fi
}

# Hàm kiểm tra cấu hình Git
check_git_config() {
    echo "Kiểm tra cấu hình Git..."
    if git config --get user.name &> /dev/null && git config --get user.email &> /dev/null; then
        echo "Cấu hình Git OK."
        echo "  Tên: $(git config --get user.name)"
        echo "  Email: $(git config --get user.email)"
        return 0
    else
        echo "Cấu hình Git chưa đầy đủ. Vui lòng cấu hình:"
        read -p "Nhập tên của bạn: " git_name
        read -p "Nhập email của bạn: " git_email
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        echo "Đã cập nhật cấu hình Git."
        return 0
    fi
}

# Hàm kiểm tra kết nối GitHub với số lần thử lại
check_github_connection() {
    local repo_url="$1"
    local max_attempts=3
    local attempt=1
    
    echo "Kiểm tra kết nối GitHub..."
    
    while [ $attempt -le $max_attempts ]; do
        if git ls-remote "$repo_url" &> /dev/null; then
            echo "Kết nối GitHub thành công."
            return 0
        else
            echo "Lần thử $attempt/$max_attempts: Không thể kết nối đến repository GitHub."
            if [ $attempt -lt $max_attempts ]; then
                echo "Đang thử lại sau 5 giây..."
                sleep 5
            fi
            attempt=$((attempt + 1))
        fi
    done
    
    echo "Không thể kết nối đến repository GitHub sau $max_attempts lần thử."
    echo "Vui lòng kiểm tra:"
    echo "1. URL repository có chính xác không"
    echo "2. Bạn có quyền truy cập repository không"
    echo "3. Repository có tồn tại không"
    return 1
}

# Hàm tạo commit message với thông tin chi tiết
create_commit_message() {
    local script_file="$1"
    local user_name=$(git config --get user.name)
    local user_email=$(git config --get user.email)
    local current_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "Thêm script $script_file

Author: $user_name <$user_email>
Date: $current_date
Description: Script được tạo tự động bằng auto-upload tool"
}

# Gọi hàm setup GitHub auth ngay khi bắt đầu script
echo "=== AUTO UPLOAD GITHUB SCRIPT ==="
echo "Phiên bản tối ưu - Created by mun0602"
echo "Ngày: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================="

setup_github_auth

# Nhập tên file .sh cần tạo
while true; do
    echo "Nhập tên file .sh cần tạo (không cần nhập đuôi .sh):"
    read file_name
    
    # Kiểm tra input không rỗng
    if [[ -z "$file_name" ]]; then
        echo "Tên file không được để trống!"
        continue
    fi
    
    folder_name="${file_name}-folder"
    script_file="${file_name}.sh"
    
    # Kiểm tra nếu file hoặc thư mục đã tồn tại
    if [ -d "$folder_name" ] || [ -f "$folder_name/$script_file" ]; then
        echo "Thư mục '$folder_name' hoặc file '$script_file' đã tồn tại."
        read -p "Bạn có muốn ghi đè không? (y/n): " overwrite
        if [[ "$overwrite" == "y" || "$overwrite" == "Y" ]]; then
            rm -rf "$folder_name"
            break
        else
            echo "Vui lòng chọn tên khác."
        fi
    else
        break
    fi
done

# Tạo thư mục và file
echo "Tạo thư mục '$folder_name' và file '$script_file'..."
mkdir -p "$folder_name"
cd "$folder_name"
touch "$script_file"

# Tạo template cơ bản cho script
cat > "$script_file" << 'EOF'
#!/bin/bash

# Script template được tạo tự động
# Author: $(git config --get user.name)
# Email: $(git config --get user.email)
# Date: $(date '+%Y-%m-%d %H:%M:%S')

echo "Hello World!"
echo "Script được tạo bởi: $(git config --get user.name)"

# Thêm code của bạn vào đây

EOF

# Mở file trong nano để sửa
echo "Đã tạo template cho file $script_file."
read -p "Bạn có muốn chỉnh sửa file ngay bây giờ không? (y/n): " edit_now

if [[ "$edit_now" == "y" || "$edit_now" == "Y" ]]; then
    echo "Mở nano để chỉnh sửa..."
    nano "$script_file"
fi

# Kiểm tra nếu user đã lưu file
if [ -s "$script_file" ]; then
    echo "File $script_file đã sẵn sàng."
else
    echo "File $script_file rỗng, sẽ sử dụng template mặc định."
fi

# Đặt quyền thực thi cho file
chmod +x "$script_file"
echo "Đã cấp quyền thực thi cho $script_file."

# Khởi tạo Git
echo "Khởi tạo Git repository..."
git init

# Tạo .gitignore
cat > .gitignore << 'EOF'
# OS files
.DS_Store
Thumbs.db

# Editor files
*.swp
*.swo
*~

# Logs
*.log
EOF

# Thêm file vào Git
echo "Thêm files vào Git..."
git add .

# Tạo commit với thông tin chi tiết
commit_message=$(create_commit_message "$script_file")
git commit -m "$commit_message"

echo "Commit thành công với thông tin:"
echo "  Author: $(git config --get user.name) <$(git config --get user.email)>"
echo "  Message: Thêm script $script_file"

# Thêm remote repository
while true; do
    read -p "Nhập URL repository GitHub của bạn: " repo_url
    
    # Kiểm tra URL không rỗng
    if [[ -z "$repo_url" ]]; then
        echo "URL không được để trống!"
        continue
    fi
    
    # Kiểm tra kết nối internet trước
    if ! check_internet_connection; then
        read -p "Bạn có muốn thử lại không? (y/n): " retry
        [ "$retry" != "y" ] && exit 1
        continue
    fi
    
    # Kiểm tra cấu hình Git
    if ! check_git_config; then
        read -p "Bạn có muốn thử lại không? (y/n): " retry
        [ "$retry" != "y" ] && exit 1
        continue
    fi
    
    # Kiểm tra kết nối GitHub
    if check_github_connection "$repo_url"; then
        # Kiểm tra xem remote đã tồn tại chưa
        if git remote get-url origin &> /dev/null; then
            echo "Remote origin đã tồn tại, cập nhật URL..."
            git remote set-url origin "$repo_url"
        else
            if git remote add origin "$repo_url"; then
                echo "Đã thêm remote repository thành công."
            else
                echo "Không thể thêm remote repository. Vui lòng thử lại."
                continue
            fi
        fi
        break
    else
        read -p "Bạn có muốn thử lại không? (y/n): " retry
        [ "$retry" != "y" ] && exit 1
    fi
done

# Push lên repository
echo "Đang push code lên GitHub..."
git branch -M main

# Thử push với retry mechanism
max_push_attempts=3
push_attempt=1

while [ $push_attempt -le $max_push_attempts ]; do
    echo "Lần thử push $push_attempt/$max_push_attempts..."
    
    if git push -u origin main; then
        echo "Push thành công!"
        break
    else
        echo "Push thất bại lần $push_attempt."
        
        if [ $push_attempt -lt $max_push_attempts ]; then
            echo "Đang thử lại sau 3 giây..."
            sleep 3
            
            # Thử pull trước khi push lại
            echo "Thử đồng bộ với remote..."
            git pull origin main --rebase 2>/dev/null || true
        else
            echo "Không thể push sau $max_push_attempts lần thử."
            echo "Vui lòng kiểm tra:"
            echo "1. Token GitHub có đúng không"
            echo "2. Quyền truy cập repository"
            echo "3. Thử push thủ công: git push -u origin main"
            exit 1
        fi
    fi
    
    push_attempt=$((push_attempt + 1))
done

# Thông báo hoàn tất
echo "=================================="
echo "🎉 HOÀN TẤT!"
echo "Script $script_file đã được đẩy lên GitHub repository thành công!"
echo "Repository: $repo_url"
echo "Author: $(git config --get user.name) <$(git config --get user.email)>"
echo "Commit: $(git log --oneline -1)"
echo "Thời gian: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================="

# Hiển thị thông tin hữu ích
echo "Các lệnh hữu ích:"
echo "  - Xem status: git status"
echo "  - Xem log: git log --oneline"
echo "  - Push thay đổi mới: git add . && git commit -m 'message' && git push"
