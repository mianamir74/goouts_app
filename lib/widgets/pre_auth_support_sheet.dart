import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'goouts_sheet.dart';

/// Standalone pre-authentication support bottom sheet.
/// Used on Login and Signup screens — no uid required.
/// Writes directly to support_requests with preAuthTicket: true.
void showPreAuthSupportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PreAuthSupportSheet(),
  );
}

class _PreAuthSupportSheet extends StatefulWidget {
  const _PreAuthSupportSheet();

  @override
  State<_PreAuthSupportSheet> createState() => _PreAuthSupportSheetState();
}

class _PreAuthSupportSheetState extends State<_PreAuthSupportSheet> {
  static const Color _blue  = Color(0xFF0392CA);
  static const Color _dark  = Color(0xFF0D1B3E);
  static const Color _grey  = Color(0xFF6B7280);
  static const Color _bg    = Color(0xFFF0F6FA);
  static const Color _border = Color(0xFFD1E9F6);

  static const List<Map<String, String>> _topics = [
    {'value': 'otp_not_received',   'label': "Didn't receive OTP"},
    {'value': 'wrong_number',       'label': 'Wrong phone number used'},
    {'value': 'account_locked',     'label': 'Account locked or suspended'},
    {'value': 'cant_create',        'label': "Can't create an account"},
    {'value': 'other',              'label': 'Something else'},
  ];

  String? _selectedTopic;
  bool    _submitting = false;
  bool    _submitted  = false;

  final _nameCtrl    = TextEditingController();
  final _contactCtrl = TextEditingController(); // email or phone
  final _msgCtrl     = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedTopic == null) {
      GoOutsSheet.warning(context,
        title: 'Topic Required',
        message: 'Please select a topic.',
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    final topicLabel = _topics
        .firstWhere((t) => t['value'] == _selectedTopic)['label'] ?? '';

    try {
      final ref     = FirebaseFirestore.instance.collection('support_requests').doc();
      final shortId = ref.id.substring(0, 8).toUpperCase();

      await ref.set({
        'uid':                '',
        'preAuthTicket':      true,
        'fullName':           _nameCtrl.text.trim(),
        'firstName':          _nameCtrl.text.trim().split(' ').first,
        'surname':            _nameCtrl.text.trim().contains(' ')
                                  ? _nameCtrl.text.trim().substring(
                                      _nameCtrl.text.trim().indexOf(' ') + 1)
                                  : '',
        'email':              _contactCtrl.text.trim().contains('@')
                                  ? _contactCtrl.text.trim() : '',
        'mobileNumber':       !_contactCtrl.text.trim().contains('@')
                                  ? _contactCtrl.text.trim() : '',
        'accountType':        'user',
        'sourceCollection':   'users',
        'category':           _selectedTopic,
        'categoryLabel':      topicLabel,
        'subTopic':           '',
        'subject':            'Pre-login: $topicLabel',
        'message':            _msgCtrl.text.trim(),
        'status':             'new',
        'priority':           _selectedTopic == 'account_locked' ? 'high' : 'medium',
        'ticketNumber':       'SR-$shortId',
        'lastMessage':        _msgCtrl.text.trim(),
        'lastMessageAt':      FieldValue.serverTimestamp(),
        'lastMessageBy':      'user',
        'unreadByAdmin':      true,
        'unreadByUser':       false,
        'adminReply':         '',
        'adminRepliedBy':     '',
        'rating':             0,
        'ratingComment':      '',
        'ratingLabel':        '',
        'selfServiceAttempted': false,
        'createdAt':          FieldValue.serverTimestamp(),
        'updatedAt':          FieldValue.serverTimestamp(),
      });

      await ref.collection('messages').add({
        'sender':     'user',
        'senderType': 'user',
        'senderName': _nameCtrl.text.trim(),
        'text':       _msgCtrl.text.trim(),
        'imageUrl':   '',
        'isRead':     false,
        'createdAt':  FieldValue.serverTimestamp(),
      });

      if (mounted) setState(() { _submitting = false; _submitted = true; });
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        GoOutsSheet.error(context,
          title: 'Send Failed',
          message: 'Failed to send. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: _submitted ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildSuccess() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 12),
      Container(
        width: 56, height: 56,
        decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7), shape: BoxShape.circle),
        child: const Icon(Icons.check_circle_rounded,
            color: Color(0xFF16A34A), size: 30),
      ),
      const SizedBox(height: 14),
      Text('Message Sent',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
      const SizedBox(height: 8),
      Text("Our support team will get back to you shortly.",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: _grey, height: 1.5)),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity, height: 48,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue, elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
          child: Text('Done',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    ],
  );

  Widget _buildForm() => Form(
    key: _formKey,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),

          // Header
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: _bg, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.support_agent_rounded,
                  color: _blue, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need help signing in?',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w800, color: _dark)),
                Text('We\'ll get back to you quickly.',
                    style: GoogleFonts.inter(fontSize: 12, color: _grey)),
              ],
            )),
          ]),
          const SizedBox(height: 16),

          // Topic chips
          Text('What\'s the issue?',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _topics.map((t) {
              final bool sel = _selectedTopic == t['value'];
              return GestureDetector(
                onTap: () => setState(() => _selectedTopic = t['value']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _blue.withOpacity(0.08) : _bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? _blue : _border,
                        width: sel ? 1.5 : 1.0),
                  ),
                  child: Text(t['label']!,
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: sel ? _blue : _dark)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Name
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: _inputDec('Your name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 10),

          // Email or phone
          TextFormField(
            controller: _contactCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDec('Email or phone number'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Contact detail is required' : null,
          ),
          const SizedBox(height: 10),

          // Message
          TextFormField(
            controller: _msgCtrl,
            maxLines: 4,
            decoration: _inputDec('Describe your issue...'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Please describe your issue' : null,
          ),
          const SizedBox(height: 16),

          // Submit
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue, elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Send Message',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),
        ],
      ),
    ),
  );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
    filled: true,
    fillColor: _bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _blue, width: 1.4)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.4)),
  );
}
