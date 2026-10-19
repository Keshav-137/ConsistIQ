import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GmailMessage {
  final String id;
  final String subject;
  final String sender;
  final String snippet;

  const GmailMessage({
    required this.id,
    required this.subject,
    required this.sender,
    required this.snippet,
  });
}

class GmailService {
  GmailService._();

  static const serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const _gmailMetadataScope =
      'https://www.googleapis.com/auth/gmail.metadata';
  static Future<void>? _initialization;

  static bool get isConfigured => serverClientId.isNotEmpty;

  static Future<void> _initialize() {
    if (!isConfigured) {
      throw StateError(
        'Google sign-in is not configured. Set GOOGLE_SERVER_CLIENT_ID when building the app.',
      );
    }
    return _initialization ??= GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
    );
  }

  static Future<GoogleSignInAccount> signIn() async {
    await _initialize();
    return GoogleSignIn.instance.authenticate();
  }

  static Future<void> signOut() async {
    await _initialize();
    await GoogleSignIn.instance.signOut();
  }

  static Future<List<GmailMessage>> readRecentInbox(
      GoogleSignInAccount account) async {
    final authorization =
        await account.authorizationClient.authorizeScopes(
      const [_gmailMetadataScope],
    );
    final headers = {
      'Authorization': 'Bearer ${authorization.accessToken}',
      'Accept': 'application/json',
    };
    final listResponse = await http
        .get(
          Uri.https(
            'gmail.googleapis.com',
            '/gmail/v1/users/me/messages',
            {'maxResults': '20', 'labelIds': 'INBOX'},
          ),
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));
    if (listResponse.statusCode != 200) {
      throw StateError(
        'Gmail could not list recent messages (HTTP ${listResponse.statusCode}).',
      );
    }
    final listed = jsonDecode(listResponse.body) as Map<String, dynamic>;
    final items = (listed['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .take(20)
        .toList();

    return Future.wait(items.map((item) async {
      final id = item['id'] as String;
      final uri = Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/$id'
        '?format=metadata&metadataHeaders=Subject&metadataHeaders=From',
      );
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError(
          'Gmail could not read a selected message (HTTP ${response.statusCode}).',
        );
      }
      final message = jsonDecode(response.body) as Map<String, dynamic>;
      final payload = message['payload'] as Map<String, dynamic>? ?? const {};
      final messageHeaders =
          payload['headers'] as List<dynamic>? ?? const [];
      String header(String name) {
        for (final raw in messageHeaders) {
          if (raw is Map<String, dynamic> &&
              (raw['name'] as String?)?.toLowerCase() == name.toLowerCase()) {
            return (raw['value'] as String?) ?? '';
          }
        }
        return '';
      }

      return GmailMessage(
        id: id,
        subject: header('Subject').trim().isEmpty
            ? '(No subject)'
            : header('Subject').trim(),
        sender: header('From'),
        snippet: (message['snippet'] as String?) ?? '',
      );
    }));
  }
}
