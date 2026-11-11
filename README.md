# ChupManHinh Easy — Signed Releases

Repository này chỉ chứa **binary release**, `update-manifest.json`, chữ ký Ed25519 và checksum cho Chụp Màn Hình Easy.

- Source code chính được giữ private ở repository phát triển.
- Ứng dụng chỉ chấp nhận bản cập nhật có manifest ký bằng khóa Ed25519 của nhà phát hành.
- Public-key fingerprint SHA-256: `442bf0874008ec6bb455731121b1ab58418f354dc6ad131b872c8889ded680dd`.
- Không lưu khóa ký riêng, token hoặc source code trong repository này.

## Tải Chụp Màn Hình Easy — macOS Stable

**macOS 13+; Apple Silicon (M1/M2/M3/M4 và mới hơn).** Bản DMG này không hỗ trợ máy Mac Intel.

- **Trang tải Stable mới nhất (link không đổi):** https://github.com/swehunglucas-lgtm/ChupManHinh-Easy-Releases/releases/latest
- **Tải trực tiếp DMG Stable mới nhất (link không đổi):** https://github.com/swehunglucas-lgtm/ChupManHinh-Easy-Releases/releases/latest/download/ChupManHinh-Easy-macOS-AppleSilicon.dmg
- [Danh sách bản phát hành](https://github.com/swehunglucas-lgtm/ChupManHinh-Easy-Releases/releases)

Tải DMG và kéo ứng dụng vào **Applications**. Ứng dụng **chưa ký Apple Developer ID và chưa notarize** nên macOS có thể hiện cảnh báo Gatekeeper. Sau khi thử mở, người dùng có thể vào **Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Vẫn mở (Open Anyway)** nếu tùy chọn đó xuất hiện. Không cần tắt bảo mật toàn hệ thống.

**Lưu ý:** V2.4.0 hiện mới phát hành Stable cho macOS Apple Silicon. Các bản Windows và Linux nằm ở các release cũ, chưa có V2.4.0.

**Quy ước các bản Stable sau:** luôn đính kèm tài sản tên cố định `ChupManHinh-Easy-macOS-AppleSilicon.dmg`, cùng manifest Ed25519 và SHA-256, để 2 đường dẫn trên tiếp tục hoạt động.
