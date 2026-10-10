import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BiodataApp());
}

const kGreen = Color(0xFF0B8457);

class BiodataApp extends StatelessWidget {
  const BiodataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biodata Form',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kGreen),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: kGreen, width: 2),
          ),
        ),
      ),
      home: const RegistrationPage(),
    );
  }
}

class SubjectEntry {
  final TextEditingController name = TextEditingController();
  TimeOfDay? start;
  TimeOfDay? end;
}

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _detailsKey = GlobalKey<FormState>();
  final _subjectsKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _section = TextEditingController();
  final _course = TextEditingController();
  final List<SubjectEntry> _subjects = [SubjectEntry()];
  int _step = 0;
  bool _saving = false;

  static const _labels = ['Details', 'Subjects', 'Review'];

  Future<void> _pickTime(SubjectEntry s, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? s.start : s.end) ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => isStart ? s.start = picked : s.end = picked);
  }

  String _fmt(TimeOfDay? t) => t == null ? '' : t.format(context);

  // 24-hour "HH:mm" string for storing in Firestore.
  String _hhmm(TimeOfDay? t) => t == null
      ? ''
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _next() {
    if (_step == 0 && !_detailsKey.currentState!.validate()) return;
    if (_step == 1) {
      final ok = _subjectsKey.currentState!.validate();
      final timesOk = _subjects.every((s) => s.start != null && s.end != null);
      if (!ok || !timesOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pls complete all subjects and times')),
        );
        return;
      }
    }
    setState(() => _step++);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('students').add({
        'name': _name.text.trim(),
        'section': _section.text.trim(),
        'course': _course.text.trim(),
        'subjects': [
          for (final s in _subjects)
            {
              'subject': s.name.text.trim(),
              'startTime': _hhmm(s.start),
              'endTime': _hhmm(s.end),
            }
        ],
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Information saved successfully')),
      );
      // Reset the form for the next entry.
      setState(() {
        _name.clear();
        _section.clear();
        _course.clear();
        _subjects
          ..clear()
          ..add(SubjectEntry());
        _step = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreen,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text('Create Your Profile',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 16),
                      _indicator(),
                      const SizedBox(height: 20),
                      if (_step == 0) _detailsStep(),
                      if (_step == 1) _subjectsStep(),
                      if (_step == 2) _reviewStep(),
                      const SizedBox(height: 16),
                      _buttons(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _indicator() => Row(
        children: List.generate(3, (i) {
          final active = i <= _step;
          return Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: active ? kGreen : Colors.grey.shade300,
                  child: Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 12, color: active ? Colors.white : Colors.black54)),
                ),
                const SizedBox(height: 4),
                Text(_labels[i],
                    style: TextStyle(
                        fontSize: 12,
                        color: active ? kGreen : Colors.grey,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }),
      );

  Widget _header(String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text(sub, style: const TextStyle(color: Colors.black54)),
          const Divider(height: 24),
        ],
      );

  Widget _field(TextEditingController c, String label, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: c,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: kGreen),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Pls input $label' : null,
        ),
      );

  Widget _detailsStep() => Form(
        key: _detailsKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('USER REGISTRATION', 'Enter your registration details.'),
            const Text('Personal details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Text('Tell us a little about your enrollment.',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            _field(_name, 'Name', Icons.person_outline),
            _field(_section, 'Section', Icons.groups),
            _field(_course, 'Course', Icons.school_outlined),
          ],
        ),
      );

  Widget _timeField(String label, IconData icon, TimeOfDay? value, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: value == null ? null : label,
              prefixIcon: Icon(icon, color: kGreen),
              suffixIcon: const Icon(Icons.access_time),
            ),
            child: Text(value == null ? label : _fmt(value),
                style: TextStyle(color: value == null ? Colors.black54 : Colors.black87)),
          ),
        ),
      );

  Widget _subjectsStep() => Form(
        key: _subjectsKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('SUBJECT ENROLLMENT', 'Add subjects and their class times.'),
            const Text('Your subjects',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Text('Add a subject and set its class schedule.',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            for (int i = 0; i < _subjects.length; i++) _subjectCard(i),
            OutlinedButton.icon(
              onPressed: () => setState(() => _subjects.add(SubjectEntry())),
              icon: const Icon(Icons.add),
              label: const Text('Add another subject'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            ),
          ],
        ),
      );

  Widget _subjectCard(int i) {
    final s = _subjects[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade400),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                    radius: 14,
                    backgroundColor: kGreen.withOpacity(0.12),
                    child: Text('${i + 1}', style: const TextStyle(color: kGreen))),
                const SizedBox(width: 10),
                Text('Subject ${i + 1}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _subjects.length > 1
                      ? () => setState(() => _subjects.removeAt(i))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _field(s.name, 'Subject', Icons.menu_book),
            _timeField('Start Time', Icons.play_circle_outline, s.start,
                () => _pickTime(s, true)),
            _timeField('End Time', Icons.flag_outlined, s.end, () => _pickTime(s, false)),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(IconData icon, String label, String value) => ListTile(
        leading: Icon(icon, color: kGreen),
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  Widget _reviewStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header('VERIFICATION', 'Review your details before saving.'),
          const Text('Review your details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Text('Make sure everything looks right before saving.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.grey.shade50,
            child: Column(children: [
              _reviewRow(Icons.person_outline, 'Name', _name.text),
              _reviewRow(Icons.groups, 'Section', _section.text),
              _reviewRow(Icons.school_outlined, 'Course', _course.text),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('Class schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final s in _subjects)
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              child: ListTile(
                leading: const Icon(Icons.menu_book, color: kGreen),
                title: Text(s.name.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${_fmt(s.start)} – ${_fmt(s.end)}'),
              ),
            ),
        ],
      );

  Widget _buttons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _step > 0
              ? TextButton.icon(
                  onPressed: () => setState(() => _step--),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'))
              : const SizedBox(),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: _saving ? null : (_step == 2 ? _save : _next),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_step == 0 ? 'Next' : _step == 1 ? 'Review' : 'Save'),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 18),
                  ]),
          ),
        ],
      );
}
