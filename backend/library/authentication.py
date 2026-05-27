from dataclasses import dataclass

from rest_framework import authentication, exceptions
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import UntypedToken

from .models import User


@dataclass
class AuthenticatedLibraryUser:
    user_id: int
    email: str
    role: str
    is_authenticated: bool = True


class LibraryJWTAuthentication(authentication.BaseAuthentication):
    """Перевіряє JWT і підставляє користувача з таблиці users."""

    def authenticate(self, request):
        header = authentication.get_authorization_header(request).decode("utf-8")
        if not header.startswith("Bearer "):
            return None
        raw_token = header.split(" ", 1)[1].strip()
        try:
            token = UntypedToken(raw_token)
            user_id = int(token.get("user_id"))
            user = User.objects.get(user_id=user_id)
        except (TokenError, InvalidToken, User.DoesNotExist, ValueError, TypeError):
            raise exceptions.AuthenticationFailed("Недійсний або прострочений токен.")
        auth_user = AuthenticatedLibraryUser(user.user_id, user.email, user.role)
        request.library_user = auth_user
        return auth_user, token
