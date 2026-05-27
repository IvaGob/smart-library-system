import React, { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  BadgeCheck,
  BookOpen,
  Brain,
  CheckCircle2,
  Clock3,
  Database,
  Library,
  LogIn,
  LogOut,
  RefreshCw,
  RotateCcw,
  Search,
  Send,
  Star,
  Terminal,
  X,
  UserPlus
} from "lucide-react";

const API_BASE = process.env.REACT_APP_API_BASE || "http://localhost:8000";
const MODEL_ERROR_THRESHOLDS = {
  warningRmse: 1.0,
  criticalRmse: 1.5,
  warningMae: 0.8,
  criticalMae: 1.2
};

const tabs = [
  { id: "catalog", label: "Каталог", icon: BookOpen },
  { id: "loans", label: "Видачі", icon: Clock3 },
  { id: "ai", label: "ШІ", icon: Brain },
  { id: "profile", label: "Профіль", icon: BadgeCheck }
];

function App() {
  const [activeTab, setActiveTab] = useState("catalog");
  const [token, setToken] = useState(localStorage.getItem("smartlibrary_token") || "");
  const [user, setUser] = useState(null);
  const [books, setBooks] = useState([]);
  const [genres, setGenres] = useState([]);
  const [loans, setLoans] = useState([]);
  const [recommendations, setRecommendations] = useState([]);
  const [explanation, setExplanation] = useState("");
  const [stats, setStats] = useState(null);
  const [search, setSearch] = useState("");
  const [selectedGenre, setSelectedGenre] = useState("");
  const [authMode, setAuthMode] = useState("login");
  const [message, setMessage] = useState("");
  const [selectedBook, setSelectedBook] = useState(null);
  const [ratings, setRatings] = useState({});
  const [devLogs, setDevLogs] = useState([]);
  const [trainingEpochs, setTrainingEpochs] = useState([]);
  const [isTraining, setIsTraining] = useState(false);
  const [authForm, setAuthForm] = useState({
    email: "reader@example.com",
    password: "reader12345",
    first_name: "Марія",
    last_name: "Коваленко",
    phone: "+380501112233"
  });

  const headers = useMemo(() => {
    const base = { "Content-Type": "application/json" };
    return token ? { ...base, Authorization: `Bearer ${token}` } : base;
  }, [token]);

  const isReader = user?.role === "reader";
  const isLibrarian = user?.role === "librarian" || user?.role === "admin";
  const isAdmin = user?.role === "admin";
  const modelQuality = getModelQuality(stats);

  function addLog(entry) {
    const now = new Date().toLocaleTimeString("uk-UA", { hour12: false });
    const nextEntry = {
      type: entry?.type || "system",
      text: entry?.text || "",
      time: entry?.time || now
    };
    setDevLogs((current) => [...current.slice(-79), nextEntry]);
  }

  async function api(path, options = {}) {
    const method = options.method || "GET";
    addLog({ type: "api", text: `${method} ${path}` });
    try {
      const response = await fetch(`${API_BASE}${path}`, {
        ...options,
        headers: { ...headers, ...(options.headers || {}) }
      });
      const contentType = response.headers.get("content-type") || "";
      const raw = await response.text();
      let data = {};
      if (raw && contentType.includes("application/json")) {
        data = JSON.parse(raw);
      } else if (raw) {
        const plain = raw.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
        data = { detail: plain.slice(0, 260) || "Сервер повернув HTML замість JSON." };
      }
      if (data.log) {
        addLog({ type: "sql", text: data.log.sql });
        addLog({ type: "api", text: `${data.log.method} ${data.log.path} → ${response.status}` });
      }
      if (Array.isArray(data.python_logs)) {
        data.python_logs.forEach((line) => addLog({ type: "python", text: line }));
      }
      if (!response.ok) {
        if (response.status === 401 || response.status === 403) {
          localStorage.removeItem("smartlibrary_token");
          setToken("");
          setUser(null);
        }
        throw new Error(data.detail || `Запит не виконано. Код ${response.status}.`);
      }
      return data;
    } catch (error) {
      addLog({ type: "error", text: error.message });
      setMessage(error.message);
      throw error;
    }
  }

  async function loadCatalog(query = search, genre = selectedGenre) {
    const params = new URLSearchParams();
    if (query) params.set("search", query);
    if (genre) params.set("genre_id", genre);
    const suffix = params.toString() ? `?${params.toString()}` : "";
    const data = await api(`/api/v1/books/${suffix}`);
    setBooks(data.results || []);
  }

  async function loadGenres() {
    const data = await api("/api/v1/genres/");
    setGenres(data.results || []);
  }

  async function loadLoans() {
    if (!token || !user) return;
    const path = isLibrarian ? "/api/v1/librarian/loans/active/" : "/api/v1/loans/active/";
    const data = await api(path);
    setLoans(data.results || []);
  }

  async function loadRatings() {
    if (!token || !user) return;
    const data = await api("/api/v1/ratings/");
    const nextRatings = {};
    (data.results || []).forEach((rating) => {
      nextRatings[rating.book_id] = rating.value;
    });
    setRatings(nextRatings);
  }

  async function loadStats() {
    const data = await api("/api/v1/ai/stats/");
    setStats(data.stats);
    const quality = getModelQuality(data.stats);
    if (quality.level === "critical") {
      addLog({ type: "error", text: `AI model error is critical: RMSE=${data.stats?.rmse}, MAE=${data.stats?.mae}` });
    }
  }

  async function loadMe() {
    if (!token) return;
    try {
      const data = await api("/api/v1/auth/me/");
      setUser(data.user);
    } catch {
      localStorage.removeItem("smartlibrary_token");
      setToken("");
    }
  }

  useEffect(() => {
    loadGenres();
    loadCatalog("", "");
  }, []);

  useEffect(() => {
    loadMe();
    loadStats();
  }, [token]);

  useEffect(() => {
    if (user) {
      loadRatings();
      loadLoans();
    } else {
      setRatings({});
      setLoans([]);
    }
  }, [user]);

  async function submitAuth(event) {
    event.preventDefault();
    const path = authMode === "login" ? "/api/v1/auth/login/" : "/api/v1/auth/register/";
    const payload = authMode === "login"
      ? { email: authForm.email, password: authForm.password }
      : authForm;
    const data = await api(path, { method: "POST", body: JSON.stringify(payload) });
    setUser(data.user);
    setToken(data.tokens.access);
    localStorage.setItem("smartlibrary_token", data.tokens.access);
    setMessage(authMode === "login" ? "Вхід виконано." : "Обліковий запис створено.");
  }

  function logout() {
    localStorage.removeItem("smartlibrary_token");
    setToken("");
    setUser(null);
    setLoans([]);
    setRatings({});
    setRecommendations([]);
    addLog({ type: "system", text: "Сесію завершено локально." });
  }

  async function borrowBook(bookId) {
    if (!isReader) {
      setMessage("Видача доступна лише для читача.");
      return;
    }
    await api("/api/v1/loans/borrow/", { method: "POST", body: JSON.stringify({ book_id: bookId, days: 14 }) });
    setMessage("Книгу видано на 14 днів.");
    await loadCatalog();
    await loadLoans();
  }

  async function returnBook(loanId) {
    const path = isLibrarian ? `/api/v1/librarian/loans/${loanId}/return/` : `/api/v1/loans/${loanId}/return/`;
    await api(path, { method: "POST", body: JSON.stringify({}) });
    setMessage(isLibrarian ? "Книгу прийнято, формуляр закрито." : "Повернення зафіксовано.");
    await loadCatalog();
    await loadLoans();
  }

  async function rateBook(bookId, value) {
    if (!isReader) {
      setMessage("Оцінювання доступне лише для читача.");
      return;
    }
    if (ratings[bookId]) {
      setMessage(`Ваша оцінка цієї книги: ${ratings[bookId]}. Повторне оцінювання вимкнено.`);
      return;
    }
    const data = await api("/api/v1/ratings/", { method: "POST", body: JSON.stringify({ book_id: bookId, value }) });
    setRatings((current) => ({ ...current, [bookId]: data.rating.value }));
    setMessage("Оцінку збережено для SVD.");
  }

  async function viewBook(bookId) {
    const data = await api(`/api/v1/books/${bookId}/`);
    setSelectedBook(data.book);
    if (user) {
      await api("/api/v1/interactions/", {
        method: "POST",
        body: JSON.stringify({ book_id: bookId, interaction_type: "view_details", weight: 0.2 })
      });
    }
  }

  async function trainModel() {
    if (!isAdmin) {
      setMessage("Панель навчання ШІ доступна лише адміністратору.");
      return;
    }
    setIsTraining(true);
    setTrainingEpochs([]);
    addLog({ type: "python", text: "[python] forced retraining requested from admin panel" });
    try {
      const data = await api("/api/v1/ai/train/", { method: "POST", body: JSON.stringify({}) });
      setStats(data.training);
      const quality = getModelQuality(data.training);
      if (quality.level === "critical") {
        addLog({ type: "error", text: `critical model accuracy after retraining: RMSE=${data.training?.rmse}, MAE=${data.training?.mae}` });
      }
      const epochs = data.training?.epoch_logs || [];
      epochs.forEach((epoch, index) => {
        window.setTimeout(() => {
          setTrainingEpochs((current) => [...current, epoch]);
          addLog({
            type: "python",
            text: `[epoch ${epoch.epoch}] RMSE=${epoch.rmse} MAE=${epoch.mae} ${epoch.message || ""}`.trim()
          });
          if (index === epochs.length - 1) {
            setIsTraining(false);
            setMessage("Навчання моделі завершено.");
          }
        }, index * 120);
      });
      if (!epochs.length) {
        setIsTraining(false);
        setMessage("Навчання моделі завершено.");
      }
    } catch {
      setIsTraining(false);
    }
  }

  async function getRecommendations() {
    const data = await api("/api/v1/ai/recommendations/", { method: "POST", body: JSON.stringify({ top_k: 5 }) });
    setRecommendations(data.recommendations || []);
    setExplanation(data.explanation || "");
    setMessage(data.mode === "svd" ? "SVD-рекомендації оновлено." : "Показано холодний старт.");
  }

  return (
    <div className="min-h-screen bg-zinc-950 pb-8 text-slate-100">
      <div className="flex min-h-screen">
        <aside className="hidden w-72 shrink-0 border-r border-zinc-800 bg-zinc-950/95 p-5 lg:block">
          <div className="flex items-center gap-3">
            <div className="grid h-11 w-11 place-items-center rounded-lg border border-emerald-400/40 bg-emerald-400/10">
              <Library className="h-6 w-6 text-emerald-300" />
            </div>
            <div>
              <h1 className="text-lg font-semibold">SmartLibraryAI</h1>
              <p className="text-sm text-slate-400">Університетська бібліотека</p>
            </div>
          </div>

          <div className="mt-8 space-y-2">
            {tabs.map((tab) => {
              const Icon = tab.icon;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex w-full items-center gap-3 rounded-lg px-3 py-3 text-left transition ${
                    activeTab === tab.id
                      ? "border border-emerald-400/30 bg-emerald-400/10 text-emerald-100"
                      : "border border-transparent text-slate-300 hover:bg-zinc-900"
                  }`}
                >
                  <Icon className="h-5 w-5" />
                  <span>{tab.label}</span>
                </button>
              );
            })}
          </div>

          <div className="mt-8 rounded-lg border border-zinc-800 bg-zinc-900 p-4">
            <p className="text-sm text-slate-400">Поточний читач</p>
            <p className="mt-1 font-medium">{user ? user.email : "Гість"}</p>
            <p className="text-sm text-slate-500">{user?.profile ? `${user.profile.first_name} ${user.profile.last_name}` : "Сесія не активна"}</p>
            {user && (
              <div className="mt-4 rounded-lg border border-zinc-700 bg-zinc-950 p-3 text-sm">
                <p className="font-medium text-emerald-200">{isAdmin ? "Роль: адміністратор" : isLibrarian ? "Роль: бібліотекар" : "Роль: читач"}</p>
                <p className="mt-1 text-slate-400">
                  {isAdmin
                    ? "Адміністратор контролює точність ШІ та запускає примусове перенавчання."
                    : isLibrarian
                    ? "Бібліотекар керує формулярами та каталогом."
                    : "Читач бере книги, повертає їх і ставить одну оцінку кожній книзі."}
                </p>
              </div>
            )}
            {user && (
              <button onClick={logout} className="mt-4 flex w-full items-center justify-center gap-2 rounded-lg bg-zinc-800 px-3 py-2 text-sm hover:bg-zinc-700">
                <LogOut className="h-4 w-4" /> Вийти
              </button>
            )}
          </div>
        </aside>

        <main className="flex-1 px-4 py-5 sm:px-6 lg:px-8">
          <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="text-sm uppercase tracking-[0.18em] text-emerald-300">PostgreSQL 15 + Django REST + SVD</p>
              <h2 className="mt-1 text-2xl font-semibold text-white">{tabs.find((tab) => tab.id === activeTab)?.label}</h2>
            </div>
            {message && <div className="rounded-lg border border-zinc-700 bg-zinc-900 px-4 py-2 text-sm text-slate-200">{message}</div>}
          </div>

          <div className="mb-5 grid grid-cols-2 gap-2 lg:hidden">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`rounded-lg border px-3 py-2 text-sm ${activeTab === tab.id ? "border-emerald-400 bg-emerald-400/10" : "border-zinc-800 bg-zinc-900"}`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {activeTab === "catalog" && (
            <section className="space-y-4">
              <div className="flex flex-col gap-3 rounded-lg border border-zinc-800 bg-zinc-900 p-4 md:flex-row">
                <div className="relative flex-1">
                  <Search className="pointer-events-none absolute left-3 top-3 h-5 w-5 text-slate-500" />
                  <input
                    value={search}
                    onChange={(event) => setSearch(event.target.value)}
                    className="h-11 w-full rounded-lg border border-zinc-700 bg-zinc-950 pl-10 pr-3 outline-none focus:border-emerald-400"
                    placeholder="Назва або ISBN"
                  />
                </div>
                <select
                  value={selectedGenre}
                  onChange={(event) => setSelectedGenre(event.target.value)}
                  className="h-11 rounded-lg border border-zinc-700 bg-zinc-950 px-3 outline-none focus:border-emerald-400"
                >
                  <option value="">Усі жанри</option>
                  {genres.map((genre) => <option key={genre.genre_id} value={genre.genre_id}>{genre.name}</option>)}
                </select>
                <button onClick={() => loadCatalog()} className="flex h-11 items-center justify-center gap-2 rounded-lg bg-emerald-500 px-5 font-medium text-zinc-950 hover:bg-emerald-400">
                  <Search className="h-5 w-5" /> Знайти
                </button>
              </div>

              <div className="grid gap-3 xl:grid-cols-2">
                {books.map((book) => (
                  <article key={book.book_id} className="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <h3 className="text-lg font-semibold text-white">{book.title}</h3>
                        <p className="mt-1 text-sm text-slate-400">{book.genre_name || "Без жанру"} · {book.publication_year || "рік не вказано"}</p>
                        <p className="mt-2 text-sm text-slate-500">ISBN {book.isbn}</p>
                        {ratings[book.book_id] && (
                          <p className="mt-2 inline-flex items-center gap-2 rounded-lg border border-amber-300/30 bg-amber-300/10 px-2 py-1 text-sm text-amber-200">
                            <Star className="h-4 w-4 fill-amber-300" /> Ваша оцінка: {ratings[book.book_id]}/5
                          </p>
                        )}
                      </div>
                      <span className="rounded-lg border border-zinc-700 px-3 py-1 text-sm">{book.available_copies}/{book.total_copies}</span>
                    </div>
                    <div className="mt-4 flex flex-wrap gap-2">
                      <button onClick={() => viewBook(book.book_id)} className="rounded-lg border border-zinc-700 px-3 py-2 text-sm hover:bg-zinc-800">MARC21</button>
                      <button disabled={!isReader || book.available_copies < 1} onClick={() => borrowBook(book.book_id)} className="flex items-center gap-2 rounded-lg bg-sky-500 px-3 py-2 text-sm font-medium text-zinc-950 disabled:cursor-not-allowed disabled:bg-zinc-700 disabled:text-slate-400">
                        <Send className="h-4 w-4" /> Видати
                      </button>
                      {[1, 2, 3, 4, 5].map((value) => (
                        <button key={value} disabled={!isReader || Boolean(ratings[book.book_id])} onClick={() => rateBook(book.book_id, value)} className={`grid h-9 w-9 place-items-center rounded-lg border hover:border-amber-300 disabled:cursor-not-allowed disabled:opacity-45 ${ratings[book.book_id] >= value ? "border-amber-300 bg-amber-300/10" : "border-zinc-700"}`} title={ratings[book.book_id] ? `Ваша оцінка ${ratings[book.book_id]}` : `Оцінка ${value}`}>
                          <Star className={`h-4 w-4 text-amber-300 ${ratings[book.book_id] >= value ? "fill-amber-300" : ""}`} />
                        </button>
                      ))}
                    </div>
                  </article>
                ))}
              </div>
            </section>
          )}

          {activeTab === "loans" && (
            <section className="space-y-4">
              <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-zinc-800 bg-zinc-900 p-4">
                <div>
                  <h3 className="font-semibold text-white">{isLibrarian ? "Активні формуляри видачі" : "Мої активні видачі"}</h3>
                  <p className="mt-1 text-sm text-slate-400">
                    {isLibrarian
                      ? "Боржники автоматично маркуються, якщо due_date минув, а return_date порожній."
                      : "Тут показано книги, які ви ще не повернули."}
                  </p>
                </div>
                <button onClick={loadLoans} className="flex items-center gap-2 rounded-lg bg-zinc-800 px-4 py-2 hover:bg-zinc-700">
                  <RefreshCw className="h-4 w-4" /> Оновити
                </button>
              </div>

              {isLibrarian ? (
                <div className="overflow-hidden rounded-lg border border-zinc-800 bg-zinc-900">
                  <div className="overflow-x-auto">
                    <table className="min-w-full text-left text-sm">
                      <thead className="border-b border-zinc-800 bg-zinc-950 text-xs uppercase text-slate-400">
                        <tr>
                          <th className="px-4 py-3">Формуляр</th>
                          <th className="px-4 py-3">Читач</th>
                          <th className="px-4 py-3">Книга</th>
                          <th className="px-4 py-3">Видано</th>
                          <th className="px-4 py-3">Повернути до</th>
                          <th className="px-4 py-3">Статус</th>
                          <th className="px-4 py-3 text-right">Дія</th>
                        </tr>
                      </thead>
                      <tbody>
                        {loans.map((loan) => {
                          const isDebtor = loan.is_debtor || (!loan.return_date && new Date(loan.due_date) < new Date(new Date().toDateString()));
                          return (
                            <tr key={loan.loan_id} className={`border-b border-zinc-800 last:border-0 ${isDebtor ? "bg-red-950/70 text-red-50" : "bg-zinc-900"}`}>
                              <td className="px-4 py-3 font-medium">#{loan.loan_id}</td>
                              <td className="px-4 py-3">
                                <div className="font-medium">{loan.reader?.first_name || ""} {loan.reader?.last_name || ""}</div>
                                <div className={isDebtor ? "text-red-200" : "text-slate-400"}>{loan.reader?.email || `ID ${loan.user_id}`}</div>
                              </td>
                              <td className="px-4 py-3">
                                <div className="font-medium">{loan.book?.title || `Книга #${loan.book_id}`}</div>
                                <div className={isDebtor ? "text-red-200" : "text-slate-400"}>{loan.book?.isbn || "ISBN не вказано"}</div>
                              </td>
                              <td className="px-4 py-3">{loan.borrow_date}</td>
                              <td className="px-4 py-3">{loan.due_date}</td>
                              <td className="px-4 py-3">
                                <span className={`inline-flex rounded-lg px-2 py-1 text-xs font-semibold ${isDebtor ? "bg-red-500 text-white" : "bg-emerald-400/10 text-emerald-200"}`}>
                                  {isDebtor ? "Боржник" : "Активний"}
                                </span>
                              </td>
                              <td className="px-4 py-3 text-right">
                                <button onClick={() => returnBook(loan.loan_id)} className="inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-500 px-3 py-2 font-medium text-zinc-950 hover:bg-emerald-400">
                                  <RotateCcw className="h-4 w-4" /> Прийняти книгу
                                </button>
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                  {!loans.length && <div className="p-6 text-slate-400">Активних формулярів немає.</div>}
                </div>
              ) : (
                <div className="grid gap-3">
                  {loans.map((loan) => (
                    <div key={loan.loan_id} className={`flex flex-col justify-between gap-3 rounded-lg border p-4 md:flex-row md:items-center ${loan.is_debtor ? "border-red-500 bg-red-950/70" : "border-zinc-800 bg-zinc-900"}`}>
                      <div>
                        <h3 className="font-semibold">{loan.book?.title || `Книга #${loan.book_id}`}</h3>
                        <p className="text-sm text-slate-400">До {loan.due_date} · {loan.is_debtor ? "Боржник" : loan.status}</p>
                      </div>
                      <button onClick={() => returnBook(loan.loan_id)} className="flex items-center justify-center gap-2 rounded-lg bg-emerald-500 px-4 py-2 font-medium text-zinc-950 hover:bg-emerald-400">
                        <RotateCcw className="h-4 w-4" /> Повернути
                      </button>
                    </div>
                  ))}
                  {!loans.length && <div className="rounded-lg border border-zinc-800 bg-zinc-900 p-6 text-slate-400">Активних видач немає.</div>}
                </div>
              )}
            </section>
          )}

          {activeTab === "ai" && (
            <section className="space-y-4">
              <div className="flex flex-wrap gap-3">
                <button disabled={!isAdmin || isTraining} onClick={trainModel} className="flex items-center gap-2 rounded-lg bg-fuchsia-500 px-4 py-2 font-medium text-white disabled:cursor-not-allowed disabled:bg-zinc-700">
                  <Brain className={`h-5 w-5 ${isTraining ? "animate-pulse" : ""}`} /> Примусово перенавчити SVD
                </button>
                <button disabled={!user} onClick={getRecommendations} className="flex items-center gap-2 rounded-lg bg-emerald-500 px-4 py-2 font-medium text-zinc-950 disabled:bg-zinc-700 disabled:text-slate-400">
                  <CheckCircle2 className="h-5 w-5" /> Отримати поради
                </button>
              </div>
              <div className="rounded-lg border border-zinc-800 bg-zinc-900 p-4 text-sm text-slate-300">
                {isAdmin
                  ? "Адміністративна панель ШІ активна: доступні метрики точності, контроль RMSE/MAE та повний цикл перенавчання моделі."
                  : isLibrarian
                  ? "Бібліотекар бачить рекомендаційний модуль, але навчання моделі обмежене роллю адміністратора."
                  : "Читач бачить персональні рекомендації на основі власних оцінок. Навчання моделі приховане від читача."}
              </div>
              {isAdmin && <ModelQualityAlert quality={modelQuality} stats={stats} />}
              {isAdmin && (
                <div className="grid gap-4 xl:grid-cols-[360px_1fr]">
                  <div className="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <h3 className="font-semibold text-white">Точність моделі</h3>
                        <p className="mt-1 text-sm text-slate-400">Графічні шкали похибок Surprise SVD.</p>
                      </div>
                      <Database className="h-5 w-5 text-emerald-300" />
                    </div>
                    <div className="mt-5 space-y-5">
                      <MetricBar label="RMSE" value={stats?.rmse} max={5} tone="emerald" />
                      <MetricBar label="MAE" value={stats?.mae} max={5} tone="sky" />
                    </div>
                    <div className="mt-5 border-t border-zinc-800 pt-4 text-sm text-slate-400">
                      <p>Версія: {stats?.version || "немає"}</p>
                      <p>Файл ваг: {stats?.weights_path || "не створено"}</p>
                    </div>
                  </div>
                  <EpochTrainingPanel epochs={trainingEpochs} isTraining={isTraining} />
                </div>
              )}
              <div className="grid gap-4 xl:grid-cols-[1fr_360px]">
                <div className="grid gap-3">
                  {recommendations.map((item) => (
                    <div key={item.book_id} className="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
                      <div className="flex items-start justify-between gap-3">
                        <div>
                          <h3 className="font-semibold">{item.title}</h3>
                          <p className="mt-1 text-sm text-slate-400">{item.genre || "Жанр не вказано"} · прогноз {item.predicted_score}</p>
                        </div>
                        <Database className="h-5 w-5 text-emerald-300" />
                      </div>
                    </div>
                  ))}
                  {!recommendations.length && <div className="rounded-lg border border-zinc-800 bg-zinc-900 p-6 text-slate-400">Рекомендації ще не запитані.</div>}
                </div>
                <div className="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
                  <h3 className="font-semibold">Пояснення Gemini</h3>
                  <p className="mt-3 text-sm leading-6 text-slate-300">{explanation || "Після запиту тут з'явиться пояснення українською."}</p>
                  <div className="mt-5 border-t border-zinc-800 pt-4 text-sm text-slate-400">
                    <p>Версія: {stats?.version || "немає"}</p>
                    <p>RMSE: {stats?.rmse ?? "немає"}</p>
                    <p>MAE: {stats?.mae ?? "немає"}</p>
                  </div>
                </div>
              </div>
            </section>
          )}

          {activeTab === "profile" && (
            <section className="grid gap-4 lg:grid-cols-[420px_1fr]">
              <form onSubmit={submitAuth} className="rounded-lg border border-zinc-800 bg-zinc-900 p-5">
                <div className="mb-4 flex gap-2">
                  <button type="button" onClick={() => setAuthMode("login")} className={`flex flex-1 items-center justify-center gap-2 rounded-lg px-3 py-2 ${authMode === "login" ? "bg-emerald-500 text-zinc-950" : "bg-zinc-800"}`}>
                    <LogIn className="h-4 w-4" /> Вхід
                  </button>
                  <button type="button" onClick={() => setAuthMode("register")} className={`flex flex-1 items-center justify-center gap-2 rounded-lg px-3 py-2 ${authMode === "register" ? "bg-emerald-500 text-zinc-950" : "bg-zinc-800"}`}>
                    <UserPlus className="h-4 w-4" /> Реєстрація
                  </button>
                </div>
                <Field label="Email" value={authForm.email} onChange={(value) => setAuthForm({ ...authForm, email: value })} />
                <Field label="Пароль" type="password" value={authForm.password} onChange={(value) => setAuthForm({ ...authForm, password: value })} />
                {authMode === "register" && (
                  <>
                    <Field label="Ім'я" value={authForm.first_name} onChange={(value) => setAuthForm({ ...authForm, first_name: value })} />
                    <Field label="Прізвище" value={authForm.last_name} onChange={(value) => setAuthForm({ ...authForm, last_name: value })} />
                    <Field label="Телефон" value={authForm.phone} onChange={(value) => setAuthForm({ ...authForm, phone: value })} />
                  </>
                )}
                <button className="mt-4 w-full rounded-lg bg-emerald-500 px-4 py-3 font-medium text-zinc-950 hover:bg-emerald-400">
                  {authMode === "login" ? "Увійти" : "Створити профіль"}
                </button>
              </form>
              <div className="rounded-lg border border-zinc-800 bg-zinc-900 p-5">
                <h3 className="text-lg font-semibold">Дані сесії</h3>
                <pre className="mt-4 overflow-auto rounded-lg bg-zinc-950 p-4 text-sm text-emerald-200">{JSON.stringify(user, null, 2) || "null"}</pre>
              </div>
            </section>
          )}
        </main>
      </div>

      <DevTerminal logs={devLogs} />

      {selectedBook && (
        <div className="fixed inset-0 z-40 grid place-items-center bg-black/70 p-4">
          <div className="max-h-[82vh] w-full max-w-3xl overflow-hidden rounded-lg border border-zinc-700 bg-zinc-950 shadow-2xl">
            <div className="flex items-center justify-between border-b border-zinc-800 px-5 py-4">
              <div>
                <h3 className="text-lg font-semibold text-white">{selectedBook.title}</h3>
                <p className="text-sm text-slate-400">MARC21 · ISBN {selectedBook.isbn}</p>
              </div>
              <button onClick={() => setSelectedBook(null)} className="grid h-9 w-9 place-items-center rounded-lg border border-zinc-700 hover:bg-zinc-800">
                <X className="h-5 w-5" />
              </button>
            </div>
            <div className="max-h-[64vh] overflow-auto p-5">
              <div className="mb-4 grid gap-3 md:grid-cols-3">
                <div className="rounded-lg border border-zinc-800 bg-zinc-900 p-3">
                  <p className="text-xs text-slate-500">Жанр</p>
                  <p className="mt-1 text-sm">{selectedBook.genre_name || "Не вказано"}</p>
                </div>
                <div className="rounded-lg border border-zinc-800 bg-zinc-900 p-3">
                  <p className="text-xs text-slate-500">Видавництво</p>
                  <p className="mt-1 text-sm">{selectedBook.publisher || "Не вказано"}</p>
                </div>
                <div className="rounded-lg border border-zinc-800 bg-zinc-900 p-3">
                  <p className="text-xs text-slate-500">Примірники</p>
                  <p className="mt-1 text-sm">{selectedBook.available_copies}/{selectedBook.total_copies}</p>
                </div>
              </div>
              <pre className="overflow-auto rounded-lg border border-zinc-800 bg-black p-4 text-sm leading-6 text-emerald-200">
                {JSON.stringify(selectedBook.marc21_raw, null, 2)}
              </pre>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}

function MetricBar({ label, value, max, tone }) {
  const numericValue = Number(value ?? 0);
  const width = Math.min(100, Math.max(0, (numericValue / max) * 100));
  const color = tone === "sky" ? "bg-sky-400" : "bg-emerald-400";
  return (
    <div>
      <div className="mb-2 flex items-center justify-between text-sm">
        <span className="font-medium text-slate-200">{label}</span>
        <span className="font-mono text-slate-300">{value ?? "немає"}</span>
      </div>
      <div className="h-3 overflow-hidden rounded-lg bg-zinc-950 ring-1 ring-zinc-800">
        <div className={`h-full rounded-lg ${color}`} style={{ width: `${width}%` }} />
      </div>
      <div className="mt-1 flex justify-between text-xs text-slate-500">
        <span>0</span>
        <span>{max}</span>
      </div>
    </div>
  );
}

function getModelQuality(stats) {
  if (!stats) {
    return {
      level: "unknown",
      title: "Метрики моделі ще не розраховані",
      message: "Запустіть примусове перенавчання SVD, щоб отримати RMSE та MAE."
    };
  }
  const rmse = Number(stats.rmse ?? 0);
  const mae = Number(stats.mae ?? 0);
  if (rmse >= MODEL_ERROR_THRESHOLDS.criticalRmse || mae >= MODEL_ERROR_THRESHOLDS.criticalMae) {
    return {
      level: "critical",
      title: "Критичний рівень похибки моделі",
      message: `RMSE або MAE перевищили допустимий поріг. Потрібно перевірити якість оцінок і запустити повторне навчання. Пороги: RMSE < ${MODEL_ERROR_THRESHOLDS.criticalRmse}, MAE < ${MODEL_ERROR_THRESHOLDS.criticalMae}.`
    };
  }
  if (rmse >= MODEL_ERROR_THRESHOLDS.warningRmse || mae >= MODEL_ERROR_THRESHOLDS.warningMae) {
    return {
      level: "warning",
      title: "Підвищений рівень похибки",
      message: "Модель працює, але точність варто проконтролювати після додавання нових оцінок читачів."
    };
  }
  return {
    level: "ok",
    title: "Похибка моделі в нормі",
    message: "RMSE та MAE перебувають нижче контрольних порогів."
  };
}

function ModelQualityAlert({ quality, stats }) {
  const styles = {
    critical: "border-red-500/60 bg-red-950/60 text-red-50",
    warning: "border-amber-400/60 bg-amber-950/40 text-amber-50",
    ok: "border-emerald-400/40 bg-emerald-950/30 text-emerald-50",
    unknown: "border-zinc-700 bg-zinc-900 text-slate-200"
  };
  return (
    <div className={`flex flex-col gap-3 rounded-lg border p-4 sm:flex-row sm:items-center sm:justify-between ${styles[quality.level]}`}>
      <div className="flex items-start gap-3">
        <AlertTriangle className="mt-0.5 h-5 w-5 shrink-0" />
        <div>
          <h3 className="font-semibold">{quality.title}</h3>
          <p className="mt-1 text-sm opacity-90">{quality.message}</p>
        </div>
      </div>
      <div className="shrink-0 rounded-lg border border-current/20 px-3 py-2 font-mono text-sm">
        RMSE={stats?.rmse ?? "..."} · MAE={stats?.mae ?? "..."}
      </div>
    </div>
  );
}

function EpochTrainingPanel({ epochs, isTraining }) {
  const last = epochs[epochs.length - 1];
  return (
    <div className="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h3 className="font-semibold text-white">Лог епох градієнтного спуску</h3>
          <p className="mt-1 text-sm text-slate-400">Покрокова динаміка зменшення RMSE та MAE.</p>
        </div>
        <span className={`rounded-lg px-2 py-1 text-xs font-semibold ${isTraining ? "bg-fuchsia-500 text-white" : "bg-zinc-800 text-slate-300"}`}>
          {isTraining ? "навчання" : "очікування"}
        </span>
      </div>
      <div className="mt-4 h-64 overflow-auto rounded-lg border border-zinc-800 bg-black p-3 font-mono text-xs leading-6 text-emerald-200">
        {epochs.map((epoch) => (
          <div key={epoch.epoch}>
            epoch {String(epoch.epoch).padStart(2, "0")} | RMSE={epoch.rmse} | MAE={epoch.mae} | {epoch.message}
          </div>
        ))}
        {!epochs.length && <div className="text-slate-500">Натисніть "Примусово перенавчити SVD", щоб побачити live-лог епох.</div>}
      </div>
      <div className="mt-4 grid gap-3 text-sm sm:grid-cols-2">
        <div className="rounded-lg border border-zinc-800 bg-zinc-950 p-3">
          <p className="text-slate-500">Останній RMSE</p>
          <p className="mt-1 font-mono text-lg text-white">{last?.rmse ?? "..."}</p>
        </div>
        <div className="rounded-lg border border-zinc-800 bg-zinc-950 p-3">
          <p className="text-slate-500">Останній MAE</p>
          <p className="mt-1 font-mono text-lg text-white">{last?.mae ?? "..."}</p>
        </div>
      </div>
    </div>
  );
}

function DevTerminal({ logs }) {
  const colorByType = {
    api: "text-sky-300",
    sql: "text-amber-200",
    python: "text-emerald-200",
    error: "text-red-300",
    system: "text-slate-300"
  };
  return (
    <section className="mx-4 mt-2 rounded-lg border border-zinc-800 bg-black p-4 sm:mx-6 lg:mx-8">
      <div className="mb-3 flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Terminal className="h-4 w-4 text-emerald-300" />
          <h3 className="text-sm font-semibold text-white">Термінал логів розробника</h3>
        </div>
        <span className="rounded-lg border border-zinc-800 px-2 py-1 text-xs text-slate-400">PostgreSQL + Django + Surprise</span>
      </div>
      <div className="h-48 overflow-auto rounded-lg border border-zinc-900 bg-zinc-950 p-3 font-mono text-xs leading-6">
        {logs.map((log, index) => (
          <div key={`${log.time}-${index}`} className={colorByType[log.type] || "text-slate-300"}>
            [{log.time}] {log.type.toUpperCase()} {log.text}
          </div>
        ))}
        {!logs.length && <div className="text-slate-500">Очікування дій користувача: вхід, пошук, видача, оцінювання або навчання ШІ.</div>}
      </div>
    </section>
  );
}

function Field({ label, value, onChange, type = "text" }) {
  return (
    <label className="mt-3 block">
      <span className="text-sm text-slate-400">{label}</span>
      <input
        type={type}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="mt-1 h-11 w-full rounded-lg border border-zinc-700 bg-zinc-950 px-3 outline-none focus:border-emerald-400"
      />
    </label>
  );
}

export default App;
