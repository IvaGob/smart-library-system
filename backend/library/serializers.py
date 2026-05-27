from rest_framework import serializers

from django.db import connection

from .models import Book, Genre, Interaction, Loan, ModelStats, Profile, Rating, Reservation, User


class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = Profile
        fields = ["profile_id", "user_id", "first_name", "last_name", "phone", "registration_date"]


class UserSerializer(serializers.ModelSerializer):
    profile = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ["user_id", "email", "role", "created_at", "updated_at", "profile"]

    def get_profile(self, obj):
        profile = Profile.objects.filter(user_id=obj.user_id).first()
        return ProfileSerializer(profile).data if profile else None


class GenreSerializer(serializers.ModelSerializer):
    class Meta:
        model = Genre
        fields = ["genre_id", "name", "description"]


class BookSerializer(serializers.ModelSerializer):
    genre_name = serializers.CharField(source="genre.name", read_only=True)
    authors = serializers.SerializerMethodField()

    class Meta:
        model = Book
        fields = [
            "book_id",
            "genre_id",
            "genre_name",
            "title",
            "isbn",
            "publisher",
            "publication_year",
            "total_copies",
            "available_copies",
            "marc21_raw",
            "added_at",
            "authors",
        ]

    def get_authors(self, obj):
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT a.author_id, a.full_name, a.biography
                FROM authors a
                JOIN book_authors ba ON ba.author_id = a.author_id
                WHERE ba.book_id = %s
                ORDER BY a.full_name
                """,
                [obj.book_id],
            )
            return [
                {"author_id": row[0], "full_name": row[1], "biography": row[2]}
                for row in cursor.fetchall()
            ]


class BookCreateSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=255)
    isbn = serializers.CharField(max_length=20)
    genre_id = serializers.IntegerField(required=False, allow_null=True)
    publisher = serializers.CharField(max_length=150, required=False, allow_blank=True, allow_null=True)
    publication_year = serializers.IntegerField(required=False, allow_null=True)
    total_copies = serializers.IntegerField(min_value=0, default=1)
    available_copies = serializers.IntegerField(min_value=0, required=False)
    author_names = serializers.ListField(child=serializers.CharField(max_length=255), required=False)

    def validate(self, attrs):
        total = attrs.get("total_copies", 1)
        available = attrs.get("available_copies", total)
        if available > total:
            raise serializers.ValidationError("Кількість доступних примірників не може перевищувати загальну.")
        attrs["available_copies"] = available
        return attrs


class LoanSerializer(serializers.ModelSerializer):
    book = serializers.SerializerMethodField()
    reader = serializers.SerializerMethodField()
    is_debtor = serializers.SerializerMethodField()

    class Meta:
        model = Loan
        fields = ["loan_id", "user_id", "book_id", "borrow_date", "due_date", "return_date", "status", "book", "reader", "is_debtor"]

    def get_book(self, obj):
        book = Book.objects.filter(book_id=obj.book_id).first()
        return {"title": book.title, "isbn": book.isbn} if book else None

    def get_reader(self, obj):
        user = User.objects.filter(user_id=obj.user_id).first()
        profile = Profile.objects.filter(user_id=obj.user_id).first()
        return {
            "email": user.email if user else None,
            "first_name": profile.first_name if profile else None,
            "last_name": profile.last_name if profile else None,
            "phone": profile.phone if profile else None,
        }

    def get_is_debtor(self, obj):
        from django.utils import timezone

        return obj.return_date is None and obj.due_date < timezone.localdate()


class ReservationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Reservation
        fields = ["reservation_id", "user_id", "book_id", "reserved_at", "expiration_date", "status"]


class RatingSerializer(serializers.ModelSerializer):
    class Meta:
        model = Rating
        fields = ["rating_id", "user_id", "book_id", "value", "rated_at"]


class InteractionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Interaction
        fields = ["interaction_id", "user_id", "book_id", "interaction_type", "weight", "timestamp"]


class ModelStatsSerializer(serializers.ModelSerializer):
    class Meta:
        model = ModelStats
        fields = ["version", "rmse", "mae", "weights_path", "trained_at"]
