import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/routes.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../data/models/task_item.dart';
import '../../services/gmail_service.dart';
import '../tasks/task_editor_screen.dart';

class GmailImportScreen extends StatefulWidget {
  const GmailImportScreen({super.key});

  @override
  State<GmailImportScreen> createState() => _GmailImportScreenState();
}

class _GmailImportScreenState extends State<GmailImportScreen> {
  GoogleSignInAccount? _account;
  List<GmailMessage> _messages = [];
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await GmailService.signIn();
      if (!mounted) return;
      setState(() => _account = account);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _readInbox() async {
    final account = _account;
    if (account == null) return;
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow Gmail metadata access?'),
        content: const Text(
          'ConsistIQ will read the subject, sender, and short preview of up to 20 '
          'recent inbox emails so you can choose which ones to turn into tasks. '
          'Google grants metadata-only access: the app does not request message '
          'body access and cannot send, delete, or change emails. Only email '
          'details you choose to save are copied into tasks on this device. '
          'You can cancel or revoke access in your Google Account settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (allow != true || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await GmailService.readRecentInbox(account);
      if (mounted) setState(() => _messages = messages);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await GmailService.signOut();
      if (mounted) {
        setState(() {
          _account = null;
          _messages = [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return PageShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const SubHeader(title: 'Google account & Gmail'),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Privacy'),
                Text(
                  'Google sign-in is optional. ConsistIQ never asks for or stores '
                  'your Google password. Gmail access is requested separately '
                  'only when you tap “Read recent inbox”, after the access '
                  'access explanation.',
                  style: TextStyle(color: g.subText, fontSize: 13),
                ),
                if (!GmailService.isConfigured) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Google sign-in is not configured for this build. The app '
                    'owner must add the Android app and signing certificate to '
                    'Google Cloud OAuth, enable the Gmail API, complete the '
                    'consent-screen setup, and build with the web client ID. '
                    'Do not put private keys or passwords in the APK.',
                    style: TextStyle(color: AppTheme.amber, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 14),
                if (_account == null)
                  GlassButton(
                    label: 'Continue with Google',
                    icon: Icons.account_circle_rounded,
                    filled: true,
                    onTap: _loading || !GmailService.isConfigured
                        ? null
                        : _signIn,
                  )
                else ...[
                  Text('Signed in as ${_account!.email}',
                      style: TextStyle(
                          color: g.text, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    GlassButton(
                      label: 'Read recent inbox',
                      icon: Icons.mail_outline_rounded,
                      filled: true,
                      onTap: _loading ? null : _readInbox,
                    ),
                    GlassButton(
                      label: 'Sign out',
                      icon: Icons.logout_rounded,
                      onTap: _loading ? null : _signOut,
                    ),
                  ]),
                ],
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: const TextStyle(color: AppTheme.red)),
            ),
          if (_messages.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Choose an email to make a task',
                style: TextStyle(
                    color: g.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final message in _messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassContainer(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message.subject,
                          style: TextStyle(
                              color: g.text, fontWeight: FontWeight.w700)),
                      if (message.sender.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(message.sender,
                              style:
                                  TextStyle(color: g.subText, fontSize: 12)),
                        ),
                      if (message.snippet.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(message.snippet,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(color: g.subText, fontSize: 13)),
                        ),
                      const SizedBox(height: 8),
                      GlassButton(
                        label: 'Create task from this email',
                        icon: Icons.add_task_rounded,
                        compact: true,
                        onTap: () => Navigator.of(context).push(fadeRoute(
                          TaskEditorScreen(
                            kind: TaskKind.task,
                            initialTitle: message.subject,
                            initialNotes: [
                              if (message.sender.isNotEmpty)
                                'From: ${message.sender}',
                              if (message.snippet.isNotEmpty) message.snippet,
                              'Imported from Gmail',
                            ].join('\n\n'),
                          ),
                        )),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
