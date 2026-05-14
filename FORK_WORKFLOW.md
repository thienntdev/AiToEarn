# Quy trình đồng bộ Upstream & Phát triển Custom

Tài liệu này hướng dẫn cách duy trì cập nhật code từ repo gốc (`yikart/AiToEarn`) đồng thời phát triển các tính năng riêng trên bản fork (`thienntdev/AiToEarn`).

---

## Tổng quan kiến trúc nhánh

```
upstream/main (yikart/AiToEarn)
    │
    │  git fetch upstream
    │  git merge upstream/main
    ▼
origin/main (thienntdev/AiToEarn)  ← Luôn giữ đồng bộ 1:1 với upstream
    │
    │  git merge main
    ▼
custom-dev  ← Nhánh phát triển tính năng riêng
    │
    ├── feature/thanh-toan-vn
    ├── feature/giao-dien-rieng
    └── ...
```

**Nguyên tắc vàng:** KHÔNG BAO GIỜ commit code riêng trực tiếp lên nhánh `main`. Nhánh `main` chỉ dùng để đồng bộ với upstream.

---

## Thiết lập ban đầu (Chỉ làm 1 lần)

### 1. Thêm upstream remote

```bash
git remote add upstream https://github.com/yikart/AiToEarn.git
```

### 2. Kiểm tra đã thiết lập đúng

```bash
git remote -v
```

Kết quả mong đợi:

```
origin    https://github.com/thienntdev/AiToEarn.git (fetch)
origin    https://github.com/thienntdev/AiToEarn.git (push)
upstream  https://github.com/yikart/AiToEarn.git (fetch)
upstream  https://github.com/yikart/AiToEarn.git (push)
```

### 3. Tạo nhánh phát triển riêng

```bash
git checkout main
git checkout -b custom-dev
git push -u origin custom-dev
```

---

## Quy trình đồng bộ hàng ngày / hàng tuần

Mỗi khi muốn lấy code mới nhất từ source gốc, thực hiện các bước sau:

### Bước 1: Tải code mới từ upstream

```bash
git fetch upstream
```

### Bước 2: Kiểm tra có bao nhiêu commit mới

```bash
git rev-list --count main..upstream/main
```

Nếu kết quả là `0` → Không có gì mới, dừng ở đây.

### Bước 3: Cập nhật nhánh `main`

```bash
git checkout main
git merge upstream/main
git push origin main
```

### Bước 4: Gộp bản cập nhật vào nhánh custom

```bash
git checkout custom-dev
git merge main
```

### Bước 5: Xử lý xung đột (nếu có)

Nếu Git báo **CONFLICT**, mở VS Code / IDE và tìm các file bị đánh dấu xung đột:

```bash
# Xem danh sách file bị xung đột
git diff --name-only --diff-filter=U
```

Trong mỗi file xung đột, bạn sẽ thấy:

```
<<<<<<< HEAD
// Code của bạn (custom-dev)
=======
// Code mới từ upstream
>>>>>>> main
```

**Cách xử lý:**
- Giữ code của bạn → xóa phần upstream
- Giữ code upstream → xóa phần của bạn
- Kết hợp cả hai → chỉnh sửa thủ công cho phù hợp

Sau khi sửa xong tất cả xung đột:

```bash
git add .
git commit -m "merge: đồng bộ upstream và giải quyết xung đột"
git push origin custom-dev
```

---

## Quy trình phát triển tính năng mới

Khi bạn muốn phát triển một tính năng riêng, hãy tạo nhánh con từ `custom-dev`:

```bash
git checkout custom-dev
git checkout -b feature/ten-tinh-nang

# ... code xong ...

git add .
git commit -m "feat: mô tả tính năng"
git push origin feature/ten-tinh-nang
```

Sau đó merge về `custom-dev` khi hoàn thành:

```bash
git checkout custom-dev
git merge feature/ten-tinh-nang
git push origin custom-dev

# Xóa nhánh feature đã hoàn thành (tùy chọn)
git branch -d feature/ten-tinh-nang
```

---

## Triển khai (Deploy)

Luôn deploy từ nhánh `custom-dev` (hoặc tạo nhánh `production` từ `custom-dev`):

```bash
# Deploy trực tiếp từ custom-dev
git checkout custom-dev
docker compose up -d --build

# Hoặc tạo nhánh production riêng
git checkout custom-dev
git checkout -b production
git push origin production
```

**KHÔNG deploy từ nhánh `main`** vì nhánh đó là bản gốc của upstream, chưa có các tính năng custom của bạn.

---

## Lệnh tắt: Script đồng bộ nhanh

Tạo file `scripts/sync-upstream.sh` và chạy mỗi khi muốn đồng bộ:

```bash
#!/bin/bash
set -e

echo "🔄 Đang tải code mới từ upstream..."
git fetch upstream

NEW_COMMITS=$(git rev-list --count main..upstream/main)
echo "📦 Có $NEW_COMMITS commit mới từ upstream"

if [ "$NEW_COMMITS" -eq "0" ]; then
    echo "✅ Đã cập nhật mới nhất. Không cần làm gì thêm."
    exit 0
fi

echo "📥 Cập nhật nhánh main..."
git checkout main
git merge upstream/main
git push origin main

echo "🔀 Gộp vào nhánh custom-dev..."
git checkout custom-dev
git merge main

echo ""
echo "✅ Đồng bộ hoàn tất!"
echo "⚠️  Nếu có xung đột, hãy giải quyết rồi commit."
```

Cấp quyền chạy:

```bash
chmod +x scripts/sync-upstream.sh
```

Sử dụng:

```bash
bash scripts/sync-upstream.sh
```

---

## Mẹo và lưu ý

### ✅ Nên làm
- Đồng bộ thường xuyên (ít nhất 1 lần/tuần) để tránh xung đột lớn
- Commit nhỏ, rõ ràng — dễ xử lý xung đột hơn
- Viết commit message có tiền tố rõ ràng: `feat:`, `fix:`, `custom:` để phân biệt code riêng
- Đọc changelog / release notes của upstream trước khi merge

### ❌ Không nên làm
- Commit code riêng lên nhánh `main`
- Để quá lâu mới đồng bộ (càng nhiều commit lệch → xung đột càng phức tạp)
- Force push (`git push --force`) lên nhánh `main`

### 💡 Mẹo giảm xung đột
- Tránh sửa trực tiếp các file core của upstream (nếu cần, hãy tạo file mới kế thừa/mở rộng)
- Đặt config riêng vào các file `local.config.js` (đã có trong `.gitignore`)
- Tạo thư mục riêng cho code custom (ví dụ: `custom/`) để tách biệt khỏi code upstream

---

## Tóm tắt các nhánh

| Nhánh | Mục đích | Ai quản lý |
|-------|----------|------------|
| `upstream/main` | Source gốc của AiToEarn | Tác giả gốc (yikart) |
| `main` | Bản sao đồng bộ 1:1 với upstream | Bạn (chỉ merge, không commit) |
| `custom-dev` | Nhánh phát triển tính năng riêng | Bạn |
| `feature/*` | Nhánh tính năng cụ thể | Bạn |
| `production` | Nhánh triển khai sản phẩm (tùy chọn) | Bạn |
