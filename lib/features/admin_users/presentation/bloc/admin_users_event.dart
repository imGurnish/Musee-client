part of 'admin_users_bloc.dart';

sealed class AdminUsersEvent {}

final class LoadUsers extends AdminUsersEvent {
  final int page;
  final int limit;
  final String? search;
  LoadUsers({this.page = 0, this.limit = 20, this.search});
}

final class CreateUserEvent extends AdminUsersEvent {
  final String name;
  final String email;
  final SubscriptionType subscriptionType;
  final String? planId;
  final List<int>? avatarBytes;
  final String? avatarFilename;
  CreateUserEvent({
    required this.name,
    required this.email,
    this.subscriptionType = SubscriptionType.free,
    this.planId,
    this.avatarBytes,
    this.avatarFilename,
  });
}

final class UpdateUserEvent extends AdminUsersEvent {
  final String id;
  final String? name;
  final String? email;
  final SubscriptionType? subscriptionType;
  final String? planId;
  final List<int>? avatarBytes;
  final String? avatarFilename;
  UpdateUserEvent({
    required this.id,
    this.name,
    this.email,
    this.subscriptionType,
    this.planId,
    this.avatarBytes,
    this.avatarFilename,
  });
}

final class DeleteUserEvent extends AdminUsersEvent {
  final String id;
  DeleteUserEvent(this.id);
}

final class DeleteUsersEvent extends AdminUsersEvent {
  final List<String> ids;
  DeleteUsersEvent(this.ids);
}
