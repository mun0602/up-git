#!/bin/bash

# Hàm kiểm tra kết nối GitHub
check_github_connection() {
    echo "Kiểm tra kết nối GitHub..."
    if git ls-remote "$1" &> /dev/null; then
        echo "Kết nối GitHub thành công."
    else
        echo "Không thể kết nối đến repository GitHub. Vui lòng kiểm tra URL."
        exit 1
    fi
}

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
    check_github_connection "$repo_url"
    git remote add origin "$repo_url" && break
done

# Push lên repository
git branch -M main
git push -u origin main

# Thông báo hoàn tất
echo "Đã đẩy script $script_file lên GitHub repository."
