import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/common/entities/user.dart';
import 'package:musee/features/admin_users/domain/usecases/create_user.dart';
import 'package:musee/features/admin_users/domain/usecases/delete_user.dart';
import 'package:musee/features/admin_users/domain/usecases/delete_users.dart';
import 'package:musee/features/admin_users/domain/usecases/list_users.dart';
import 'package:musee/features/admin_users/domain/usecases/update_user.dart';

part 'admin_users_event.dart';
part 'admin_users_state.dart';

class AdminUsersBloc extends Bloc<AdminUsersEvent, AdminUsersState> {
  final ListUsers _listUsers;
  final CreateUser _createUser;
  final UpdateUser _updateUser;
  final DeleteUser _deleteUser;
  final DeleteUsers _deleteUsers;

  AdminUsersBloc({
    required ListUsers listUsers,
    required CreateUser createUser,
    required UpdateUser updateUser,
    required DeleteUser deleteUser,
     required DeleteUsers deleteUsers,
  }) : _listUsers = listUsers,
       _createUser = createUser,
       _updateUser = updateUser,
       _deleteUser = deleteUser,
       _deleteUsers = deleteUsers,
       super(const AdminUsersInitial()) {
    on<LoadUsers>(_onLoadUsers);
    on<CreateUserEvent>(_onCreateUser);
    on<UpdateUserEvent>(_onUpdateUser);
    on<DeleteUserEvent>(_onDeleteUser);
    on<DeleteUsersEvent>(_onDeleteUsers);
  }

  Future<void> _onLoadUsers(
    LoadUsers event,
    Emitter<AdminUsersState> emit,
  ) async {
    // Preserve pagination/search but show loading
    emit(const AdminUsersLoading());
    final res = await _listUsers(
      ListUsersParams(
        page: event.page,
        limit: event.limit,
        search: event.search,
      ),
    );
    res.fold(
      (failure) => emit(AdminUsersFailure(failure.message)),
      (tuple) => emit(
        AdminUsersPageLoaded(
          items: tuple.$1,
          total: tuple.$2,
          page: tuple.$3,
          limit: tuple.$4,
          search: event.search,
        ),
      ),
    );
  }

  Future<void> _onCreateUser(
    CreateUserEvent event,
    Emitter<AdminUsersState> emit,
  ) async {
    emit(const AdminUsersLoading());
    final res = await _createUser(
      CreateUserParams(
        name: event.name,
        email: event.email,
        subscriptionType: event.subscriptionType,
        planId: event.planId,
        avatarBytes: event.avatarBytes,
        avatarFilename: event.avatarFilename,
      ),
    );
    await res.fold(
      (failure) async => emit(AdminUsersFailure(failure.message)),
      (_) async {
        final stateBefore = state;
        int page = 0, limit = 20;
        String? search;
        if (stateBefore is AdminUsersPageLoaded) {
          page = stateBefore.page;
          limit = stateBefore.limit;
          search = stateBefore.search;
        }
        final reload = await _listUsers(
          ListUsersParams(page: page, limit: limit, search: search),
        );
        reload.fold(
          (f) => emit(AdminUsersFailure(f.message)),
          (tuple) => emit(
            AdminUsersPageLoaded(
              items: tuple.$1,
              total: tuple.$2,
              page: tuple.$3,
              limit: tuple.$4,
              search: search,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onUpdateUser(
    UpdateUserEvent event,
    Emitter<AdminUsersState> emit,
  ) async {
    emit(const AdminUsersLoading());
    final res = await _updateUser(
      UpdateUserParams(
        id: event.id,
        name: event.name,
        email: event.email,
        subscriptionType: event.subscriptionType,
        planId: event.planId,
        avatarBytes: event.avatarBytes,
        avatarFilename: event.avatarFilename,
      ),
    );
    await res.fold(
      (failure) async => emit(AdminUsersFailure(failure.message)),
      (_) async {
        final stateBefore = state;
        int page = 0, limit = 20;
        String? search;
        if (stateBefore is AdminUsersPageLoaded) {
          page = stateBefore.page;
          limit = stateBefore.limit;
          search = stateBefore.search;
        }
        final reload = await _listUsers(
          ListUsersParams(page: page, limit: limit, search: search),
        );
        reload.fold(
          (f) => emit(AdminUsersFailure(f.message)),
          (tuple) => emit(
            AdminUsersPageLoaded(
              items: tuple.$1,
              total: tuple.$2,
              page: tuple.$3,
              limit: tuple.$4,
              search: search,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onDeleteUser(
    DeleteUserEvent event,
    Emitter<AdminUsersState> emit,
  ) async {
    emit(const AdminUsersLoading());
    final res = await _deleteUser(event.id);
    await res.fold(
      (failure) async => emit(AdminUsersFailure(failure.message)),
      (_) async {
        final stateBefore = state;
        int page = 0, limit = 20;
        String? search;
        if (stateBefore is AdminUsersPageLoaded) {
          page = stateBefore.page;
          limit = stateBefore.limit;
          search = stateBefore.search;
        }
        final reload = await _listUsers(
          ListUsersParams(page: page, limit: limit, search: search),
        );
        reload.fold(
          (f) => emit(AdminUsersFailure(f.message)),
          (tuple) => emit(
            AdminUsersPageLoaded(
              items: tuple.$1,
              total: tuple.$2,
              page: tuple.$3,
              limit: tuple.$4,
              search: search,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onDeleteUsers(
    DeleteUsersEvent event,
    Emitter<AdminUsersState> emit,
  ) async {
    emit(const AdminUsersLoading());
    final res = await _deleteUsers(event.ids);
    await res.fold(
      (failure) async => emit(AdminUsersFailure(failure.message)),
      (_) async {
        final stateBefore = state;
        int page = 0, limit = 20;
        String? search;
        if (stateBefore is AdminUsersPageLoaded) {
          page = stateBefore.page;
          limit = stateBefore.limit;
          search = stateBefore.search;
        }
        final reload = await _listUsers(
          ListUsersParams(page: page, limit: limit, search: search),
        );
        reload.fold(
          (f) => emit(AdminUsersFailure(f.message)),
          (tuple) => emit(
            AdminUsersPageLoaded(
              items: tuple.$1,
              total: tuple.$2,
              page: tuple.$3,
              limit: tuple.$4,
              search: search,
            ),
          ),
        );
      },
    );
  }
}
