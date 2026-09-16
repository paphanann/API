# PASS

Frontend Flutter เรียก Backend ที่ `http://localhost:3000` อย่างเดียว ไม่คุย SQL / Shopee / TikTok โดยตรง และไม่เก็บ Token ไว้หน้าบ้าน

รันคู่กัน:

| ฝั่ง | พอร์ต | หน้าที่ |
| --- | --- | --- |
| Frontend PASS | **5173** | แสดงหน้าเว็บ |
| Backend Express | 3000 | คุย SQL + Marketplace API |

Backend ต้องเปิด CORS ให้ `FRONTEND_URL=http://localhost:5173`

```bash
flutter pub get
flutter run -d chrome --web-port=5173 --dart-define=API_URL=http://localhost:3000
```

หน้า login ส่งอีเมล/รหัสผ่านไป Backend ให้ตรวจจากฐานข้อมูล

- `POST /api/auth/login` body `{ "email", "username", "password" }`
- ถ้า 404 จะลอง `POST /api/login`
- หน้าบ้านไม่คุย SQL ตรง และไม่เก็บ Partner Key / Access Token ของ marketplace

หลัง Authorize สำเร็จ Backend ควรเด้งกลับ `http://localhost:5173/connections?status=success`
