# 🎬 FlickNest 

A beautiful, offline-first movie and TV show explorer app built with Flutter. Browse trending titles, create custom lists, and manage your watchlist—all without requiring sign-in or cloud services.

![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.9.2+-0175C2?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)
![License](https://img.shields.io/badge/License-MIT-green)

---

## ✨ Features

### 🎯 Core Features
- **Offline-First**: All data stored locally on your device
- **No Sign-In Required**: Use the app without creating an account
- **Beautiful UI**: Material 3 design with 9 brand color themes
- **Dark & Light Mode**: System-aware theme switching

### 🎬 Movie & TV Browsing
- Browse trending movies and TV shows
- Search across movies, TV shows, and people
- Advanced filters: year range, genres, ratings, languages, countries
- Discover by genre
- View detailed information, cast, crew, trailers, and recommendations

### 📚 Personal Lists
- **3 Default Lists**: Favorites, Watchlist, Watched
- **Custom Lists**: Create unlimited custom lists with:
  - Custom names, descriptions, icons, and colors
  - Filter by Movie-only, TV-only, or Both
  - Advanced search, sort, and filter within lists
- **Selection Mode**: Multi-select and batch operations

### 👤 Profile
- Local profile with custom name, avatar, and cover photo
- Camera or gallery image picker support

### 🔍 Search & Discovery
- Multi-tab search (All, Movies, TV, People)
- Filter by type, year, genres, languages, countries, ratings
- Sort by relevance, popularity, or release date
- Recent search history

---

## 📸 Screenshots

> Add your screenshots here

---

## 🛠️ Tech Stack

- **Framework**: Flutter 3.9.2+
- **Language**: Dart 3.9.2+
- **State Management**: ChangeNotifier (built-in)
- **Local Storage**: SharedPreferences
- **HTTP Client**: Dio
- **Image Caching**: cached_network_image
- **Fonts**: Google Fonts (Inter, Quicksand)
- **API**: The Movie Database (TMDB)

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.9.2 or higher
- Android Studio / VS Code
- Android SDK (API 21+)
- TMDB API Key ([Get it here](https://www.themoviedb.org/settings/api))

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/miqdad23/flicknest.git
   cd flicknest