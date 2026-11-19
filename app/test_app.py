"""Kiểm tra tích hợp 3 màn hình trên DB thật (cấu hình theo app/.env).

Chạy:  python test_app.py
Tạo 1 đơn test (ngày nhận phòng cách hôm nay ~400 ngày) rồi tự xóa; dữ liệu mẫu không bị đổi.
"""
from datetime import date, timedelta

import pymssql

from app import app, query

client = app.test_client()
passed = 0


def check(name, cond):
    global passed
    assert cond, f'[FAIL] {name}'
    passed += 1
    print(f'[PASS] {name}')


def day(n):
    return (date.today() + timedelta(days=n)).isoformat()


def post(url, **data):
    return client.post(url, data=data, follow_redirects=True).get_data(as_text=True)


def get(url):
    return client.get(url).get_data(as_text=True)


NEW = dict(user_id='2', room='5|Old Quarter Studio', check_in=day(400), check_out=day(402),
           adults='1', children='0', quantity='1')

# ---------- 3.1 Thêm: lỗi THROW của sp_Booking_Insert hiện đúng, ô sai được tô đỏ ----------
html = post('/bookings/new', **dict(NEW, check_in=day(-1)))
check('them: ngay nhan phong da qua -> 51105', '[51105] CHECK_IN_DATE' in html and 'is-invalid' in html)
check('them: loi giu lai du lieu da nhap', f'value="{day(402)}"' in html)
check('them: vuot suc chua -> 51111', '[51111]' in post('/bookings/new', **dict(NEW, adults='5')))
check('them: voucher da dung -> 51124', '[51124]' in post('/bookings/new', **dict(NEW, voucher_code='VC_GUEST2_200K')))
check('them: thieu khach -> 51121', '[51121]' in post('/bookings/new', **dict(NEW, user_id='')))

r = client.post('/bookings/new', data=NEW)
check('them: hop le -> chuyen ve danh sach', r.status_code == 302 and 'keyword=BK' in r.headers['Location'])
code = r.headers['Location'].split('keyword=')[1]
bid = query('SELECT BOOKING_ID FROM dbo.BOOKING WHERE BOOKING_CODE = %s', (code,))[0]['BOOKING_ID']

try:
    # ---------- 3.2 Danh sách: tìm, lọc, sắp xếp, phân trang ----------
    check('danh sach: tim theo ma don moi', code in get(f'/bookings?keyword={code}'))
    html = get('/bookings?keyword=Bình')
    check('danh sach: tim theo ten khach', 'BK20260002' in html and 'BK20260001' not in html)
    html = get('/bookings?status=COMPLETED')
    check('danh sach: loc COMPLETED', 'BK20260001' in html and 'BK20260012' not in html)
    html = get('/bookings?from=2026-09-01&to=2026-09-30')
    check('danh sach: loc khoang ngay', 'BK20260005' in html and 'BK20260011' not in html)
    check('danh sach: khoang ngay nguoc -> canh bao', 'Khoảng ngày bị ngược' in get('/bookings?from=2026-12-01&to=2026-01-01'))
    html = get('/bookings?status=CANCELLED&sort=guest_name')
    check('danh sach: sap xep theo ten khach', html.index('Hoàng Gia Bảo') < html.index('Trần Thị Bình'))
    html = get('/bookings')
    check('danh sach: phan trang 10 dong/trang', html.count('<tr>') == 11 and 'page=2' in html)
    check('danh sach: trang 2', code in get('/bookings?page=2&sort=check_in'))

    # ---------- 3.1 Sửa ----------
    check('sua: mo form', code in get(f'/bookings/{bid}/edit'))
    edit = dict(NEW, room='5|Old Quarter Studio', check_in=day(410), check_out=day(413), status='PENDING')
    post(f'/bookings/{bid}/edit', **edit)
    row = query('SELECT CHECK_IN_DATE, CHECK_OUT_DATE FROM dbo.BOOKING WHERE BOOKING_ID = %s', (bid,))[0]
    check('sua: doi ngay o thanh cong', row['CHECK_IN_DATE'].isoformat() == day(410))
    html = post(f'/bookings/{bid}/edit', **dict(edit, check_out=day(405)))
    check('sua: tra phong truoc nhan phong -> 51106', '[51106]' in html and 'is-invalid' in html)

    # ---------- Đổi trạng thái ngay trên dòng ----------
    nxt = '/bookings?status=PENDING'
    check('trang thai: PENDING -> COMPLETED bi chan (51205)',
          '[51205]' in post(f'/bookings/{bid}/status', status='COMPLETED', next=nxt))
    post(f'/bookings/{bid}/status', status='CONFIRMED', next=nxt)
    check('trang thai: PENDING -> CONFIRMED',
          query('SELECT [STATUS] FROM dbo.BOOKING WHERE BOOKING_ID = %s', (bid,))[0]['STATUS'] == 'CONFIRMED')
    check('sua: don CONFIRMED khong doi ngay duoc (51203)',
          '[51203]' in post(f'/bookings/{bid}/edit', **dict(edit, check_in=day(420), check_out=day(421), status='CONFIRMED')))
    check('xoa: don CONFIRMED bi chan (51302)', '[51302]' in post(f'/bookings/{bid}/delete', next=nxt))
    post(f'/bookings/{bid}/status', status='CANCELLED')
finally:
    # ---------- 3.1 Xóa (cũng là dọn dữ liệu test) ----------
    if query('SELECT 1 AS x FROM dbo.BOOKING WHERE BOOKING_ID = %s AND [STATUS] = %s', (bid, 'CONFIRMED')):
        post(f'/bookings/{bid}/status', status='CANCELLED')
    post(f'/bookings/{bid}/delete')
check('xoa: don CANCELLED chua thanh toan', not query('SELECT 1 AS x FROM dbo.BOOKING WHERE BOOKING_ID = %s', (bid,)))
check('xoa: don da thanh toan bi chan (51302)', '[51302]' in post('/bookings/1/delete'))
check('next ngoai trang bi bo qua', client.post('/bookings/999999/delete', data={'next': '//evil.com'})
      .headers['Location'] == '/bookings')

# ---------- 3.3 Dashboard ----------
html = get('/dashboard')
check('dashboard: bang + bieu do', 'Saigon Majestic Hotel' in html and 'id="chart"' in html)
check('dashboard: loc thanh pho', 'Saigon Majestic Hotel' not in get('/dashboard?city=Hà Nội'))
check('dashboard: HAVING doanh thu toi thieu', 'Saigon Majestic Hotel' not in get('/dashboard?min_revenue=6000000'))
check('dashboard: khong co du lieu', 'Không có doanh thu' in get('/dashboard?from=2030-01-01'))
check('dashboard: hang khach #3 nam 2026', '>SILVER</span>' in get('/dashboard?guest=3&year=2026'))
check('dashboard: nam khong hop le -> NULL', 'Không hợp lệ' in get('/dashboard?guest=3&year=0'))

# ---------- Tài khoản DB của app không ghi trực tiếp được ----------
try:
    query('DELETE FROM dbo.BOOKING WHERE 1 = 0')
    denied = False
except pymssql.Error as e:
    denied = e.args[0] == 229
check('tai khoan app khong co quyen DELETE truc tiep (229)', denied)

print(f'\n{passed}/{passed} PASS')
