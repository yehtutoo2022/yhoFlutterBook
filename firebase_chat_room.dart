import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';

/// ! We use riverpod to watch the current logged-in user.
/// ! e.g. final user = ref.watch(_currentUserProvider).valueOrNull;
final _currentUserProvider =
    StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

// NOTE: to add firebase support, first go to firebase console, generate the
// firebase json file, and add configuration lines in the gradle files.
// C.f. this commit: https://github.com/X-Wei/flutter_catalog/commit/48792cbc0de62fc47e0e9ba2cd3718117f4d73d1.
class FirebaseChatroomExample extends ConsumerStatefulWidget {
  const FirebaseChatroomExample({super.key});

  @override
  _FirebaseChatroomExampleState createState() =>
      _FirebaseChatroomExampleState();
}

class _FirebaseChatroomExampleState
    extends ConsumerState<FirebaseChatroomExample> {
  late DatabaseReference _firebaseMsgDbRef;

  final TextEditingController _textController = TextEditingController();
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _firebaseMsgDbRef = FirebaseDatabase.instance
        .ref()
        .child('messages/${now.year}/${now.month}/${now.day}');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(_currentUserProvider).unwrapPrevious().valueOrNull;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.red,
        leading: IconButton(
          icon: const Icon(Icons.info),
          onPressed: () => _showNoteDialog(context),
        ),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            user == null ? 'Chatting' : 'Chatting as "${user.displayName}"',
          ),
        ),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            _buildMessagesList(),
            const Divider(height: 2.0),
            _buildComposeMsgRow()
          ],
        ),
      ),
    );
  }

  void _showNoteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note'),
        content: const Text(
          'This chat room is only for demo purposes.\n\n'
          'The chat messages are publicly available, and they '
          'can be deleted at any time by the firebase admin.\n\n'
          'To send messages, you must log in '
          'in the "Firebase login" demo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  // Builds the list of chat messages.
  Widget _buildMessagesList() {
    return Flexible(
      child: Scrollbar(
        child: FirebaseAnimatedList(
          defaultChild: const Center(child: CircularProgressIndicator()),
          query: _firebaseMsgDbRef,
          sort: (a, b) => b.key!.compareTo(a.key!),
          padding: const EdgeInsets.all(8.0),
          reverse: true,
          itemBuilder: (
            BuildContext ctx,
            DataSnapshot snapshot,
            Animation<double> animation,
            int idx,
          ) =>
              _messageFromSnapshot(snapshot, animation),
        ),
      ),
    );
  }

  // Returns the UI of one message from a data snapshot.
  Widget _messageFromSnapshot(
    DataSnapshot snapshot,
    Animation<double> animation,
  ) {
    final val = snapshot.value;
    if (val == null) {
      return Container();
    }
    final json = val as Map;
    final senderName = json['senderName'] as String? ?? '?? <unknown>';
    final msgText = json['text'] as String? ?? '??';
    final sentTime = json['timestamp'] as int? ?? 0;
    final senderPhotoUrl = json['senderPhotoUrl'] as String?;
    final messageUI = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: senderPhotoUrl != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(senderPhotoUrl),
                  )
                : CircleAvatar(
                    child: senderName.isEmpty ? null : Text(senderName[0]),
                  ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(senderName,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  DateTime.fromMillisecondsSinceEpoch(sentTime).toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(msgText),
              ],
            ),
          ),
        ],
      ),
    );
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ),
      child: messageUI,
    );
  }

  // Builds the row for composing and sending message.
  Widget _buildComposeMsgRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(color: Theme.of(context).cardColor),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Flexible(
            child: TextField(
              keyboardType: TextInputType.multiline,
              // Setting maxLines=null makes the text field auto-expand when one
              // line is filled up.
              maxLines: null,
              maxLength: 200,
              decoration:
                  const InputDecoration.collapsed(hintText: "Send a message"),
              controller: _textController,
              onChanged: (String text) =>
                  setState(() => _isComposing = text.isNotEmpty),
              onSubmitted: _onTextMsgSubmitted,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _isComposing
                ? () => _onTextMsgSubmitted(_textController.text)
                : null,
          ),
        ],
      ),
    );
  }

  // Triggered when text is submitted (send button pressed).
  Future<void> _onTextMsgSubmitted(String text) async {
    final user = ref.read(_currentUserProvider).unwrapPrevious().valueOrNull;
    if (user == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Login required'),
          content: const Text(
            'To send messages you need to first log in.\n\n'
            'Go to the "Firebase login" example, and log in from there. '
            'You will then be able to send messages.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );
      return;
    }
    // Clear input text field.
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
    // Send message to firebase realtime database.
    _firebaseMsgDbRef.push().set({
      'senderId': user.uid,
      'senderName': user.displayName,
      'senderPhotoUrl': user.photoURL,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    kAnalytics?.logEvent(name: 'send_message');
  }
}

