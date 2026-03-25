part of 'admin_artists_bloc.dart';

abstract class AdminArtistsEvent {}

class LoadArtists extends AdminArtistsEvent {
  final int page;
  final int limit;
  final String? search;
  LoadArtists({this.page = 0, this.limit = 20, this.search});
}

class CreateArtistEvent extends AdminArtistsEvent {
  final String? artistId; // Option A
  final String? name; // Option B
  final String? email;
  final String bio; // required
  final List<int>? coverBytes;
  final String? coverFilename;
  final List<int>? avatarBytes;
  final String? avatarFilename;
  final List<String>? genres;
  final int? debutYear;
  final bool? isVerified;
  final Map<String, dynamic>? socialLinks;
  final int? monthlyListeners;
  final String? regionId;
  final DateTime? dateOfBirth;

  CreateArtistEvent({
    this.artistId,
    this.name,
    this.email,
    required this.bio,
    this.coverBytes,
    this.coverFilename,
    this.avatarBytes,
    this.avatarFilename,
    this.genres,
    this.debutYear,
    this.isVerified,
    this.socialLinks,
    this.monthlyListeners,
    this.regionId,
    this.dateOfBirth,
  });
}

class UpdateArtistEvent extends AdminArtistsEvent {
  final String id;
  final String? bio;
  final String? coverUrl;
  final List<int>? coverBytes;
  final String? coverFilename;
  final List<String>? genres;
  final int? debutYear;
  final bool? isVerified;
  final Map<String, dynamic>? socialLinks;
  final int? monthlyListeners;
  final String? regionId;
  final DateTime? dateOfBirth;

  UpdateArtistEvent({
    required this.id,
    this.bio,
    this.coverUrl,
    this.coverBytes,
    this.coverFilename,
    this.genres,
    this.debutYear,
    this.isVerified,
    this.socialLinks,
    this.monthlyListeners,
    this.regionId,
    this.dateOfBirth,
  });
}

class DeleteArtistEvent extends AdminArtistsEvent {
  final String id;
  DeleteArtistEvent(this.id);
}
