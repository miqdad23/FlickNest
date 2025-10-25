# Changelog

All notable changes to FlickNest will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.0] - 2025-01-XX

### Added
- 🎉 Initial release of FlickNest
- ✨ Offline-first architecture with local storage
- 🎬 Browse trending, popular, top-rated movies & TV shows
- 🔍 Advanced search with multi-tab interface (All, Movies, TV, People)
- 📚 Default lists: Favorites, Watchlist, Watched
- 📁 Custom lists with:
  - Custom names, descriptions, icons, and colors
  - Filter by Movie/TV/Both
  - Advanced search, sort, and filter within lists
  - Multi-select and batch operations
- 👤 Local profile management with avatar and cover photo
- 🎨 9 brand color themes (Purple, Orange, Blue, Green, Red, Teal, Cyan, Indigo, Pink)
- 🌓 Dark & light mode support
- 📖 Detailed movie/TV pages with:
  - Cast, crew, trailers
  - Recommendations
  - Image galleries
  - Seasons & episodes (TV)
  - Personal ratings & notes
- 🔐 No sign-in required

### Technical
- Flutter 3.9.2+
- Material 3 design system
- TMDB API integration
- Local data persistence with SharedPreferences
- Image caching with cached_network_image
- Google Fonts (Inter, Quicksand)

### Fixed
- Fixed package name typo (flicknes → flicknest)
- Fixed zone mismatch warning in main.dart
- Removed unused dependencies

[1.0.0]: https://github.com/miqdad23/FlickNest/releases/tag/v1.0.0