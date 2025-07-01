#!/bin/bash

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

# Gọi hàm setup GitHub auth ngay khi bắt đầu script
setup_github_auth

# Nhập tên file .sh cần tạo
while true; do
    echo "Nhập tên file .sh cần tạo (không cần nhập đuôi .sh):"
    read file_name
    folder_name="${file_name}-folder"
    script_file="${file_name}.sh"
    
    # Kiểm tra nếu file hoặc thư mục đã tồn tại
    if [ -d "$folder_name" ] || [ -f "$folder_name/$script_file" ]; then
        echo "Thư mục hoặc file đã tồn tại. Vui lòng chọn tên khác."
    else
        break
    fi
done

# Tạo thư mục và file
mkdir -p "$folder_name"
cd "$folder_name"
touch "$script_file"

# Mở file trong nano để sửa
echo "Đã tạo file $script_file. Mở nano để chỉnh sửa..."
nano "$script_file"

# Kiểm tra nếu user đã lưu file
if [ -s "$script_file" ]; then
    echo "Đã lưu file $script_file."
else
    echo "File $script_file rỗng. Hủy thao tác."
    exit 1
fi

# Đặt quyền thực thi cho file
chmod +x "$script_file"

# Khởi tạo Git
git init

# Thêm file vào Git
git add "$script_file"
git commit -m "Thêm script $script_file"

# Thêm remote repository
while true; do
    read -p "Nhập URL repository GitHub của bạn: " repo_url
    
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
        if git remote add origin "$repo_url"; then
            echo "Đã thêm remote repository thành công."
            break
        else
            echo "Không thể thêm remote repository. Vui lòng thử lại."
        fi
    else
        read -p "Bạn có muốn thử lại không? (y/n): " retry
        [ "$retry" != "y" ] && exit 1
    fi
done

# Push lên repository
git branch -M main
git push -u origin main

# Thông báo hoàn tất
echo "Đã đẩy script $script_file lên GitHub repository."
