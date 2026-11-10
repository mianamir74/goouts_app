// Advance booking request sheet (Level 2). Sends createBookingRequest; the
// venue accepts or declines and the customer gets a notification.
// Added 10 November 2026.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_service.dart';
import 'goouts_sheet.dart';

class BookingRequestSheet extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final List<String> bookingTypes;
  final String bookingUrl;
  final bool takesDeposit;

  const BookingRequestSheet({
    super.key,
    required this.partnerId,
    required this.partnerName,
    this.bookingTypes = const [],
    this.bookingUrl = '',
    this.takesDeposit = false,
  });

  /// Opens the venue's own booking page when there is no GoOuts booking
  /// request option, otherwise shows this sheet.
  static Future<void> open(
    BuildContext context, {
    required String partnerId,
    required String partnerName,
    required bool requests,
    List<String> bookingTypes = const [],
    String bookingUrl = '',
    bool takesDeposit = false,
  }) async {
    if (!requests) {
      final uri = Uri.tryParse(bookingUrl);
      if (uri != null && uri.scheme == 'https') {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: MediaQuery.of(context).size.width >= 900
          ? const BoxConstraints(maxWidth: 560)
          : null,
      builder: (_) => BookingRequestSheet(
        partnerId: partnerId,
        partnerName: partnerName,
        bookingTypes: bookingTypes,
        bookingUrl: bookingUrl,
        takesDeposit: takesDeposit,
      ),
    );
  }

  @override
  State<BookingRequestSheet> createState() => _BookingRequestSheetState();
}

class _BookingRequestSheetState extends State<BookingRequestSheet> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);

  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  int _people = 2;
  late String _type =
      widget.bookingTypes.isNotEmpty ? widget.bookingTypes.first : 'Tables';
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    _name.text = u?.displayName ?? '';
    _phone.text = u?.phoneNumber ?? '';
    UserService().getCurrentUser().then((d) {
      if (!mounted || d == null) return;
      if (_name.text.isEmpty) _name.text = (d['fullName'] ?? '').toString();
      if (_phone.text.isEmpty) _phone.text = (d['phone'] ?? '').toString();
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 89)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  String get _timeText =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _send() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().length < 7) {
      setState(() => _error = 'Please add your name and phone number.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    final ctx = nav.context;
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('createBookingRequest')
          .call(<String, dynamic>{
        'partnerId': widget.partnerId,
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'time': _timeText,
        'partySize': _people,
        'bookingType': _type,
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'notes': _notes.text.trim(),
      }).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      nav.pop();
      if (!ctx.mounted) return;
      GoOutsSheet.success(ctx,
          title: 'Request sent',
          message: '${widget.partnerName} will accept or decline your '
              'request. We will notify you as soon as they reply.');
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'Could not send. Please try again.');
    } catch (_) {
      setState(() => _error = 'Could not send. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _pickTile(IconData icon, String label, VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD5DCE3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(icon, size: 18, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFD5DCE3),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Book at ${widget.partnerName}',
                  style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _primary)),
              const SizedBox(height: 4),
              Text(
                  'Send a request. The venue confirms it, nothing is charged '
                  'by GoOuts.${widget.takesDeposit ? ' The venue may ask for a deposit.' : ''}',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.grey[600], height: 1.4)),
              const SizedBox(height: 16),
              Row(children: [
                _pickTile(Icons.calendar_today_rounded,
                    DateFormat('EEE d MMM').format(_date), _pickDate),
                const SizedBox(width: 10),
                _pickTile(Icons.schedule_rounded, _timeText, _pickTime),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Text('People',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
                const Spacer(),
                IconButton(
                  onPressed:
                      _people > 1 ? () => setState(() => _people--) : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  color: _primary,
                ),
                Text('$_people',
                    style: GoogleFonts.inter(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed:
                      _people < 30 ? () => setState(() => _people++) : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: _primary,
                ),
              ]),
              if (widget.bookingTypes.length > 1) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in widget.bookingTypes)
                      ChoiceChip(
                        label: Text(t),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                        selectedColor: const Color(0xFFD6EEF8),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              TextField(controller: _name, decoration: _dec('Your name')),
              const SizedBox(height: 10),
              TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: _dec('Phone number')),
              const SizedBox(height: 10),
              TextField(
                  controller: _notes,
                  maxLength: 300,
                  decoration: _dec('Notes for the venue (optional)')),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFFDC2626))),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    minimumSize: const Size(0, 50),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Send booking request',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
              if (widget.bookingUrl.isNotEmpty)
                Center(
                  child: TextButton(
                    onPressed: () async {
                      final uri = Uri.tryParse(widget.bookingUrl);
                      if (uri != null && uri.scheme == 'https') {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text("Or book on the venue's own website"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
