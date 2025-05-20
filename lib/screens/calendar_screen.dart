import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Define the Event model
class Event {
  final String? id; // Firestore document ID
  final String title;
  final String description;
  final DateTime date; // Date of the event
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  Event({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  @override
  String toString() => title;

  // Convert Event to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date), // Store date as Firestore Timestamp
      'startTimeHour': startTime.hour,
      'startTimeMinute': startTime.minute,
      'endTimeHour': endTime.hour,
      'endTimeMinute': endTime.minute,
    };
  }

  // Create Event from a Firestore DocumentSnapshot
  factory Event.fromMap(Map<String, dynamic> map, String documentId) {
    return Event(
      id: documentId,
      title: map['title'],
      description: map['description'],
      date: (map['date'] as Timestamp).toDate(),
      startTime: TimeOfDay(
        hour: map['startTimeHour'],
        minute: map['startTimeMinute'],
      ),
      endTime: TimeOfDay(
        hour: map['endTimeHour'],
        minute: map['endTimeMinute'],
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Event>> _events = {};

  // Controllers for the event dialog text fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance

  @override
  void initState() {
    super.initState();
    tz_data.initializeTimeZones(); // Initialize timezone data
    initializeDateFormatting(
      'tr_TR',
      null,
    ); // Initialize date formatting for Turkish locale
    _selectedDay = _focusedDay; // Initialize selected day
    _loadEventsFromFirestore(); // Load events when the screen initializes
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadEventsFromFirestore() async {
    // For now, load all events. Consider querying by date range for larger datasets.
    // Assuming events are stored for the current user or globally accessible.
    // If you have user authentication, you would typically filter by userId.
    QuerySnapshot snapshot =
        await _firestore.collection('calendar_plans').get();
    Map<DateTime, List<Event>> loadedEvents = {};
    for (var doc in snapshot.docs) {
      Event event = Event.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      DateTime eventDate = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      ); // Normalize date for map key
      if (loadedEvents[eventDate] != null) {
        loadedEvents[eventDate]!.add(event);
      } else {
        loadedEvents[eventDate] = [event];
      }
    }
    if (mounted) {
      setState(() {
        _events = loadedEvents;
      });
    }
  }

  List<Event> _getEventsForDay(DateTime day) {
    // Normalize the day to ensure consistency with map keys
    DateTime normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  Future<void> _showAddEventDialog() async {
    _titleController.clear();
    _descriptionController.clear();
    _selectedStartTime = null;
    _selectedEndTime = null;

    if (_selectedDay == null)
      return; // Should not happen if FAB is pressed after selecting a day

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          // Use StatefulBuilder to update time pickers in dialog
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add Event for ${MaterialLocalizations.of(context).formatShortDate(_selectedDay!)}',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(hintText: 'Title'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedStartTime == null
                              ? 'Start Time'
                              : _selectedStartTime!.format(context),
                        ),
                        TextButton(
                          child: const Text('Select'),
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime:
                                  _selectedStartTime ?? TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                _selectedStartTime = picked;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedEndTime == null
                              ? 'End Time'
                              : _selectedEndTime!.format(context),
                        ),
                        TextButton(
                          child: const Text('Select'),
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime:
                                  _selectedEndTime ??
                                  _selectedStartTime ??
                                  TimeOfDay.now(),
                            );
                            if (picked != null) {
                              // Basic validation: end time should be after start time
                              if (_selectedStartTime != null) {
                                final startMinutes =
                                    _selectedStartTime!.hour * 60 +
                                    _selectedStartTime!.minute;
                                final endMinutes =
                                    picked.hour * 60 + picked.minute;
                                if (endMinutes <= startMinutes) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'End time must be after start time.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              }
                              setDialogState(() {
                                _selectedEndTime = picked;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    if (_titleController.text.isEmpty ||
                        _selectedStartTime == null ||
                        _selectedEndTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Title, start time, and end time are required.',
                          ),
                        ),
                      );
                      return;
                    }

                    final newEvent = Event(
                      // id will be generated by Firestore
                      title: _titleController.text,
                      description: _descriptionController.text,
                      date:
                          _selectedDay!, // The selected day is the date of the event
                      startTime: _selectedStartTime!,
                      endTime: _selectedEndTime!,
                    );

                    try {
                      // Save to Firestore
                      DocumentReference docRef = await _firestore
                          .collection('calendar_plans')
                          .add(newEvent.toMap());

                      // Add to local state with Firestore ID
                      final eventWithId = Event(
                        id: docRef.id,
                        title: newEvent.title,
                        description: newEvent.description,
                        date: newEvent.date,
                        startTime: newEvent.startTime,
                        endTime: newEvent.endTime,
                      );

                      final normalizedDay = DateTime(
                        eventWithId.date.year,
                        eventWithId.date.month,
                        eventWithId.date.day,
                      );
                      setState(() {
                        if (_events[normalizedDay] != null) {
                          _events[normalizedDay]!.add(eventWithId);
                        } else {
                          _events[normalizedDay] = [eventWithId];
                        }
                      });
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Event saved successfully!'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save event: $e')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TableCalendar<Event>(
            locale: 'tr_TR',
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableGestures: AvailableGestures.all,
            availableCalendarFormats: const {
              CalendarFormat.week: 'Hafta',
              CalendarFormat.month: 'Ay',
            },
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: true,
              formatButtonShowsNext: false,
              titleTextStyle: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
              formatButtonTextStyle: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(12.0),
              ),
              leftChevronIcon: const Icon(
                Icons.chevron_left,
                color: Colors.blue,
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right,
                color: Colors.blue,
              ),
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(color: Colors.white),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(color: Colors.black87),
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(color: Colors.red[700]),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: const TextStyle(fontWeight: FontWeight.w500),
              weekendStyle: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.red[700],
              ),
            ),
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            eventLoader: _getEventsForDay,
            onDaySelected:
                (selectedDay, focusedDay) => setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                }),
            onPageChanged:
                (focusedDay) => setState(() {
                  _focusedDay = focusedDay;
                }),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child:
                _buildEventList(), // Use a dedicated method to build the event list
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedDay != null) {
            _showAddEventDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select a day first to add an event.'),
              ),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // Widget to build the list of events for the selected day
  Widget _buildEventList() {
    final eventsForSelectedDay = _getEventsForDay(_selectedDay ?? _focusedDay);
    if (eventsForSelectedDay.isEmpty) {
      return const Center(child: Text('Bugün planın yok.'));
    }
    return ListView.builder(
      itemCount: eventsForSelectedDay.length,
      itemBuilder: (context, index) {
        final event = eventsForSelectedDay[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: ListTile(
            title: Text(event.title),
            subtitle: Text(event.description),
            trailing: Text(
              '${event.startTime.format(context)} - ${event.endTime.format(context)}',
            ),
            // Optional: Add onTap to edit or delete event
            // onTap: () => _showEditEventDialog(event),
          ),
        );
      },
    );
  }
}
