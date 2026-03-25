part of 'admin_playlist_detail_bloc.dart';

abstract class AdminPlaylistDetailState {
  const AdminPlaylistDetailState();
}

class AdminPlaylistDetailInitial extends AdminPlaylistDetailState {
  const AdminPlaylistDetailInitial();
}

class AdminPlaylistDetailLoading extends AdminPlaylistDetailState {
  const AdminPlaylistDetailLoading();
}

class AdminPlaylistDetailLoaded extends AdminPlaylistDetailState {
  static const Object _unset = Object();

  final Playlist playlist;
  final List<TrackSearchModel> searchResults;
  final int searchTotal;
  final int searchPage;
  final String? searchQuery;
  final bool isSearching;
  final String? error;
  final bool isAddingTrack;
  final bool isRemovingTrack;

  const AdminPlaylistDetailLoaded({
    required this.playlist,
    this.searchResults = const [],
    this.searchTotal = 0,
    this.searchPage = 0,
    this.searchQuery,
    this.isSearching = false,
    this.error,
    this.isAddingTrack = false,
    this.isRemovingTrack = false,
  });

  AdminPlaylistDetailLoaded copyWith({
    Playlist? playlist,
    List<TrackSearchModel>? searchResults,
    int? searchTotal,
    int? searchPage,
    Object? searchQuery = _unset,
    bool? isSearching,
    Object? error = _unset,
    bool? isAddingTrack,
    bool? isRemovingTrack,
  }) {
    return AdminPlaylistDetailLoaded(
      playlist: playlist ?? this.playlist,
      searchResults: searchResults ?? this.searchResults,
      searchTotal: searchTotal ?? this.searchTotal,
      searchPage: searchPage ?? this.searchPage,
      searchQuery: identical(searchQuery, _unset)
          ? this.searchQuery
          : searchQuery as String?,
      isSearching: isSearching ?? this.isSearching,
      error: identical(error, _unset) ? this.error : error as String?,
      isAddingTrack: isAddingTrack ?? this.isAddingTrack,
      isRemovingTrack: isRemovingTrack ?? this.isRemovingTrack,
    );
  }
}

class AdminPlaylistDetailError extends AdminPlaylistDetailState {
  final String message;

  const AdminPlaylistDetailError(this.message);
}
