from django.contrib import admin
from django.urls import path
from library import views

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/auth/register/", views.RegisterView.as_view()),
    path("api/v1/auth/login/", views.LoginView.as_view()),
    path("api/v1/auth/profile/", views.ProfileView.as_view()),
    path("api/v1/auth/me/", views.MeView.as_view()),
    path("api/v1/books/", views.BookListCreateView.as_view()),
    path("api/v1/books/<int:book_id>/", views.BookDetailView.as_view()),
    path("api/v1/genres/", views.GenreListView.as_view()),
    path("api/v1/loans/borrow/", views.BorrowBookView.as_view()),
    path("api/v1/loans/<int:loan_id>/return/", views.ReturnBookView.as_view()),
    path("api/v1/loans/active/", views.ActiveLoansView.as_view()),
    path("api/v1/librarian/loans/active/", views.LibrarianActiveLoansView.as_view()),
    path("api/v1/librarian/loans/<int:loan_id>/return/", views.LibrarianReturnBookView.as_view()),
    path("api/v1/reservations/", views.ReservationCreateView.as_view()),
    path("api/v1/reservations/<int:reservation_id>/cancel/", views.ReservationCancelView.as_view()),
    path("api/v1/ratings/", views.RatingView.as_view()),
    path("api/v1/interactions/", views.InteractionView.as_view()),
    path("api/v1/ai/recommendations/", views.RecommendationView.as_view()),
    path("api/v1/ai/train/", views.TrainModelView.as_view()),
    path("api/v1/ai/stats/", views.ModelStatsView.as_view()),
]
