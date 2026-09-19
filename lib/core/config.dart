/// URL ของ Backend Express เท่านั้น — หน้าบ้านไม่คุย SQL / marketplace โดยตรง
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');
