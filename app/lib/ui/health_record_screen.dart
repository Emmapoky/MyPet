import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/care_entry.dart';
import '../models/pet.dart';
import '../records/pdf_text.dart';
import '../records/vet_record_parser.dart';
import '../state/app_state.dart';
import '../util/day.dart';
import 'feedback.dart';
import 'theme.dart';
import 'widgets/pet_bar.dart';

/// A dated health record against a pet (FR02): vet visit, vaccination, medicine,
/// test results or a procedure. A vet's PDF can fill it in; anything the PDF did not
/// hold is marked so the carer can add it.
class HealthRecordScreen extends StatefulWidget {
  const HealthRecordScreen({super.key, required this.pet, this.editing, this.readPdf = readPdfText, this.pickPdf});
  final Pet pet;
  final CareEntry? editing;

  /// Reads a PDF's text (swapped in tests).
  final Future<String> Function(String path) readPdf;

  /// Picks a PDF and returns its path (swapped in tests).
  final Future<String?> Function()? pickPdf;

  @override
  State<HealthRecordScreen> createState() => _HealthRecordScreenState();
}

class _HealthRecordScreenState extends State<HealthRecordScreen> {
  late final Map<String, dynamic> _d = widget.editing?.data ?? const {};
  late RecordType type = RecordType.values.asNameMap()[_d['type']] ?? RecordType.vetVisit;
  late final title = TextEditingController(text: widget.editing?.title ?? '');
  late final note = TextEditingController(text: widget.editing?.note ?? '');
  late final clinic = TextEditingController(text: _d['clinic'] as String? ?? '');
  late final vet = TextEditingController(text: _d['vet'] as String? ?? '');
  late final weight = TextEditingController(text: (_d['weightKg'] as num?)?.toString() ?? '');
  late final vaccines = TextEditingController(text: (_d['vaccines'] as List?)?.join(', ') ?? '');
  late final medicines = TextEditingController(text: (_d['medicines'] as List?)?.join(', ') ?? '');
  late Day day = widget.editing?.day ?? context.read<AppState>().today;
  late Day? nextDue = _d['nextDue'] == null ? null : Day.parse(_d['nextDue'] as String);
  late String? source = _d['source'] as String?;

  /// Fields the PDF did not hold, shown in amber until filled.
  Set<String> missing = {};
  String? pdfName, otherPet, problem;
  bool reading = false;

  Future<void> _import() async {
    Feel.tap();
    final String? path;
    if (widget.pickPdf != null) {
      path = await widget.pickPdf!();
    } else {
      final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      path = picked.isEmpty ? null : picked.first.path;
    }
    if (path == null) return;
    final file = path;
    setState(() {
      reading = true;
      problem = null;
    });
    try {
      final text = await widget.readPdf(file);
      if (text.trim().length < 20) {
        setState(() => problem = "This PDF is a scan, so its words can't be read. Fill in the fields below.");
        return;
      }
      final r = parseVetRecord(text);
      setState(() {
        type = r.type;
        title.text = r.title;
        if (r.date != null) day = Day.of(r.date!);
        if (r.nextDue != null) nextDue = Day.of(r.nextDue!);
        clinic.text = r.clinic ?? '';
        vet.text = r.vet ?? '';
        if (r.weightKg != null) weight.text = r.weightKg!.toString();
        vaccines.text = r.vaccines.join(', ');
        medicines.text = r.medicines.join(', ');
        if (r.notes != null) note.text = r.notes!;
        missing = r.missing.toSet();
        pdfName = file.split('/').last;
        source = 'pdf';
        final name = r.petName;
        otherPet = name != null && name.toLowerCase() != widget.pet.name.toLowerCase() ? name : null;
      });
      Feel.saved();
    } catch (_) {
      setState(() => problem = "Couldn't open that PDF. Try another, or fill in the fields below.");
    } finally {
      if (mounted) setState(() => reading = false);
    }
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) return;
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    List<String> list(TextEditingController c) =>
        c.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    final w = double.tryParse(weight.text.trim().replaceAll(',', '.'));
    final data = {
      'title': title.text.trim(),
      'type': type.name,
      if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      if (clinic.text.trim().isNotEmpty) 'clinic': clinic.text.trim(),
      if (vet.text.trim().isNotEmpty) 'vet': vet.text.trim(),
      if (w != null && w > 0 && w < 120) 'weightKg': w,
      if (list(vaccines).isNotEmpty) 'vaccines': list(vaccines),
      if (list(medicines).isNotEmpty) 'medicines': list(medicines),
      if (nextDue != null) 'nextDue': nextDue.toString(),
      'source': ?source,
    };
    if (widget.editing != null) {
      await s.editEntry(widget.editing!, data, day: day);
    } else {
      await s.addEntry(widget.pet.id, EntryKind.healthRecord, data, day: day);
    }
    Feel.saved();
    nav.pop();
  }

  InputDecoration _deco(BuildContext context, String label, String key, {String? hint}) {
    final c = MyPetColors.of(context);
    final miss = missing.contains(key);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusInput),
      borderSide: BorderSide(color: c.changeEdge, width: 2),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: miss ? 'Not in the PDF' : null,
      helperStyle: miss ? TextStyle(color: c.onChangeContainer) : null,
      enabledBorder: miss ? border : null,
      fillColor: miss ? c.changeContainer : null,
    );
  }

  Widget _dateRow(String label, Day? value, String key, ValueChanged<Day?> set, {bool clearable = false}) {
    final miss = missing.contains(key);
    final c = MyPetColors.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Tokens.space2),
      shape: miss
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusInput), side: BorderSide(color: c.changeEdge, width: 2))
          : null,
      tileColor: miss ? c.changeContainer : null,
      title: Text(label),
      subtitle: Text(value == null ? (miss ? 'Not in the PDF' : 'Not set') : DateFormat('d MMMM y').format(value.asDateTime)),
      trailing: clearable && value != null
          ? IconButton(tooltip: 'Clear', icon: const Icon(Icons.clear), onPressed: () => setState(() => set(null)))
          : const Icon(Icons.calendar_today_outlined),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(DateTime.now().year + 5),
          initialDate: (value ?? day).asDateTime,
        );
        if (d != null) {
          setState(() {
            set(Day.of(d));
            missing.remove(key);
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = MyPetColors.of(context);
    const gap = SizedBox(height: Tokens.space4);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          PetAvatar(pet: widget.pet, size: 36),
          const SizedBox(width: Tokens.space3),
          Flexible(child: Text(widget.editing == null ? 'Health record' : 'Edit record', overflow: TextOverflow.ellipsis)),
        ]),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Tokens.space4), children: [
          // Fill from a vet's PDF.
          OutlinedButton.icon(
            onPressed: reading ? null : _import,
            icon: reading
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded),
            label: Text(pdfName == null ? 'Fill from a vet PDF' : 'Use another PDF'),
          ),
          if (pdfName != null || problem != null) ...[
            const SizedBox(height: Tokens.space3),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(Tokens.space3),
                decoration: BoxDecoration(
                  color: problem != null || missing.isNotEmpty ? c.changeContainer : c.loggedContainer,
                  borderRadius: BorderRadius.circular(Tokens.radiusInput),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(problem != null || missing.isNotEmpty ? Icons.edit_note_rounded : Icons.check_circle_rounded,
                      color: problem != null || missing.isNotEmpty ? c.onChangeContainer : c.onLoggedContainer),
                  const SizedBox(width: Tokens.space2),
                  Expanded(
                    child: Text(
                      problem ??
                          [
                            'Filled from $pdfName.',
                            if (missing.isNotEmpty) 'Please add: ${missing.join(', ')}.',
                            if (otherPet != null) 'This PDF says $otherPet, not ${widget.pet.name}.',
                          ].join(' '),
                      style: t.textTheme.bodyMedium,
                    ),
                  ),
                ]),
              ),
            ),
          ],
          gap,
          DropdownMenu<RecordType>(
            initialSelection: type,
            key: ValueKey(type),
            expandedInsets: EdgeInsets.zero,
            label: const Text('Type'),
            inputDecorationTheme: missing.contains('Type')
                ? InputDecorationTheme(
                    filled: true,
                    fillColor: c.changeContainer,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Tokens.radiusInput),
                      borderSide: BorderSide(color: c.changeEdge, width: 2),
                    ),
                  )
                : null,
            dropdownMenuEntries: [
              for (final e in recordTypeNames.entries) DropdownMenuEntry(value: e.key, label: e.value),
            ],
            onSelected: (v) => setState(() {
              if (v != null) type = v;
              missing.remove('Type');
              if (title.text.isEmpty || recordTypeNames.values.contains(title.text)) {
                title.text = recordTypeNames[type]!;
              }
            }),
          ),
          gap,
          TextField(
            controller: title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'What happened', hintText: 'Vet visit, vaccination, medicine given'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Tokens.space3),
          _dateRow('Date', day, 'Date', (d) => day = d ?? day),
          const SizedBox(height: Tokens.space3),
          TextField(
            controller: clinic,
            textCapitalization: TextCapitalization.words,
            decoration: _deco(context, 'Clinic', 'Clinic'),
            onChanged: (_) => setState(() => missing.remove('Clinic')),
          ),
          const SizedBox(height: Tokens.space3),
          TextField(
            controller: vet,
            textCapitalization: TextCapitalization.words,
            decoration: _deco(context, 'Vet (optional)', 'Vet'),
          ),
          if (type == RecordType.vaccination) ...[
            const SizedBox(height: Tokens.space3),
            TextField(
              controller: vaccines,
              decoration: _deco(context, 'Vaccines', 'Vaccines', hint: 'Rabies, DHPP'),
              onChanged: (_) => setState(() => missing.remove('Vaccines')),
            ),
          ],
          if (type == RecordType.medicine) ...[
            const SizedBox(height: Tokens.space3),
            TextField(
              controller: medicines,
              decoration: _deco(context, 'Medicines', 'Medicines', hint: 'Name and dose'),
              onChanged: (_) => setState(() => missing.remove('Medicines')),
            ),
          ],
          const SizedBox(height: Tokens.space3),
          TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _deco(context, 'Weight in kg (optional)', 'Weight'),
          ),
          if (type == RecordType.vaccination || type == RecordType.vetVisit || nextDue != null) ...[
            const SizedBox(height: Tokens.space3),
            _dateRow(type == RecordType.vaccination ? 'Next due' : 'Recheck', nextDue, 'Next', (d) => nextDue = d,
                clearable: true),
          ],
          const SizedBox(height: Tokens.space3),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: FilledButton(
            onPressed: title.text.trim().isEmpty ? null : _save,
            child: const Text('Save'),
          ),
        ),
      ),
    );
  }
}
