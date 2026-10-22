# TASK-002: Loại Bỏ Lỗ Hổng Bypass Mật Khẩu Tĩnh & Chuẩn Hóa Bcrypt Hash

> **Tài liệu giao việc kỹ thuật từ Project Architect & Technical Lead gửi IDE Agent (Software Engineer).**
> **Trạng thái:** SẴN SÀNG ĐỂ THỰC THI (PENDING APPROVAL)
> **Mức độ ưu tiên:** CRITICAL (Bảo mật cốt lõi)
> **Phân hệ tác động:** `backend/`, `init-db/`, `docs/`

---

## 1. Mục Tiêu (Objective)

1. **Khắc phục triệt để lỗ hổng xác thực:** Loại bỏ cơ chế fallback gán `isMatch = true` khi mật khẩu đầu vào là chuỗi tĩnh `password123` trong [auth.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/auth.controller.ts).
2. **Bảo toàn khả năng đăng nhập của tài khoản mẫu:** Thay thế chuỗi băm giả lập trong [01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql) bằng chuỗi băm Bcrypt thật và hợp lệ (salt rounds = 10) tương ứng với mật khẩu kiểm thử mặc định, giúp các tài khoản seed vẫn đăng nhập thành công qua cơ chế so khớp Bcrypt chuẩn mực.
3. **Chống hồi quy (Regression Prevention):** Bổ sung bộ kiểm thử tự động (Unit / Regression Tests) bao phủ các trường hợp: mật khẩu đúng, mật khẩu sai, và trường hợp nhập mật khẩu tĩnh với tài khoản có mật khẩu khác.

---

## 2. Hiện Trạng Đã Xác Minh (Verified Current State)

### 2.1. Lỗ hổng trong mã nguồn Backend
Tại [backend/src/controllers/auth.controller.ts:L32-L36](file:///d:/flutter create delivery_marker_app/backend/src/controllers/auth.controller.ts#L32-L36):
```typescript
// Passwords match check (supports plaintext 'password123' fallback for quick dev test or bcrypt)
let isMatch = await bcrypt.compare(password, user.password_hash);
if (!isMatch && password === 'password123') {
  isMatch = true;
}
```
- **Hậu quả:** Bất kỳ ai biết số điện thoại của tài khoản (kể cả tài khoản Admin) đều có thể đăng nhập thành công bằng cách nhập mật khẩu `password123`, ngay cả khi tài khoản đó đã đổi mật khẩu khác hoặc hash trong CSDL không khớp.

### 2.2. Nguyên nhân sâu xa trong CSDL Seed Data
Tại [init-db/01-init-db.sql:L189-L202](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql#L189-L202):
- Chuỗi băm được gán cho 3 tài khoản mẫu là:
  `$2b$10$6C0pZbJ5yDk6/x2zX4kL6.H9T5q5D5f8S2z6A5B4C3D2E1F0G1H2I`
- **Kết quả kiểm tra thực tế:**
  Hàm `bcrypt.compareSync('password123', '$2b$10$6C0pZbJ5yDk6/x2zX4kL6.H9T5q5D5f8S2z6A5B4C3D2E1F0G1H2I')` trả về **`false`**.
- **Kết luận:** Đây là chuỗi hash giả lập (placeholder/dummy string) được tạo thủ công (phần đuôi chứa chuỗi giả `A5B4C3D2E1F0G1H2I`). Khi lập trình viên trước đây nhận thấy `bcrypt.compare` luôn trả về `false`, thay vì tạo lại hash Bcrypt chuẩn, họ đã chắp vá bằng đoạn mã fallback `if (password === 'password123')`.

---

## 3. Phạm Vi Thực Hiện (Scope of Work)

### 3.1. Trong phạm vi (In-Scope)
1. **Chỉnh sửa Backend Controller:**
   - Cập nhật [backend/src/controllers/auth.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/auth.controller.ts):
     - Xóa hoàn toàn đoạn mã fallback `if (!isMatch && password === 'password123')`.
     - Giữ nguyên luồng kiểm tra duy nhất: `const isMatch = await bcrypt.compare(password, user.password_hash);`.
2. **Cập nhật Seed Data trong CSDL:**
   - Cập nhật [init-db/01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql):
     - Sinh một chuỗi băm Bcrypt hợp lệ (độ phức tạp salt rounds = 10) từ mật khẩu kiểm thử mặc định `password123`.
     - Thay thế giá trị hash cũ bằng hash hợp lệ mới cho cả 3 tài khoản mẫu (`Nguyễn Văn Quản Lý`, `Trần Văn Giao`, `Lê Thị Tốc Độ`).
3. **Bổ sung Bộ Kiểm Thử (Unit / Regression Tests):**
   - Tạo tệp kiểm thử mới [backend/test/auth.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/auth.spec.ts) bao phủ các kịch bản so khớp mật khẩu và chống hồi quy.
4. **Cập nhật Tài Liệu Kỹ Thuật:**
   - Cập nhật [docs/CURRENT_STATE.md](file:///d:/flutter create delivery_marker_app/docs/CURRENT_STATE.md): Ghi nhận đã giải quyết lỗ hổng bảo mật mức độ cao.
   - Cập nhật [docs/DECISIONS.md](file:///d:/flutter create delivery_marker_app/docs/DECISIONS.md): Chuyển `PENDING-002` thành `ACCEPTED`.
   - Cập nhật [docs/TESTING.md](file:///d:/flutter create delivery_marker_app/docs/TESTING.md): Bổ sung kết quả chạy test mới.

### 3.2. Ngoài phạm vi (Out-of-Scope)
- **Không** thay đổi cấu trúc schema của bảng `users` (không thêm/sửa/xóa cột).
- **Không** sửa đổi bất kỳ logic nghiệp vụ nào trong [admin.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/admin.controller.ts), [locations.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/locations.controller.ts), hay [orders.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/orders.controller.ts).
- **Không** can thiệp vào mã nguồn của `admin_web` hay `mobile_app`.
- **Không** thay đổi thuật toán mã hóa (tiếp tục sử dụng Bcrypt salt 10 chuẩn).

---

## 4. Tiêu Chí Nghiệm Thu (Acceptance Criteria)

| Mã AC | Tiêu Chí Nghiệm Thu | Phương Pháp Xác Minh |
| :--- | :--- | :--- |
| **AC-1** | Không còn bất kỳ đoạn mã nào so sánh chuỗi tĩnh `password === 'password123'` trong toàn bộ thư mục `backend/`. | Chạy tìm kiếm chuỗi: `rg "password123" backend/src` -> Kết quả: 0 match. |
| **AC-2** | Việc so khớp mật khẩu hoàn toàn phụ thuộc vào kết quả của `await bcrypt.compare(password, user.password_hash)`. | Kiểm tra mã nguồn [auth.controller.ts](file:///d:/flutter create delivery_marker_app/backend/src/controllers/auth.controller.ts). |
| **AC-3** | Khi người dùng nhập sai mật khẩu, API trả về HTTP `401 Unauthorized` kèm thông điệp: `"Số điện thoại hoặc mật khẩu không chính xác"`. | Unit test / API test. |
| **AC-4** | Khi người dùng nhập `password123` vào một tài khoản có mật khẩu thực tế khác, hệ thống **bắt buộc** từ chối truy cập (401), không có bất kỳ ngoại lệ nào. | Unit test chống hồi quy trong [auth.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/auth.spec.ts). |
| **AC-5** | Dữ liệu seed trong [01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql) chứa chuỗi hash Bcrypt thật, đảm bảo `bcrypt.compareSync('password123', seedHash)` trả về `true`. | Chạy lệnh kiểm tra bằng Node.js script. |
| **AC-6** | Toàn bộ các bộ kiểm thử đơn vị trong `backend` (`auth.spec.ts` và `location.spec.ts`) đều vượt qua 100%. | Lệnh `npm test` trong `backend` thoát với exit code 0. |
| **AC-7** | Mã nguồn TypeScript của backend biên dịch sạch sẽ, không có cảnh báo kiểu dữ liệu. | Lệnh `npx tsc --noEmit` trong `backend` thoát với exit code 0. |

---

## 5. Yêu Cầu Kiểm Thử & Kịch Bản Chi Tiết (Testing Requirements)

Tạo tệp [backend/test/auth.spec.ts](file:///d:/flutter create delivery_marker_app/backend/test/auth.spec.ts) cài đặt tối thiểu 4 ca kiểm thử sau:

```typescript
describe('Authentication & Password Verification Security Tests', () => {
  // Test Case 1: Mật khẩu hợp lệ khớp với hash Bcrypt
  it('should successfully verify when password matches valid bcrypt hash', async () => {
    // Tạo hash thật từ bcrypt với salt 10
    // Kỳ vọng: bcrypt.compare trả về true
  });

  // Test Case 2: Mật khẩu sai bị từ chối
  it('should reject verification when password does not match bcrypt hash', async () => {
    // Thử mật khẩu sai với hash thật
    // Kỳ vọng: bcrypt.compare trả về false
  });

  // Test Case 3: Chống hồi quy - Không cho phép dùng password123 để bypass tài khoản có mật khẩu khác
  it('should strictly reject "password123" when user has a different password hash', async () => {
    // Tạo hash cho một mật khẩu riêng biệt (VD: "my_custom_secure_password")
    // Thử so sánh với "password123"
    // Kỳ vọng: bcrypt.compare trả về false (Không có logic bypass)
  });

  // Test Case 4: Xác minh tính hợp lệ của hash mẫu trong seed script
  it('should verify that seed data hash correctly resolves default test password', () => {
    // Đọc hash từ seed data và so sánh với mật khẩu mẫu mặc định
    // Kỳ vọng: bcrypt.compareSync trả về true
  });
});
```

---

## 6. Định Dạng Báo Cáo Bàn Giao Của IDE Agent (Handover Format)

Sau khi hoàn tất cài đặt và kiểm thử, IDE Agent **phải** lập báo cáo bàn giao theo cấu trúc sau:

```markdown
# BÁO CÁO KẾT QUẢ THỰC HIỆN TASK-002

## 1. Tóm tắt các thay đổi đã thực hiện
- [auth.controller.ts]: Đã xóa đoạn mã bypass...
- [01-init-db.sql]: Đã cập nhật hash Bcrypt chuẩn cho các tài khoản seed...
- [auth.spec.ts]: Đã tạo mới bộ kiểm thử bảo mật...
- [Tài liệu docs/]: Đã cập nhật CURRENT_STATE, DECISIONS, TESTING...

## 2. Bằng chứng kiểm tra hash CSDL Seed
- Lệnh chạy kiểm tra hash trong 01-init-db.sql với bcrypt.compareSync:
  `...` -> Kết quả: `Matches: true`

## 3. Kết quả chạy kiểm thử thực tế (Exact Commands & Output)
- Kết quả chạy `npm test`:
  (Dán nguyên văn log chạy test của Jest)
- Kết quả chạy `npx tsc --noEmit`:
  (Dán nguyên văn kết quả)

## 4. Bảng đối chiếu tiêu chí nghiệm thu (AC Checklist)
- [x] AC-1: Đạt
- [x] AC-2: Đạt
- [x] AC-3: Đạt
- [x] AC-4: Đạt
- [x] AC-5: Đạt
- [x] AC-6: Đạt
- [x] AC-7: Đạt

## 5. Xác nhận bảo mật
- Không in lộ mật khẩu hoặc secret key trong báo cáo hay mã nguồn.
```

---

## 7. Hướng Dẫn CSDL Cho Môi Trường Đang Chạy (Database Migration Note)

> [!IMPORTANT]
> Đối với các container CSDL Postgres đã khởi tạo từ trước (đang giữ volume `postgres_data`), việc sửa tệp [01-init-db.sql](file:///d:/flutter create delivery_marker_app/init-db/01-init-db.sql) sẽ không tự động cập nhật dữ liệu của container cũ.
>
> **Quy định cập nhật CSDL hiện có:**
> - Tuyệt đối **không** xóa hoặc dựng lại volume, không reset database hay chạy các lệnh phá hủy dữ liệu (như `docker-compose down -v` hoặc xóa volume).
> - Database hiện có chỉ được cập nhật qua phương án migration hoặc câu lệnh SQL có kiểm soát, sau khi xác minh môi trường và dữ liệu.
> - Ví dụ câu lệnh SQL cập nhật có kiểm soát cho các tài khoản seed sau khi đã xác minh môi trường:
>   ```sql
>   UPDATE users SET password_hash = '<HASH_MOI>' WHERE phone_number IN ('0900000001', '0901111111', '0902222222');
>   ```
