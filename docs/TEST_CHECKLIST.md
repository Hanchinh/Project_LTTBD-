# Bảng Kiểm Thử Thủ Công Trên Thiết Bị Thật (Manual Test Checklist)

> **Tài liệu danh mục kiểm thử thực tế trên điện thoại Android vật lý trước khi giao ứng dụng Ghim Điểm Giao Hàng (v1.0.0+1) cho shipper.**
> Phân định nghiêm ngặt: Những phần đã có automated test kiểm chứng được ghi nhận `[ĐÃ TEST]`, những phần cần kiểm tra phần cứng vật lý được gắn nhãn `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]`.

---

## 1. Danh Mục Kịch Bản Kiểm Thử Thực Địa

| STT | Kịch bản kiểm thử | Mô tả chi tiết các bước | Tiêu chí nghiệm thu (Pass Criteria) | Trạng thái hiện tại |
| :---: | :--- | :--- | :--- | :---: |
| **01** | **Khởi động lần đầu (Onboarding)** | 1. Cài đặt file APK phát hành mới tinh.<br>2. Mở ứng dụng lần đầu tiên. | Hiện màn chào "Chào mừng", cho phép nhập tên hiển thị hoặc bấm Bỏ qua, vào thẳng giao diện bản đồ không đòi đăng nhập server. | `[ĐÃ TEST]` (Widget Test) / `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]` |
| **02** | **Cấp quyền GPS & Định vị Shipper** | 1. Ứng dụng yêu cầu quyền vị trí.<br>2. Bấm "Cho phép khi dùng ứng dụng".<br>3. Bật GPS trên máy, bấm nút định vị. | Tâm bản đồ di chuyển đến vị trí thực tế của shipper; marker xanh dương hiện chính xác theo GPS vệ tinh. | `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]` |
| **03** | **Ghim vị trí nhà khách hàng (Tâm ngắm)** | 1. Đứng trước cổng nhà khách, bấm nút (+) Ghim vị trí.<br>2. Kéo tâm ngắm đỏ vào đúng vị trí cổng.<br>3. Bấm xác nhận, nhập tên, SĐT, ghi chú cổng. | Lưu thành công vào SQLite; marker xanh lá xuất hiện trên bản đồ; chạm vào marker mở card chi tiết ngay lập tức. | `[ĐÃ TEST]` (Automated Test) / `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]` |
| **04** | **Chụp ảnh cổng nhà bằng Camera thật** | 1. Trong form chi tiết khách, bấm "Chụp ảnh".<br>2. Chụp cổng nhà khách hàng thật.<br>3. Xác nhận ảnh. | Camera hệ thống mở trơn tru; ảnh được nén về max 1600px, thumbnail 300px lưu vào thư mục riêng của app; hiển thị sắc nét trong danh bạ và chi tiết điểm. | `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]` |
| **05** | **Bản đồ khi mất kết nối mạng (Offline)** | 1. Tắt Wi-Fi và tắt dữ liệu di động (4G/5G).<br>2. Mở app, di chuyển trên bản đồ.<br>3. Tìm kiếm khách hàng đã lưu trong danh bạ.<br>4. Tìm kiếm địa chỉ mới trên thanh tìm kiếm. | Banner cảnh báo mất mạng hiện rõ; toàn bộ điểm ghim đã lưu vẫn hiện đầy đủ trên nền bản đồ đã cache; tìm khách trong danh bạ chạy mượt; tìm địa chỉ mới báo "Cần kết nối mạng để tìm kiếm địa chỉ". | `[ĐÃ TEST]` (Automated Test) / `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]` |
| **06** | **Tạo và quản lý ca làm việc (Shift)** | 1. Chuyển sang tab "Ca làm việc", bấm tạo ca.<br>2. Thêm nhanh 10-20 số điện thoại từ clipboard hoặc chọn từ danh bạ.<br>3. Mở bản đồ ca. | Các điểm giao tự động gom nhóm; điểm đã có vị trí hiển thị xanh, điểm chưa có hiển thị vàng cam; cho phép ghim nhanh vị trí tạm. | `[ĐÃ TEST]` (Automated Test) / `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]` |
| **07** | **Chia sẻ điểm bằng File (.dshare)** | 1. Trong tab Cá nhân/Danh bạ, chọn 5 điểm khách hàng, xuất file .dshare (kèm ảnh).<br>2. Gửi file qua ứng dụng Zalo / Google Drive sang máy shipper B.<br>3. Trên máy B, bấm trực tiếp vào file .dshare. | Ứng dụng tự động bật lên qua Intent Filter; màn hình xem trước hiện đủ 5 điểm và ảnh; bấm "Nhập điểm" thành công, không trùng lặp số điện thoại. | `[ĐÃ TEST]` (Unit & Integration Test) / `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]` |
| **08** | **Chia sẻ điểm bằng Mã QR (Nhiều mã)** | 1. Chọn 30 điểm giao, chọn Chia sẻ qua QR.<br>2. Ứng dụng tự động tăng độ sáng màn hình, phân mảnh mã "1/3, 2/3, 3/3".<br>3. Trên máy B, mở máy quét QR camera. | Máy ảnh quét liên tục từng mã mảnh; thanh tiến trình nhảy 33% -> 66% -> 100%; tự động giải nén và nhập đủ 30 điểm. | `[ĐÃ TEST]` (Unit Test) / `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]` |
| **09** | **Khóa ứng dụng bằng mã PIN & Sinh trắc học** | 1. Vào tab Cá nhân, đặt mã PIN 6 số.<br>2. Khóa máy hoặc ấn Home ra màn hình chính, chờ 1 phút.<br>3. Mở lại ứng dụng. | Màn hình khóa số hiện ra; nếu nhập sai 5 lần bị khóa 30 giây; nhập đúng vào lại app bình thường; hỗ trợ mở khóa vân tay nếu thiết bị có cảm biến. | `[ĐÃ TEST]` (Widget Test) / `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]` |
| **10** | **Sao lưu & Khôi phục ZIP toàn diện** | 1. Bấm "Tạo bản sao lưu ngay", tạo file .zip.<br>2. Xóa thử một số khách hàng hoặc xóa trắng app.<br>3. Bấm "Khôi phục dữ liệu", chọn tệp .zip vừa tạo. | Dữ liệu khách hàng, vị trí đã lưu, lịch sử và toàn bộ tệp ảnh nhà được phục hồi 100% nguyên vẹn. | `[ĐÃ TEST]` (Full Test) / `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]` |
| **11** | **Dọn bộ nhớ đệm (Cache) & Thống kê lưu trữ** | 1. Xem dung lượng CSDL, Ảnh, Bộ nhớ đệm trong tab Cá nhân.<br>2. Bấm "Dọn bộ nhớ đệm". | Hộp thoại xác nhận hiện ra; dọn sạch các tile tạm và file chia sẻ tạm; dung lượng bộ nhớ đệm giảm về 0 B; dữ liệu khách hàng và ảnh không bị ảnh hưởng. | `[ĐÃ TEST]` (Automated Test) / `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]` |
| **12** | **Độ bền dữ liệu khi tắt app / tắt nguồn đột ngột** | 1. Đang lưu vị trí hoặc đang thao tác trong ca.<br>2. Vuốt tắt ứng dụng đột ngột từ Recent Apps hoặc khởi động lại điện thoại.<br>3. Mở lại ứng dụng. | Cơ sở dữ liệu SQLite (WAL mode) không bị hỏng (corrupt); dữ liệu vừa commit còn nguyên vẹn; ứng dụng mở lên trơn tru không văng crash. | `[ĐÃ TEST]` (Automated Test) / `[CHƯA THỬ TRÊN ĐIỆN THOẠI THẬT]` |

---

## 2. Hướng Dẫn Kỹ Thuật Khi Test Trên Thực Địa

1. **Chuẩn bị 2 điện thoại Android thật:**
   - Máy A: Đã có sẵn dữ liệu 20-50 điểm ghim thực tế kèm ảnh chụp.
   - Máy B: Cài đặt mới toanh (fresh install) để thử nghiệm import chia sẻ qua QR và file `.dshare`.
2. **Khu vực thử nghiệm:**
   - Tuyến đường có nhiều hẻm sâu, số nhà nhảy cóc (địa bàn thực tế của shipper).
   - Thử nghiệm tắt 4G khi đi vào khu vực sóng yếu hoặc tầng hầm.
3. **Ghi nhận lỗi:**
   - Nếu phát hiện bất kỳ lỗi giật lag, sai lệch tọa độ hoặc lỗi camera, ghi nhận lại model điện thoại, phiên bản Android và gửi báo cáo về đội ngũ kỹ thuật.

