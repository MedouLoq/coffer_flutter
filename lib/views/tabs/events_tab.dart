import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../controllers/vault_controller.dart';
import '../../services/crypto_service.dart';
import '../../services/db_service.dart';

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab>
    with AutomaticKeepAliveClientMixin {
  final VaultController vaultController = Get.find<VaultController>();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // ✅ événements chargés depuis DB (groupés par jour)
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};

  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadEventsFromDb();
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadEventsFromDb() async {
    try {
      if (mounted) setState(() => _loading = true);

      final rows = await DBService.query('events', orderBy: 'event_date ASC');

      _events.clear();

      for (final row in rows) {
        final dateStr = row['event_date']?.toString();
        if (dateStr == null || dateStr.isEmpty) continue;

        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;

        Map<String, dynamic> event;

        final encryptedData = row['data']?.toString();
        if (encryptedData != null && encryptedData.isNotEmpty) {
          if (vaultController.encryptionKey == null) continue;

          final jsonText = await CryptoService.decryptText(
            encryptedData,
            vaultController.encryptionKey!,
          );
          event = jsonDecode(jsonText) as Map<String, dynamic>;
        } else {
          event = {
            'id': row['id'],
            'title': row['title'] ?? 'Sans titre',
            'description': row['description'],
            'time': row['time'] ?? '00:00',
            'date': date.toIso8601String(),
          };
        }

        event['id'] ??= row['id'];
        event['date'] ??= date.toIso8601String();

        final key = _dayKey(date);
        _events.putIfAbsent(key, () => []);
        _events[key]!.add(event);
      }

      if (mounted) setState(() {});
    } catch (e) {
      Get.snackbar(
        '❌ Erreur',
        'Impossible de charger les événements: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = _dayKey(day);
    return _events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),

          // Calendrier
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_selectedDay == null
                    ? _buildNoDateSelected()
                    : _buildEventsList(_getEventsForDay(_selectedDay!))),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _selectedDay == null
                  ? 'Événements'
                  : 'Événements du ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _loadEventsFromDb,
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
            onPressed: _addEvent,
            tooltip: 'Ajouter',
          ),
        ],
      ),
    );
  }

  // ✅ FIX OVERFLOW: scrollable si hauteur petite
  Widget _buildNoDateSelected() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 200),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 20),
              Text(
                'Sélectionnez une date',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _addEvent,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un événement'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventsList(List<Map<String, dynamic>> events) {
    if (events.isEmpty) {
      // ✅ FIX OVERFLOW: scrollable
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 200),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 20),
                Text(
                  'Aucun événement ce jour',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _addEvent,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un événement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEventsFromDb,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (context, index) => _buildEventCard(events[index]),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.event, color: Colors.blue, size: 28),
        ),
        title: Text(
          (event['title'] ?? 'Sans titre').toString(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  (event['time'] ?? '00:00').toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            if (event['description'] != null &&
                event['description'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                event['description'].toString(),
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showEventActions(event),
        ),
      ),
    );
  }

  void _addEvent() {
    if (_selectedDay == null) {
      Get.snackbar(
        'Date requise',
        'Veuillez sélectionner une date',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    if (vaultController.encryptionKey == null) {
      Get.snackbar(
        'Coffre verrouillé',
        'Déverrouillez le coffre pour ajouter un événement',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final titleController = TextEditingController();
    final descController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    Get.dialog(
      AlertDialog(
        title: const Text('Nouvel événement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setInner) {
                  return ListTile(
                    title: const Text('Heure'),
                    trailing: Text(selectedTime.format(context)),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) setInner(() => selectedTime = time);
                    },
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;

              final day = DateTime(
                _selectedDay!.year,
                _selectedDay!.month,
                _selectedDay!.day,
              );

              // Prepare the event data object
              final eventData = {
                'title': titleController.text.trim(),
                'description': descController.text.trim(),
                'time': selectedTime.format(context),
              };

              try {
                // 👇 USE THE CONTROLLER METHOD INSTEAD OF DBService.insert
                // This automatically handles user_id and sync_status
                final success = await vaultController.addEvent(
                  eventDate: day,
                  eventData: eventData,
                );

                if (success) {
                  Get.back();
                  Get.snackbar(
                    '✅ Événement ajouté',
                    titleController.text.trim(),
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                  await _loadEventsFromDb();
                }
              } catch (e) {
                Get.snackbar(
                  '❌ Erreur',
                  'Impossible d\'ajouter: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showEventActions(Map<String, dynamic> event) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (event['title'] ?? '').toString(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Modifier'),
              onTap: () {
                Get.back();
                Get.snackbar('Modifier', 'Fonctionnalité à venir');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer'),
              onTap: () async {
                Get.back();
                final id = event['id'];
                if (id is! int) {
                  Get.snackbar(
                    'Erreur',
                    'ID événement invalide',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                  return;
                }

                await DBService.delete('events',
                    where: 'id = ?', whereArgs: [id]);

                Get.snackbar(
                  '✅ Supprimé',
                  'Événement supprimé',
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );

                await _loadEventsFromDb();
              },
            ),
          ],
        ),
      ),
    );
  }
}
