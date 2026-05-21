import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api/api_constants.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  io.Socket? get socket => _socket;

  void connect(String token) {
    if (_socket?.connected == true) return;

    _socket = io.io(
      ApiConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath(ApiConstants.socketPath)
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void joinChannel(int channelId) {
    _socket?.emit('join_channel', {'channelId': channelId});
  }

  void leaveChannel(int channelId) {
    _socket?.emit('leave_channel', {'channelId': channelId});
  }

  void sendMessage({
    required int channelId,
    required String content,
    String type = 'text',
    int? parentId,
  }) {
    _socket?.emit('send_message', {
      'channelId': channelId,
      'content': content,
      'type': type,
      if (parentId != null) 'parentId': parentId,
    });
  }

  void emitTyping(int channelId) {
    _socket?.emit('typing', {'channelId': channelId});
  }

  void emitStopTyping(int channelId) {
    _socket?.emit('stop_typing', {'channelId': channelId});
  }

  void markRead(int channelId) {
    _socket?.emit('mark_read', {'channelId': channelId});
  }

  void on(String event, dynamic Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }
}
