import 'package:equatable/equatable.dart';

/// User profile and authentication entity.
class UserModel extends Equatable {
  final int id;
  final String username;
  final String displayName;
  final int coins;
  final String gender;
  final String bio;

  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.coins = 0,
    this.gender = '',
    this.bio = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['username'] as String? ?? '',
      coins: json['coins'] is int ? json['coins'] as int : int.tryParse('${json['coins']}') ?? 0,
      gender: json['gender'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'coins': coins,
      'gender': gender,
      'bio': bio,
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? displayName,
    int? coins,
    String? gender,
    String? bio,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      coins: coins ?? this.coins,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
    );
  }

  @override
  List<Object?> get props => [id, username, displayName, coins, gender, bio];
}

/// Authentication response containing JWT token and user entity.
class AuthResponse extends Equatable {
  final String accessToken;
  final String tokenType;
  final UserModel user;

  const AuthResponse({
    required this.accessToken,
    this.tokenType = 'bearer',
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final token = json['access_token'] as String? ?? '';
    final tokenType = json['token_type'] as String? ?? 'bearer';
    final userMap = json['user'] as Map<String, dynamic>? ?? json;
    return AuthResponse(
      accessToken: token,
      tokenType: tokenType,
      user: UserModel.fromJson(userMap),
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'token_type': tokenType,
    'user': user.toJson(),
  };

  @override
  List<Object?> get props => [accessToken, tokenType, user];
}

/// Extended profile model representing /api/users/{id}/profile and /api/auth/me.
class UserProfile extends UserModel {
  final bool online;
  final String? lastSeenAt;
  final int totalPlayed;
  final int totalWins;
  final int totalLosses;
  final String? topGame;
  final List<dynamic> stats;

  const UserProfile({
    required super.id,
    required super.username,
    required super.displayName,
    super.coins = 0,
    super.gender = '',
    super.bio = '',
    this.online = false,
    this.lastSeenAt,
    this.totalPlayed = 0,
    this.totalWins = 0,
    this.totalLosses = 0,
    this.topGame,
    this.stats = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['username'] as String? ?? '',
      coins: json['coins'] is int ? json['coins'] as int : int.tryParse('${json['coins']}') ?? 0,
      gender: json['gender'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      online: json['online'] as bool? ?? false,
      lastSeenAt: json['last_seen_at'] as String?,
      totalPlayed: json['total_played'] is int
          ? json['total_played'] as int
          : int.tryParse('${json['total_played']}') ?? 0,
      totalWins: json['total_wins'] is int
          ? json['total_wins'] as int
          : int.tryParse('${json['total_wins']}') ?? 0,
      totalLosses: json['total_losses'] is int
          ? json['total_losses'] as int
          : int.tryParse('${json['total_losses']}') ?? 0,
      topGame: json['top_game'] as String?,
      stats: json['stats'] as List<dynamic>? ?? const [],
    );
  }

  UserModel toUserModel() => this;

  @override
  List<Object?> get props => [
    ...super.props,
    online,
    lastSeenAt,
    totalPlayed,
    totalWins,
    totalLosses,
    topGame,
    stats,
  ];
}
