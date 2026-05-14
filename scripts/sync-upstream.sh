#!/bin/bash
set -e

# ============================================================
# sync-upstream.sh
# Chạy từ BẤT KỲ nhánh nào, script sẽ tự động:
#   1. Lưu nhánh hiện tại & stash code đang dở (nếu có)
#   2. Checkout sang main → đồng bộ upstream
#   3. Checkout sang custom-dev → merge main vào
#   4. Quay lại nhánh ban đầu & khôi phục code đang dở
#
# Cách dùng:  bash scripts/sync-upstream.sh
# ============================================================

CUSTOM_BRANCH="custom-dev"

# --- Lưu trạng thái hiện tại ---
CURRENT_BRANCH=$(git branch --show-current)
echo "📍 Nhánh hiện tại: $CURRENT_BRANCH"

# Stash code đang dở (nếu có thay đổi chưa commit)
STASHED=false
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "💾 Phát hiện code chưa commit — tạm lưu (stash) lại..."
    git stash push -m "sync-upstream: auto stash trước khi đồng bộ"
    STASHED=true
fi

# --- Hàm quay lại nhánh ban đầu ---
cleanup() {
    echo ""
    echo "🔙 Quay lại nhánh $CURRENT_BRANCH..."
    git checkout "$CURRENT_BRANCH"

    if [ "$STASHED" = true ]; then
        echo "📂 Khôi phục code đang dở từ stash..."
        git stash pop
    fi
}

# Nếu script bị lỗi giữa chừng → vẫn quay lại nhánh ban đầu
trap cleanup EXIT

# --- Bước 1: Fetch upstream ---
echo ""
echo "🔄 Đang tải code mới từ upstream..."
git fetch upstream

NEW_COMMITS=$(git rev-list --count main..upstream/main)
echo "📦 Có $NEW_COMMITS commit mới từ upstream"

if [ "$NEW_COMMITS" -eq "0" ]; then
    echo "✅ Đã cập nhật mới nhất. Không cần làm gì thêm."
    # cleanup sẽ tự chạy qua trap EXIT
    exit 0
fi

# --- Bước 2: Cập nhật nhánh main ---
echo ""
echo "📥 Cập nhật nhánh main..."
git checkout main
git merge upstream/main
git push origin main
echo "✅ Nhánh main đã đồng bộ với upstream."

# --- Bước 3: Merge vào custom-dev (nếu có) ---
if git show-ref --verify --quiet "refs/heads/$CUSTOM_BRANCH"; then
    echo ""
    echo "🔀 Gộp vào nhánh $CUSTOM_BRANCH..."
    git checkout "$CUSTOM_BRANCH"
    if git merge main; then
        git push origin "$CUSTOM_BRANCH"
        echo "✅ Đồng bộ hoàn tất! Không có xung đột."
    else
        echo ""
        echo "⚠️  Có xung đột khi merge vào $CUSTOM_BRANCH!"
        echo "📋 Danh sách file bị xung đột:"
        git diff --name-only --diff-filter=U
        echo ""
        echo "👉 Giải quyết xung đột trong IDE, sau đó chạy:"
        echo "   git add ."
        echo "   git commit -m \"merge: đồng bộ upstream\""
        echo "   git push origin $CUSTOM_BRANCH"
        # Không exit 1 ở đây để cleanup vẫn chạy đúng nhánh
        trap - EXIT  # Tắt auto-cleanup vì đang ở giữa merge conflict
        exit 1
    fi
else
    echo ""
    echo "ℹ️  Nhánh $CUSTOM_BRANCH chưa tồn tại."
    echo "👉 Tạo bằng lệnh: git checkout -b $CUSTOM_BRANCH"
fi

echo ""
echo "🎉 Hoàn tất!"
# cleanup tự chạy qua trap EXIT → quay lại nhánh ban đầu
