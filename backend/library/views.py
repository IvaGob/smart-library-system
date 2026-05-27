from datetime import timedelta

from django.contrib.auth.hashers import check_password, make_password
from django.db import IntegrityError, connection, transaction
from django.db.models import F, Q
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import AccessToken, RefreshToken

from recommendations.recommender import SmartLibraryRecommender

from .models import Author, Book, Genre, Interaction, Loan, ModelStats, Profile, Rating, Reservation, User
from .serializers import (
    BookCreateSerializer,
    BookSerializer,
    GenreSerializer,
    InteractionSerializer,
    LoanSerializer,
    ModelStatsSerializer,
    RatingSerializer,
    ReservationSerializer,
    UserSerializer,
)


def api_log(method, path, sql):
    """Формує навчальний журнал для фронтенд-консолі."""
    return {"method": method, "path": path, "sql": sql, "timestamp": timezone.now().isoformat()}


def require_library_user(request):
    """Повертає поточного користувача або None для захищених дій."""
    return getattr(request, "library_user", None)


def build_tokens(user):
    """Створює JWT access та refresh токени для власної таблиці users."""
    access = AccessToken()
    refresh = RefreshToken()
    for token in (access, refresh):
        token["user_id"] = user.user_id
        token["email"] = user.email
        token["role"] = user.role
    return {"access": str(access), "refresh": str(refresh)}


def is_librarian(user):
    return user and user.role in ("librarian", "admin")


def complete_loan_return(loan, actor_user_id):
    loan.return_date = timezone.localdate()
    loan.status = "returned"
    loan.save(update_fields=["return_date", "status"])
    book = Book.objects.select_for_update().get(book_id=loan.book_id)
    if book.available_copies < book.total_copies:
        Book.objects.filter(book_id=loan.book_id).update(available_copies=F("available_copies") + 1)
    Interaction.objects.create(user_id=actor_user_id, book_id=loan.book_id, interaction_type="return", weight=0.4)
    return loan


class RegisterView(APIView):
    authentication_classes = []

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        password = request.data.get("password", "")
        first_name = request.data.get("first_name", "").strip()
        last_name = request.data.get("last_name", "").strip()
        phone = request.data.get("phone", "").strip() or None
        if not email or not password or not first_name or not last_name:
            return Response({"detail": "Заповніть email, пароль, ім'я та прізвище."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            with transaction.atomic():
                user = User.objects.create(email=email, password_hash=make_password(password), role="reader")
                Profile.objects.create(user_id=user.user_id, first_name=first_name, last_name=last_name, phone=phone)
        except IntegrityError:
            return Response({"detail": "Користувач із таким email уже існує."}, status=status.HTTP_409_CONFLICT)
        return Response(
            {
                "user": UserSerializer(user).data,
                "tokens": build_tokens(user),
                "log": api_log("POST", "/api/v1/auth/register/", "INSERT INTO users (email, password_hash, role) VALUES (%s, %s, 'reader'); INSERT INTO profiles (user_id, first_name, last_name, phone) VALUES (%s, %s, %s, %s);"),
            },
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    authentication_classes = []

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        password = request.data.get("password", "")
        user = User.objects.filter(email=email).first()
        if not user or not check_password(password, user.password_hash):
            return Response({"detail": "Невірний email або пароль."}, status=status.HTTP_401_UNAUTHORIZED)
        return Response(
            {
                "user": UserSerializer(user).data,
                "tokens": build_tokens(user),
                "log": api_log("POST", "/api/v1/auth/login/", "SELECT * FROM users WHERE email = %s;"),
            }
        )


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = require_library_user(request)
        db_user = User.objects.get(user_id=user.user_id)
        return Response({"user": UserSerializer(db_user).data, "log": api_log("GET", "/api/v1/auth/me/", "SELECT u.*, p.* FROM users u LEFT JOIN profiles p ON p.user_id = u.user_id WHERE u.user_id = %s;")})


class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request):
        user = require_library_user(request)
        profile = Profile.objects.get(user_id=user.user_id)
        profile.first_name = request.data.get("first_name", profile.first_name)
        profile.last_name = request.data.get("last_name", profile.last_name)
        profile.phone = request.data.get("phone", profile.phone)
        profile.save(update_fields=["first_name", "last_name", "phone"])
        return Response({"profile": UserSerializer(User.objects.get(user_id=user.user_id)).data, "log": api_log("PUT", "/api/v1/auth/profile/", "UPDATE profiles SET first_name = %s, last_name = %s, phone = %s WHERE user_id = %s;")})


class GenreListView(APIView):
    def get(self, request):
        genres = Genre.objects.order_by("name")
        return Response({"results": GenreSerializer(genres, many=True).data, "log": api_log("GET", "/api/v1/genres/", "SELECT * FROM genres ORDER BY name;")})


class BookListCreateView(APIView):
    def get(self, request):
        search = request.query_params.get("search", "").strip()
        genre_id = request.query_params.get("genre_id")
        books = Book.objects.select_related("genre").order_by("title")
        if search:
            books = books.filter(Q(title__icontains=search) | Q(isbn__iexact=search))
        if genre_id:
            books = books.filter(genre_id=genre_id)
        page = max(int(request.query_params.get("page", 1)), 1)
        page_size = min(max(int(request.query_params.get("page_size", 20)), 1), 50)
        start = (page - 1) * page_size
        end = start + page_size
        return Response(
            {
                "count": books.count(),
                "results": BookSerializer(books[start:end], many=True).data,
                "log": api_log("GET", "/api/v1/books/", "SELECT b.*, g.name AS genre_name FROM books b LEFT JOIN genres g ON b.genre_id = g.genre_id WHERE b.title ILIKE %s OR b.isbn = %s;"),
            }
        )

    def post(self, request):
        user = require_library_user(request)
        if not user or user.role != "librarian":
            return Response({"detail": "Додавати книги може лише бібліотекар."}, status=status.HTTP_403_FORBIDDEN)
        serializer = BookCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        marc21_raw = {
            "leader": "00000nam a2200000 i 4500",
            "fields": {
                "020": data["isbn"],
                "245": data["title"],
                "260": data.get("publisher") or "",
                "650": str(data.get("genre_id") or ""),
            },
        }
        with transaction.atomic():
            book = Book.objects.create(
                genre_id=data.get("genre_id"),
                title=data["title"],
                isbn=data["isbn"],
                publisher=data.get("publisher"),
                publication_year=data.get("publication_year"),
                total_copies=data["total_copies"],
                available_copies=data["available_copies"],
                marc21_raw=marc21_raw,
            )
            for name in data.get("author_names", []):
                author, _ = Author.objects.get_or_create(full_name=name)
                with connection.cursor() as cursor:
                    cursor.execute(
                        "INSERT INTO book_authors (book_id, author_id) VALUES (%s, %s) ON CONFLICT DO NOTHING;",
                        [book.book_id, author.author_id],
                    )
        return Response({"book": BookSerializer(book).data, "log": api_log("POST", "/api/v1/books/", "INSERT INTO books (genre_id, title, isbn, publisher, publication_year, total_copies, available_copies, marc21_raw) VALUES (%s, %s, %s, %s, %s, %s, %s, %s); INSERT INTO book_authors (book_id, author_id) VALUES (%s, %s);")}, status=status.HTTP_201_CREATED)


class BookDetailView(APIView):
    def get(self, request, book_id):
        book = Book.objects.select_related("genre").filter(book_id=book_id).first()
        if not book:
            return Response({"detail": "Книгу не знайдено."}, status=status.HTTP_404_NOT_FOUND)
        return Response({"book": BookSerializer(book).data, "log": api_log("GET", f"/api/v1/books/{book_id}/", "SELECT b.*, g.name, a.* FROM books b LEFT JOIN genres g ON b.genre_id = g.genre_id LEFT JOIN book_authors ba ON ba.book_id = b.book_id LEFT JOIN authors a ON a.author_id = ba.author_id WHERE b.book_id = %s;")})


class BorrowBookView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = require_library_user(request)
        if not user:
            return Response({"detail": "Потрібно увійти в систему."}, status=status.HTTP_401_UNAUTHORIZED)
        try:
            book_id = int(request.data.get("book_id"))
            days = int(request.data.get("days", 14))
        except (TypeError, ValueError):
            return Response({"detail": "Некоректний ідентифікатор книги або строк видачі."}, status=status.HTTP_400_BAD_REQUEST)
        with transaction.atomic():
            book = Book.objects.select_for_update().filter(book_id=book_id).first()
            if not book:
                return Response({"detail": "Книгу не знайдено."}, status=status.HTTP_404_NOT_FOUND)
            if book.available_copies <= 0:
                return Response({"detail": "Немає доступних примірників."}, status=status.HTTP_409_CONFLICT)
            loan = Loan.objects.create(user_id=user.user_id, book_id=book.book_id, due_date=timezone.localdate() + timedelta(days=days), status="active")
            book.available_copies -= 1
            book.save(update_fields=["available_copies"])
            Interaction.objects.create(user_id=user.user_id, book_id=book.book_id, interaction_type="borrow", weight=1.0)
        return Response({"loan": LoanSerializer(loan).data, "log": api_log("POST", "/api/v1/loans/borrow/", "BEGIN; SELECT * FROM books WHERE book_id = %s FOR UPDATE; INSERT INTO loans (user_id, book_id, due_date, status) VALUES (%s, %s, %s, 'active'); UPDATE books SET available_copies = available_copies - 1 WHERE book_id = %s; COMMIT;")}, status=status.HTTP_201_CREATED)


class ReturnBookView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, loan_id):
        user = require_library_user(request)
        with transaction.atomic():
            loan = Loan.objects.select_for_update().filter(loan_id=loan_id, user_id=user.user_id).first()
            if not loan or loan.status == "returned":
                return Response({"detail": "Активну видачу не знайдено."}, status=status.HTTP_404_NOT_FOUND)
            loan = complete_loan_return(loan, user.user_id)
        return Response({"loan": LoanSerializer(loan).data, "log": api_log("POST", f"/api/v1/loans/{loan_id}/return/", "BEGIN; UPDATE loans SET return_date = CURRENT_DATE, status = 'returned' WHERE loan_id = %s; UPDATE books SET available_copies = available_copies + 1 WHERE book_id = %s; COMMIT;")})


class ActiveLoansView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = require_library_user(request)
        Loan.objects.filter(user_id=user.user_id, status="active", due_date__lt=timezone.localdate()).update(status="overdue")
        loans = Loan.objects.filter(user_id=user.user_id).exclude(status="returned").order_by("due_date")
        return Response({"results": LoanSerializer(loans, many=True).data, "log": api_log("GET", "/api/v1/loans/active/", "UPDATE loans SET status = 'overdue' WHERE CURRENT_DATE > due_date AND status = 'active'; SELECT * FROM loans WHERE user_id = %s AND status <> 'returned';")})


class LibrarianActiveLoansView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = require_library_user(request)
        if not is_librarian(user):
            return Response({"detail": "Модуль формулярів доступний лише бібліотекарю."}, status=status.HTTP_403_FORBIDDEN)
        Loan.objects.filter(status="active", return_date__isnull=True, due_date__lt=timezone.localdate()).update(status="overdue")
        loans = Loan.objects.filter(return_date__isnull=True).exclude(status="returned").order_by("due_date", "loan_id")
        return Response({"results": LoanSerializer(loans, many=True).data, "log": api_log("GET", "/api/v1/librarian/loans/active/", "UPDATE loans SET status = 'overdue' WHERE CURRENT_DATE > due_date AND return_date IS NULL; SELECT * FROM loans WHERE return_date IS NULL AND status <> 'returned' ORDER BY due_date, loan_id;")})


class LibrarianReturnBookView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, loan_id):
        user = require_library_user(request)
        if not is_librarian(user):
            return Response({"detail": "Приймати книги може лише бібліотекар."}, status=status.HTTP_403_FORBIDDEN)
        with transaction.atomic():
            loan = Loan.objects.select_for_update().filter(loan_id=loan_id, return_date__isnull=True).exclude(status="returned").first()
            if not loan:
                return Response({"detail": "Активний формуляр не знайдено."}, status=status.HTTP_404_NOT_FOUND)
            loan = complete_loan_return(loan, user.user_id)
        return Response({"loan": LoanSerializer(loan).data, "log": api_log("POST", f"/api/v1/librarian/loans/{loan_id}/return/", "BEGIN; SELECT * FROM loans WHERE loan_id = %s AND return_date IS NULL FOR UPDATE; UPDATE loans SET return_date = CURRENT_DATE, status = 'returned' WHERE loan_id = %s; UPDATE books SET available_copies = available_copies + 1 WHERE book_id = %s; COMMIT;")})


class ReservationCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = require_library_user(request)
        book_id = int(request.data.get("book_id"))
        book = Book.objects.filter(book_id=book_id).first()
        if not book:
            return Response({"detail": "Книгу не знайдено."}, status=status.HTTP_404_NOT_FOUND)
        reservation = Reservation.objects.create(user_id=user.user_id, book_id=book_id, expiration_date=timezone.now() + timedelta(days=3), status="pending")
        return Response({"reservation": ReservationSerializer(reservation).data, "log": api_log("POST", "/api/v1/reservations/", "INSERT INTO reservations (user_id, book_id, expiration_date, status) VALUES (%s, %s, %s, 'pending');")}, status=status.HTTP_201_CREATED)


class ReservationCancelView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, reservation_id):
        user = require_library_user(request)
        updated = Reservation.objects.filter(reservation_id=reservation_id, user_id=user.user_id).update(status="expired")
        if not updated:
            return Response({"detail": "Бронювання не знайдено."}, status=status.HTTP_404_NOT_FOUND)
        return Response({"status": "expired", "log": api_log("POST", f"/api/v1/reservations/{reservation_id}/cancel/", "UPDATE reservations SET status = 'expired' WHERE reservation_id = %s;")})


class RatingView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = require_library_user(request)
        if not user:
            return Response({"detail": "Потрібно увійти в систему."}, status=status.HTTP_401_UNAUTHORIZED)
        ratings = Rating.objects.filter(user_id=user.user_id).order_by("-rated_at")
        return Response({"results": RatingSerializer(ratings, many=True).data, "log": api_log("GET", "/api/v1/ratings/", "SELECT * FROM ratings WHERE user_id = %s ORDER BY rated_at DESC;")})

    def post(self, request):
        user = require_library_user(request)
        if not user:
            return Response({"detail": "Потрібно увійти в систему."}, status=status.HTTP_401_UNAUTHORIZED)
        try:
            book_id = int(request.data.get("book_id"))
            value = int(request.data.get("value"))
        except (TypeError, ValueError):
            return Response({"detail": "Некоректна книга або оцінка."}, status=status.HTTP_400_BAD_REQUEST)
        if value < 1 or value > 5:
            return Response({"detail": "Оцінка має бути від 1 до 5."}, status=status.HTTP_400_BAD_REQUEST)
        if not Book.objects.filter(book_id=book_id).exists():
            return Response({"detail": "Книгу не знайдено."}, status=status.HTTP_404_NOT_FOUND)
        if Rating.objects.filter(user_id=user.user_id, book_id=book_id).exists():
            return Response({"detail": "Ви вже оцінили цю книгу."}, status=status.HTTP_409_CONFLICT)
        rating = Rating.objects.create(user_id=user.user_id, book_id=book_id, value=value)
        Interaction.objects.create(user_id=user.user_id, book_id=book_id, interaction_type="rating", weight=float(value) / 5.0)
        return Response({"rating": RatingSerializer(rating).data, "log": api_log("POST", "/api/v1/ratings/", "INSERT INTO ratings (user_id, book_id, value) VALUES (%s, %s, %s);")}, status=status.HTTP_201_CREATED)


class InteractionView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = require_library_user(request)
        if not user:
            return Response({"detail": "Потрібно увійти в систему."}, status=status.HTTP_401_UNAUTHORIZED)
        try:
            book_id = int(request.data.get("book_id"))
            weight = float(request.data.get("weight", 0.2))
        except (TypeError, ValueError):
            return Response({"detail": "Некоректна книга або вага взаємодії."}, status=status.HTTP_400_BAD_REQUEST)
        if not Book.objects.filter(book_id=book_id).exists():
            return Response({"detail": "Книгу не знайдено."}, status=status.HTTP_404_NOT_FOUND)
        interaction = Interaction.objects.create(
            user_id=user.user_id,
            book_id=book_id,
            interaction_type=request.data.get("interaction_type", "view_details"),
            weight=weight,
        )
        return Response({"interaction": InteractionSerializer(interaction).data, "log": api_log("POST", "/api/v1/interactions/", "INSERT INTO interactions (user_id, book_id, interaction_type, weight) VALUES (%s, %s, %s, %s);")}, status=status.HTTP_201_CREATED)


class RecommendationView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = require_library_user(request)
        top_k = int(request.data.get("top_k", 5))
        service = SmartLibraryRecommender()
        result = service.recommend(user.user_id, top_k)
        explanation = service.explain(user.user_id, result["items"])
        return Response({"mode": result["mode"], "recommendations": result["items"], "explanation": explanation, "log": api_log("POST", "/api/v1/ai/recommendations/", "SELECT * FROM ratings; SELECT * FROM books WHERE book_id NOT IN (SELECT book_id FROM ratings WHERE user_id = %s); SVD.predict(user_id, book_id);")})


class TrainModelView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = require_library_user(request)
        if not user or user.role != "admin":
            return Response({"detail": "Панель навчання ШІ доступна лише адміністратору."}, status=status.HTTP_403_FORBIDDEN)
        result = SmartLibraryRecommender().train()
        return Response(
            {
                "training": result,
                "python_logs": result.get("python_logs", []),
                "log": api_log("POST", "/api/v1/ai/train/", "SELECT user_id, book_id, value FROM ratings; FIT Surprise SVD; INSERT INTO model_stats (version, rmse, mae, weights_path) VALUES (%s, %s, %s, %s);"),
            }
        )


class ModelStatsView(APIView):
    def get(self, request):
        stats = ModelStats.objects.order_by("-trained_at").first()
        data = ModelStatsSerializer(stats).data if stats else None
        return Response({"stats": data, "log": api_log("GET", "/api/v1/ai/stats/", "SELECT * FROM model_stats ORDER BY trained_at DESC LIMIT 1;")})
