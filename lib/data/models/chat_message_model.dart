import 'package:equatable/equatable.dart';

/// In-room chat message.
class ChatMessageModel extends Equatable {
  final String text;
  final String sender;
  final int userId;
  final DateTime timestamp;

  const ChatMessageModel({
    required this.text,
    required this.sender,
    required this.userId,
    required this.timestamp,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      text: json['text'] as String? ?? '',
      sender: json['sender'] as String? ?? 'لاعب',
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse('${json['user_id']}') ?? 0,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'sender': sender,
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [text, sender, userId, timestamp];
}
