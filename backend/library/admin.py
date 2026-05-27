from django.contrib import admin

from .models import Book, Genre, Interaction, Loan, ModelStats, Profile, Rating, Reservation, User


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    """Показує облікові записи читачів у адміністративній панелі."""

    list_display = ("user_id", "email", "role", "created_at", "updated_at")
    search_fields = ("email", "role")
    list_filter = ("role",)


@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    """Показує профілі користувачів бібліотеки."""

    list_display = ("profile_id", "user_id", "first_name", "last_name", "phone", "registration_date")
    search_fields = ("first_name", "last_name", "phone")


@admin.register(Genre)
class GenreAdmin(admin.ModelAdmin):
    """Показує жанри каталогу."""

    list_display = ("genre_id", "name")
    search_fields = ("name",)


@admin.register(Book)
class BookAdmin(admin.ModelAdmin):
    """Показує MARC21-каталог книг."""

    list_display = ("book_id", "title", "isbn", "genre", "total_copies", "available_copies", "added_at")
    search_fields = ("title", "isbn", "publisher")
    list_filter = ("genre", "publication_year")


@admin.register(Loan)
class LoanAdmin(admin.ModelAdmin):
    """Показує логічно ізольовані записи видач."""

    list_display = ("loan_id", "user_id", "book_id", "borrow_date", "due_date", "return_date", "status")
    search_fields = ("user_id", "book_id", "status")
    list_filter = ("status",)


@admin.register(Reservation)
class ReservationAdmin(admin.ModelAdmin):
    """Показує чергу бронювань."""

    list_display = ("reservation_id", "user_id", "book_id", "reserved_at", "expiration_date", "status")
    search_fields = ("user_id", "book_id", "status")
    list_filter = ("status",)


@admin.register(Rating)
class RatingAdmin(admin.ModelAdmin):
    """Показує оцінки для навчання рекомендаційної моделі."""

    list_display = ("rating_id", "user_id", "book_id", "value", "rated_at")
    search_fields = ("user_id", "book_id")
    list_filter = ("value",)


@admin.register(Interaction)
class InteractionAdmin(admin.ModelAdmin):
    """Показує неявні взаємодії користувачів із каталогом."""

    list_display = ("interaction_id", "user_id", "book_id", "interaction_type", "weight", "timestamp")
    search_fields = ("user_id", "book_id", "interaction_type")
    list_filter = ("interaction_type",)


@admin.register(ModelStats)
class ModelStatsAdmin(admin.ModelAdmin):
    """Показує метрики навчання SVD-моделі."""

    list_display = ("version", "rmse", "mae", "weights_path", "trained_at")
    search_fields = ("version", "weights_path")
