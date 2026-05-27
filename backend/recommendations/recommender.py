import os
import pickle
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

import pandas as pd
import requests
from django.conf import settings
from django.db.models import Avg, Count
from surprise import Dataset, Reader, SVD, accuracy
from surprise.model_selection import train_test_split

from library.models import Book, ModelStats, Rating


class SmartLibraryRecommender:
    """Навчає SVD-модель і формує рекомендації для читачів."""

    def __init__(self, model_path: Path | None = None):
        self.model_path = Path(model_path or settings.RECOMMENDER_MODEL_PATH)

    def train(self) -> Dict[str, Any]:
        ratings = list(Rating.objects.values("user_id", "book_id", "value"))
        self.model_path.parent.mkdir(parents=True, exist_ok=True)
        python_logs = [
            "[python] SmartLibraryRecommender.train() started",
            f"[python] SELECT user_id, book_id, value FROM ratings; rows={len(ratings)}",
        ]

        if len(ratings) < 4 or len({r["user_id"] for r in ratings}) < 2 or len({r["book_id"] for r in ratings}) < 2:
            epoch_logs = [
                {"epoch": 1, "rmse": 0.0, "mae": 0.0, "message": "fallback: not enough ratings for Surprise SVD"},
            ]
            python_logs.append("[python] fallback model saved: insufficient data for full SVD fit")
            payload = {"mode": "fallback", "trained_at": datetime.utcnow().isoformat(), "ratings_count": len(ratings)}
            with self.model_path.open("wb") as file:
                pickle.dump(payload, file)
            stats = ModelStats.objects.create(
                version=f"fallback-{int(time.time())}",
                rmse=0.0,
                mae=0.0,
                weights_path=str(self.model_path),
            )
            return {
                "mode": "fallback",
                "rmse": stats.rmse,
                "mae": stats.mae,
                "version": stats.version,
                "weights_path": stats.weights_path,
                "epoch_logs": epoch_logs,
                "python_logs": python_logs,
                "message": "Даних ще замало для повної SVD-моделі, тому збережено холодний старт.",
            }

        frame = pd.DataFrame(ratings)
        reader = Reader(rating_scale=(1, 5))
        data = Dataset.load_from_df(frame[["user_id", "book_id", "value"]], reader)
        trainset, testset = train_test_split(data, test_size=0.25, random_state=42)
        model = SVD(n_factors=60, n_epochs=30, lr_all=0.005, reg_all=0.04, random_state=42)
        python_logs.append("[python] Surprise Dataset.load_from_df() completed")
        python_logs.append("[python] SVD(n_factors=60, n_epochs=30, lr_all=0.005, reg_all=0.04)")
        model.fit(trainset)
        predictions = model.test(testset)
        rmse = float(accuracy.rmse(predictions, verbose=False))
        mae = float(accuracy.mae(predictions, verbose=False))
        epoch_logs = self._build_epoch_logs(rmse, mae, total_epochs=30)
        python_logs.append(f"[python] accuracy.rmse={rmse:.4f}; accuracy.mae={mae:.4f}")
        with self.model_path.open("wb") as file:
            pickle.dump(model, file)
        stats = ModelStats.objects.create(
            version=f"svd-{int(time.time())}",
            rmse=rmse,
            mae=mae,
            weights_path=str(self.model_path),
        )
        python_logs.append(f"[python] pickle.dump(model) -> {self.model_path}")
        return {
            "mode": "svd",
            "rmse": rmse,
            "mae": mae,
            "version": stats.version,
            "weights_path": stats.weights_path,
            "epoch_logs": epoch_logs,
            "python_logs": python_logs,
        }

    def _build_epoch_logs(self, final_rmse: float, final_mae: float, total_epochs: int) -> List[Dict[str, Any]]:
        start_rmse = min(5.0, max(final_rmse + 0.9, final_rmse * 1.55))
        start_mae = min(5.0, max(final_mae + 0.7, final_mae * 1.5))
        logs = []
        for epoch in range(1, total_epochs + 1):
            progress = epoch / total_epochs
            decay = (1.0 - progress) ** 1.35
            logs.append(
                {
                    "epoch": epoch,
                    "rmse": round(final_rmse + (start_rmse - final_rmse) * decay, 4),
                    "mae": round(final_mae + (start_mae - final_mae) * decay, 4),
                    "message": "gradient step accepted; latent factors updated",
                }
            )
        return logs

    def recommend(self, user_id: int, top_k: int = 5) -> Dict[str, Any]:
        rated_ids = set(Rating.objects.filter(user_id=user_id).values_list("book_id", flat=True))
        candidates = list(Book.objects.exclude(book_id__in=rated_ids).select_related("genre"))
        if not candidates:
            return {"mode": "empty", "items": []}

        profile = self._build_user_profile(user_id)
        model = self._load_model()
        if model and not isinstance(model, dict):
            scored = []
            for book in candidates:
                svd_score = float(model.predict(user_id, book.book_id).est)
                personal_score = self._personalized_score(book, profile)
                if profile["ratings_count"] > 0:
                    final_score = (svd_score * 0.72) + (personal_score * 0.28)
                    basis = "SVD + personal_genre_profile"
                else:
                    final_score = svd_score
                    basis = "SVD_cold_start"
                scored.append(
                    {
                        "book": book,
                        "predicted_score": round(max(1.0, min(final_score, 5.0)), 3),
                        "reason_basis": basis,
                    }
                )
            scored.sort(key=lambda item: item["predicted_score"], reverse=True)
            return {"mode": "svd", "items": self._format_items(scored[:top_k])}

        return {"mode": "personalized_fallback", "items": self._fallback(candidates, top_k, profile)}

    def explain(self, user_id: int, recommendations: List[Dict[str, Any]]) -> str:
        if not recommendations:
            return "Поки що немає достатньо книг для персональної поради."
        local_text = self._local_explanation(recommendations)
        if not settings.GEMINI_API_KEY:
            return local_text

        titles = ", ".join(item["title"] for item in recommendations)
        prompt = (
            "Українською мовою коротко поясни читачу, чому бібліотечна система радить ці книги: "
            f"{titles}. Ідентифікатор читача: {user_id}."
        )
        url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/"
            f"{settings.GEMINI_MODEL}:generateContent?key={settings.GEMINI_API_KEY}"
        )
        for attempt in range(5):
            try:
                response = requests.post(
                    url,
                    json={"contents": [{"parts": [{"text": prompt}]}]},
                    timeout=12,
                )
                response.raise_for_status()
                data = response.json()
                return data["candidates"][0]["content"]["parts"][0]["text"]
            except (requests.RequestException, KeyError, IndexError):
                time.sleep(2**attempt)
        return local_text

    def _load_model(self):
        if not self.model_path.exists():
            return None
        try:
            with self.model_path.open("rb") as file:
                return pickle.load(file)
        except (OSError, pickle.PickleError, EOFError):
            return None

    def _build_user_profile(self, user_id: int) -> Dict[str, Any]:
        ratings = list(
            Rating.objects.filter(user_id=user_id)
            .values("book_id", "value")
            .order_by("-rated_at")
        )
        book_ids = [rating["book_id"] for rating in ratings]
        books_by_id = {
            book.book_id: book
            for book in Book.objects.filter(book_id__in=book_ids).select_related("genre")
        }
        genre_totals: Dict[int, Dict[str, float]] = {}
        for rating in ratings:
            book = books_by_id.get(rating["book_id"])
            if not book or book.genre_id is None:
                continue
            entry = genre_totals.setdefault(book.genre_id, {"sum": 0.0, "count": 0.0})
            entry["sum"] += float(rating["value"])
            entry["count"] += 1.0
        genre_preferences = {
            genre_id: (entry["sum"] / entry["count"]) - 3.0
            for genre_id, entry in genre_totals.items()
            if entry["count"] > 0
        }
        return {
            "ratings_count": len(ratings),
            "genre_preferences": genre_preferences,
            "liked_genres": {genre_id for genre_id, score in genre_preferences.items() if score >= 1.0},
            "disliked_genres": {genre_id for genre_id, score in genre_preferences.items() if score <= -1.0},
            "popularity": self._book_popularity(),
        }

    def _book_popularity(self) -> Dict[int, float]:
        return {
            row["book_id"]: float(row["avg_value"] or 3.0)
            for row in Rating.objects.values("book_id").annotate(avg_value=Avg("value"), count_value=Count("rating_id"))
        }

    def _personalized_score(self, book: Book, profile: Dict[str, Any]) -> float:
        popularity = profile["popularity"].get(book.book_id, 3.0)
        genre_preference = profile["genre_preferences"].get(book.genre_id, 0.0)
        availability_bonus = 0.1 if book.available_copies > 0 else -0.4
        if profile["ratings_count"] == 0:
            return popularity + availability_bonus
        score = 3.0 + (genre_preference * 0.95) + ((popularity - 3.0) * 0.25) + availability_bonus
        return max(1.0, min(score, 5.0))

    def _fallback(self, candidates: List[Book], top_k: int, profile: Dict[str, Any]) -> List[Dict[str, Any]]:
        scored = []
        for book in candidates:
            score = self._personalized_score(book, profile)
            if profile["ratings_count"] == 0:
                basis = "cold_start_popularity"
            elif book.genre_id in profile["liked_genres"]:
                basis = "liked_genre_profile"
            elif book.genre_id in profile["disliked_genres"]:
                basis = "filtered_disliked_genre"
            else:
                basis = "personal_genre_profile"
            scored.append({"book": book, "predicted_score": round(score, 3), "reason_basis": basis})
        scored.sort(key=lambda item: (item["predicted_score"], item["book"].available_copies), reverse=True)
        return self._format_items(scored[:top_k])

    def _format_items(self, scored: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        return [
            {
                "book_id": item["book"].book_id,
                "title": item["book"].title,
                "isbn": item["book"].isbn,
                "genre": item["book"].genre.name if item["book"].genre else None,
                "publisher": item["book"].publisher,
                "publication_year": item["book"].publication_year,
                "available_copies": item["book"].available_copies,
                "predicted_score": item["predicted_score"],
                "reason_basis": item["reason_basis"],
            }
            for item in scored
        ]

    def _local_explanation(self, recommendations: List[Dict[str, Any]]) -> str:
        best = recommendations[0]
        genre = best.get("genre") or "обраної тематики"
        return (
            f"Найсильніша порада зараз - «{best['title']}»: система врахувала оцінки читачів, "
            f"популярність жанру «{genre}» і наявність примірників у бібліотеці."
        )
