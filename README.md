# Quản lý siêu thị

## 🎯 Mục tiêu

Áp dụng kiến thức về **tranh chấp** và **giải quyết tranh chấp** trong môi trường kinh doanh thông qua việc mô phỏng các giao dịch đồng thời trên cơ sở dữ liệu quản lý siêu thị.

## 🚀 Các bước mô phỏng

### Bước 1: Khởi tạo dữ liệu

Chạy lần lượt các file SQL sau để tạo cơ sở dữ liệu và các thủ tục cần thiết:

- `3_BC4_database.sql` — Tạo cấu trúc cơ sở dữ liệu
- `3_BC4_data.sql` — Nạp dữ liệu mẫu vào database

### Bước 2: Mô phỏng tranh chấp

Trong thư mục `TRANHCAPDONGTHOI`, chạy đồng thời hai file sau để mô phỏng hai giao dịch xảy ra tranh chấp:

- `T1.sql` — Giao dịch thứ nhất
- `T2.sql` — Giao dịch thứ hai

### Bước 3: Giải quyết tranh chấp

Các procedure trong file `3_BC4_procedures.sql` là các giải pháp được xây dựng để xử lý tranh chấp.

Để mô phỏng cách giải quyết tranh chấp:

1. Mở procedure bạn muốn kiểm thử trong `3_BC4_procedures.sql`
2. Thêm câu lệnh `WAITFOR DELAY '00:00:05'` vào những vị trí có khả năng xảy ra tranh chấp
3. Chạy đồng thời 2 procedure để quan sát cách hệ thống xử lý và giải quyết tranh chấp

---

💡 **Lưu ý:** Việc thêm `WAITFOR DELAY` giúp kéo dài thời gian thực thi, tạo điều kiện để tranh chấp xảy ra rõ ràng hơn và dễ quan sát cách giải quyết.