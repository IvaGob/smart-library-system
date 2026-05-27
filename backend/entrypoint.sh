#!/bin/sh
set -e

python manage.py migrate --noinput
python manage.py collectstatic --noinput
python manage.py shell -c "
from pathlib import Path
from django.conf import settings
from django.db import connection

sql_path = Path(settings.BASE_DIR) / 'init_db.sql'
with sql_path.open(encoding='utf-8') as sql_file:
    sql = sql_file.read()

with connection.cursor() as cursor:
    cursor.execute(sql)
"

python manage.py shell -c "
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import make_password
from library.models import Profile
from library.models import User as LibraryUser

User = get_user_model()

def ensure_profile(user_id, first_name, last_name, phone):
    profiles = list(Profile.objects.filter(user_id=user_id).order_by('profile_id'))
    if profiles:
        profile = profiles[0]
        profile.first_name = first_name
        profile.last_name = last_name
        profile.phone = phone
        profile.save(update_fields=['first_name', 'last_name', 'phone'])
        duplicate_ids = [duplicate.profile_id for duplicate in profiles[1:]]
        if duplicate_ids:
            Profile.objects.filter(profile_id__in=duplicate_ids).delete()
        return profile
    return Profile.objects.create(
        user_id=user_id,
        first_name=first_name,
        last_name=last_name,
        phone=phone,
    )

username = 'admin'
email = 'admin@example.com'
password = 'admin12345'
if not User.objects.filter(username=username).exists():
    User.objects.create_superuser(username=username, email=email, password=password)

library_user, created = LibraryUser.objects.get_or_create(
    email=email,
    defaults={'password_hash': make_password(password), 'role': 'admin'},
)
if not created:
    library_user.password_hash = make_password(password)
    library_user.role = 'admin'
    library_user.save(update_fields=['password_hash', 'role'])

ensure_profile(library_user.user_id, 'Адміністратор', 'Системи', '+380501110000')

demo_users = [
    ('reader@example.com', 'reader12345', 'reader', 'Марія', 'Коваленко', '+380501112233'),
    ('librarian@example.com', 'librarian12345', 'librarian', 'Олег', 'Бібліотекар', '+380501114455'),
]
for demo_email, demo_password, role, first_name, last_name, phone in demo_users:
    demo_user, demo_created = LibraryUser.objects.get_or_create(
        email=demo_email,
        defaults={'password_hash': make_password(demo_password), 'role': role},
    )
    if not demo_created:
        demo_user.password_hash = make_password(demo_password)
        demo_user.role = role
        demo_user.save(update_fields=['password_hash', 'role'])
    ensure_profile(demo_user.user_id, first_name, last_name, phone)
"

gunicorn smart_library.wsgi:application --bind "0.0.0.0:${PORT:-8000}"
