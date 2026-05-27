from django.db import models


class User(models.Model):
    user_id = models.AutoField(primary_key=True)
    email = models.CharField(max_length=255, unique=True)
    password_hash = models.CharField(max_length=255)
    role = models.CharField(max_length=50, default="reader")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = "users"


class Profile(models.Model):
    profile_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(User, db_column="user_id", on_delete=models.CASCADE, related_name="profiles")
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    phone = models.CharField(max_length=20, null=True, blank=True)
    registration_date = models.DateField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = "profiles"


class Genre(models.Model):
    genre_id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = "genres"


class Book(models.Model):
    book_id = models.AutoField(primary_key=True)
    genre = models.ForeignKey(Genre, db_column="genre_id", null=True, blank=True, on_delete=models.SET_NULL)
    title = models.CharField(max_length=255)
    isbn = models.CharField(max_length=20, unique=True)
    publisher = models.CharField(max_length=150, null=True, blank=True)
    publication_year = models.IntegerField(null=True, blank=True)
    total_copies = models.IntegerField(default=1)
    available_copies = models.IntegerField(default=1)
    marc21_raw = models.JSONField()
    added_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = "books"


class Author(models.Model):
    author_id = models.AutoField(primary_key=True)
    full_name = models.CharField(max_length=255)
    biography = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = "authors"


class BookAuthor(models.Model):
    book = models.ForeignKey(Book, db_column="book_id", on_delete=models.CASCADE, primary_key=True)
    author = models.ForeignKey(Author, db_column="author_id", on_delete=models.CASCADE)

    class Meta:
        managed = False
        db_table = "book_authors"
        unique_together = (("book", "author"),)


class Loan(models.Model):
    loan_id = models.AutoField(primary_key=True)
    user_id = models.IntegerField()
    book_id = models.IntegerField()
    borrow_date = models.DateField(auto_now_add=True)
    due_date = models.DateField()
    return_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=50, default="active")

    class Meta:
        managed = False
        db_table = "loans"
        indexes = [models.Index(fields=["user_id", "book_id"])]


class Reservation(models.Model):
    reservation_id = models.AutoField(primary_key=True)
    user_id = models.IntegerField()
    book_id = models.IntegerField()
    reserved_at = models.DateTimeField(auto_now_add=True)
    expiration_date = models.DateTimeField()
    status = models.CharField(max_length=50, default="pending")

    class Meta:
        managed = False
        db_table = "reservations"
        indexes = [models.Index(fields=["user_id", "book_id"])]


class Rating(models.Model):
    rating_id = models.AutoField(primary_key=True)
    user_id = models.IntegerField()
    book_id = models.IntegerField()
    value = models.IntegerField()
    rated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = "ratings"
        unique_together = (("user_id", "book_id"),)
        indexes = [models.Index(fields=["user_id", "book_id"])]


class Interaction(models.Model):
    interaction_id = models.AutoField(primary_key=True)
    user_id = models.IntegerField()
    book_id = models.IntegerField()
    interaction_type = models.CharField(max_length=50)
    weight = models.FloatField(default=0.0)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = "interactions"
        indexes = [models.Index(fields=["user_id", "book_id"])]


class ModelStats(models.Model):
    version = models.CharField(max_length=50, primary_key=True)
    rmse = models.FloatField()
    mae = models.FloatField()
    weights_path = models.CharField(max_length=500)
    trained_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = "model_stats"
