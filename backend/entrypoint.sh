#!/bin/sh
set -e

python manage.py migrate --noinput
python manage.py collectstatic --noinput

python manage.py shell -c "
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import make_password
from library.models import Profile
from library.models import User as LibraryUser
User = get_user_model()
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

Profile.objects.get_or_create(
    user_id=library_user.user_id,
    defaults={'first_name': 'Адміністратор', 'last_name': 'Системи', 'phone': '+380501110000'},
)

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
    Profile.objects.get_or_create(
        user_id=demo_user.user_id,
        defaults={'first_name': first_name, 'last_name': last_name, 'phone': phone},
    )
"

gunicorn smart_library.wsgi:application --bind "0.0.0.0:${PORT:-8000}"
