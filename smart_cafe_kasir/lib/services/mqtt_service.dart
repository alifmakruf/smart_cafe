import 'dart:convert';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  late MqttServerClient client;

  // ========================================
  // HIVEMQ CLOUD CONFIGURATION (TLS Port 8883)
  // ========================================
  final String broker = 'aa76b3bfe96d48c7b7203acbc3c437ed.s1.eu.hivemq.cloud';
  final int port = 8883; // ← TLS port (BUKAN 8884!)
  final String username = 'Admin';
  final String password = 'Admin123';
  final String clientId = 'FlutterKasir_${DateTime.now().millisecondsSinceEpoch}';

  // Topics
  final String topicTableStatus = 'warungkopi/table/+/status';
  final String topicTableRelay = 'warungkopi/table/+/relay';
  final String topicTableLed = 'warungkopi/table/+/led';
  final String topicKitchen = 'warungkopi/kitchen/#';
  final String topicKasir = 'warungkopi/kasir/#';

  // Callbacks
  Function(Map<String, dynamic>)? onTableStatus;
  Function(Map<String, dynamic>)? onRelayStatus;
  Function(Map<String, dynamic>)? onKitchenData;
  Function(String)? onConnectionStatus;

  bool get isConnected => client.connectionStatus?.state == MqttConnectionState.connected;

  // ========================================
  // CONNECT (Pattern dari teman kamu)
  // ========================================
  Future<bool> connect() async {
    client = MqttServerClient.withPort(broker, clientId, port);

    // ✅ CRITICAL: TLS configuration (SIMPLE!)
    client.secure = true;
    client.securityContext = SecurityContext.defaultContext;
    client.keepAlivePeriod = 60;
    client.logging(on: true);

    // Set callbacks
    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;
    client.onSubscribed = _onSubscribed;

    // Connection message
    final connMessage = MqttConnectMessage()
        .authenticateAs(username, password)
        .withWillTopic('warungkopi/status')
        .withWillMessage('Flutter dashboard disconnected')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      print('\n========================================');
      print('📡 Connecting to HiveMQ Cloud (TLS)');
      print('Broker: $broker:$port');
      print('Client ID: $clientId');
      print('========================================');

      await client.connect();

      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        print('\n✅✅✅ Connected to HiveMQ! ✅✅✅');
        print('========================================\n');

        // Subscribe to topics
        _subscribeToTopics();

        // Listen to messages
        client.updates!.listen(_onMessage);

        return true;
      }
    } catch (e) {
      print('\n❌ Connection failed: $e');
      print('========================================\n');
      client.disconnect();
    }

    return false;
  }

  // ========================================
  // SUBSCRIBE TO TOPICS
  // ========================================
  void _subscribeToTopics() {
    print('📩 Subscribing to topics...');

    client.subscribe(topicTableStatus, MqttQos.atLeastOnce);
    client.subscribe(topicTableRelay, MqttQos.atLeastOnce);
    client.subscribe(topicTableLed, MqttQos.atLeastOnce);
    client.subscribe(topicKitchen, MqttQos.atLeastOnce);
    client.subscribe(topicKasir, MqttQos.atLeastOnce);

    print('✅ Subscribed to all topics');
  }

  // ========================================
  // CALLBACKS
  // ========================================
  void _onConnected() {
    print('✅ MQTT Connected callback');
    onConnectionStatus?.call('Connected');
  }

  void _onDisconnected() {
    print('❌ MQTT Disconnected callback');
    onConnectionStatus?.call('Disconnected');
  }

  void _onSubscribed(String topic) {
    print('✅ Subscribed: $topic');
  }

  // ========================================
  // MESSAGE HANDLER
  // ========================================
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> event) {
    final recMess = event[0].payload as MqttPublishMessage;
    final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    final topic = event[0].topic;

    print('\n📥 MQTT Message Received:');
    print('  Topic: $topic');
    print('  Payload: $payload');

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      data['topic'] = topic;

      // Route to appropriate callback
      if (topic.contains('/status') && onTableStatus != null) {
        onTableStatus!(data);
      } else if (topic.contains('/relay') && onRelayStatus != null) {
        onRelayStatus!(data);
      } else if (topic.contains('kitchen') && onKitchenData != null) {
        onKitchenData!(data);
      }
    } catch (e) {
      print('❌ Error parsing message: $e');
    }
  }

  // ========================================
  // PUBLISH HELPERS
  // ========================================
  void publish(String topic, Map<String, dynamic> message) {
    if (!isConnected) {
      print('⚠️  Not connected to MQTT');
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(message));

    client.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    print('\n📤 MQTT Published:');
    print('  Topic: $topic');
    print('  Payload: ${jsonEncode(message)}');
  }

  // Publish specific events
  void publishCardLinked(String cardUid, int orderId, int tableId) {
    publish('warungkopi/kasir/card_linked', {
      'card_uid': cardUid,
      'order_id': orderId,
      'table_id': tableId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void publishOrderStatus(int orderId, int tableId, String status) {
    String topic = 'warungkopi/kitchen/preparing';

    if (status == 'ready') {
      topic = 'warungkopi/kitchen/ready';
    } else if (status == 'completed') {
      topic = 'warungkopi/kitchen/completed';
    }

    publish(topic, {
      'order_id': orderId,
      'table_id': tableId,
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void publishLedControl(int tableId, bool preparing, bool ready) {
    publish('warungkopi/table/$tableId/led', {
      'preparing': preparing,
      'ready': ready,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ========================================
  // DISCONNECT
  // ========================================
  void disconnect() {
    if (isConnected) {
      client.disconnect();
      print('✅ MQTT Disconnected');
    }
  }
}