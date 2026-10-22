# Bộ Sưu Tập 8 Phương Án Logo Evernear (Logo Options Showcase)

Thư mục này lưu trữ trọn bộ **8 phương án thiết kế logo độc đáo và đa dạng** cho thương hiệu **Evernear** (bảo vệ an toàn gia đình, chăm sóc người cao tuổi, công nghệ bình an - Calm Technology).

Mỗi phương án đều đi kèm đầy đủ 3 kích thước chuẩn:
- `*_full.png`: Master Artwork độ phân giải cao (1024x1024)
- `*_512x512.png`: Icon App tiêu chuẩn cho di động và tài liệu
- `*_192x192.png`: Favicon web và icon thông báo

---

## Danh Sách 8 Phương Án Thiết Kế

| STT | Tên Phương Án | Biểu Tượng Cốt Lõi | Phong Cách & Tone Màu |
| :---: | :--- | :--- | :--- |
| **1** | `option_1_friendly_shield_pulse` | Khiên bảo vệ bo tròn thân thiện + Vô cực $\infty$ + Nhịp tim sinh mệnh | Squircle trắng gốm tinh khiết, xanh ngọc bích y tế & cam san hô |
| **2** | `option_2_ribbon_care_hand` | Dải ruy băng 3D tạo hình chữ 'E' + Trái tim + Bàn tay nâng niu | Xanh dương hoàng gia, xanh ngọc lam & hồng đào dịu mắt |
| **3** | `option_3_shield_warm_heart` | Khiên che chở vững chãi + Vòng lặp kép + Trái tim phát sáng | Xanh ngọc sâu + Trái tim san hô cam rực rỡ, độ tương phản cao |
| **4** | `option_4_shelter_dome_pearl` | Mái vòm bảo bọc Bắc Âu + Chữ 'e' thường + Viên ngọc sinh mệnh | Trắng tuyết Scandinavia, xám bạc tinh tế, ngọc bích bừng sáng |
| **5** | `option_5_infinity_heart_loop` | Đôi dải lụa 3D đất sét mờ đan quyện vô cực tạo hình trái tim | Xanh mòng két (Teal) & lam da trời chuyển sắc mượt mà trên nền trắng |
| **6** | `option_6_care_hands_sprout` | Hai bàn tay chụm lại hình chữ 'E' nâng niu mầm sống non & sóng thở | Xanh lá mạ non (Nature Green), mint tươi mới & hổ phách ấm |
| **7** | `option_7_monogram_e_shield` | Full-bleed gradient sang trọng, chữ 'E' Monogram + Khiên + Nhịp tim | Nền Gradient lục bảo sâu (Deep Teal), biểu tượng trắng sắc nét |
| **8** | `option_8_family_embrace_heart` | Người thân ôm lấy nhau trong vòng hào quang tạo hình trái tim & chữ 'E' | Vàng mơ sum vầy, cam đào dịu ngọt & xanh lam hiền hòa |
| **9** | `option_9_shield_check_pulse_green` *(Đang kích hoạt)* | Khiên bảo vệ + Dấu Check kết hợp sóng nhịp tim sinh mệnh + chữ `Evernear` | Xanh lá Evernear (`#1B5E20`) & Vàng Cam ấm (`#E68C14`) trên nền trắng |
| **10** | `option_10_shield_check_pulse_navy` | Khiên bảo vệ + Dấu Check kết hợp sóng nhịp tim sinh mệnh + chữ `Evernear` | Xanh Navy đậm (`#262052`) & Vàng Cam ấm (`#E4962C`) trên nền trắng |

---

## Cách Kích Hoạt / Chuyển Đổi Logo Bằng 1 Lệnh

Dự án đã tích hợp sẵn công cụ chuyển đổi tự động. Khi anh ưng ý phương án nào, chỉ cần chạy:

```bash
# Ví dụ: Kích hoạt Phương án 5
python3 scripts/switch_logo.py 5

# Hoặc kích hoạt Phương án 2
python3 scripts/switch_logo.py 2
```

Lệnh trên sẽ tự động:
1. Cập nhật `mobile/assets/images/evernear_logo.png`
2. Cập nhật `mobile/web/favicon.png`
3. Tự động cắt & tạo toàn bộ bộ icon Android (`mipmap-mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`).
