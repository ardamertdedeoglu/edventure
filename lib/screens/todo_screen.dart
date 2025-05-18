import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/todo.dart';
import '../services/todo_service.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({Key? key}) : super(key: key);

  @override
  _TodoScreenState createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> with SingleTickerProviderStateMixin {
  final TodoService _todoService = TodoService();
  late Stream<List<Todo>> _activeTodosStream;
  late Stream<List<Todo>> _completedTodosStream;
  late TabController _tabController;
  bool _isCompletedTab = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  Todo? _editingTodo;

  @override
  void initState() {
    super.initState();
    _initTodosStreams();
    _tabController = TabController(length: 2, vsync: this);
    
    // Tab değişimlerini dinle
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    // Only update state when tab index actually changes
    if (_tabController.indexIsChanging || _tabController.animation!.value.round() != _tabController.previousIndex) {
      setState(() {
        _isCompletedTab = _tabController.index == 1;
      });
    }
  }

  void _initTodosStreams() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user != null) {
      _activeTodosStream = _todoService.getActiveTodos(authService.user!.uid);
      _completedTodosStream = _todoService.getCompletedTodos(authService.user!.uid);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, Function(DateTime) onDateSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF246EE9),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF246EE9),
                textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      // First update the parent state
      setState(() {
        _selectedDate = picked;
      });
      // Then call the callback to update the dialog state
      onDateSelected(picked);
    }
  }

  void _showAddEditTodoDialog([Todo? todo]) {
    _editingTodo = todo;
    if (todo != null) {
      _titleController.text = todo.title;
      _descriptionController.text = todo.description;
      _selectedDate = todo.deadline;
    } else {
      _titleController.clear();
      _descriptionController.clear();
      _selectedDate = DateTime.now().add(const Duration(days: 1));
    }

    // Create a local date variable for the dialog
    DateTime dialogSelectedDate = _selectedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            _editingTodo == null ? 'Yeni Görev Ekle' : 'Görevi Düzenle',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Color(0xFF246EE9),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Başlık',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: 'Görev başlığı...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF246EE9), width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Açıklama',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: _descriptionController,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: 'Görev detayları...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF246EE9), width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  minLines: 3,
                  maxLines: 5,
                ),
                SizedBox(height: 20),
                Text(
                  'Son Tarih',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 6),
                InkWell(
                  onTap: () => _selectDate(context, (newDate) {
                    // Update the dialog state with the new date
                    setState(() {
                      dialogSelectedDate = newDate;
                    });
                    // Also update the parent state
                    this.setState(() {
                      _selectedDate = newDate;
                    });
                  }),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Color(0xFF246EE9), size: 20),
                        SizedBox(width: 12),
                        Text(
                          DateFormat('dd MMM yyyy').format(dialogSelectedDate),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _saveTodo();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF246EE9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                _editingTodo == null ? 'Ekle' : 'Güncelle',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveTodo() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Başlık boş olamaz',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.user!.uid;

      if (_editingTodo == null) {
        // Create a new todo
        final newTodo = Todo(
          id: '', // Firestore will generate an ID
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          deadline: _selectedDate,
          userId: userId,
        );
        await _todoService.addTodo(newTodo);
        
        // Yeni görev eklendiyse ve tamamlanan tab'daysa, aktif tab'a geç
        if (_tabController.index == 1) {
          _tabController.animateTo(0);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Görev başarıyla eklendi',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Update existing todo
        final updatedTodo = _editingTodo!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          deadline: _selectedDate,
        );
        await _todoService.updateTodo(updatedTodo);
        
        // Görev güncellendiğinde, doğru tab'a geçiş yap
        final isInCorrectTab = (_tabController.index == 0 && !updatedTodo.isCompleted) || 
                               (_tabController.index == 1 && updatedTodo.isCompleted);
        
        if (!isInCorrectTab) {
          _tabController.animateTo(updatedTodo.isCompleted ? 1 : 0);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Görev başarıyla güncellendi',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bir hata oluştu: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      print('Error saving todo: $e');
    }
  }

  void _deleteTodo(Todo todo) async {
    try {
      await _todoService.deleteTodo(todo.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Görev başarıyla silindi',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Görev silinirken bir hata oluştu: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      print('Error deleting todo: $e');
    }
  }

  void _toggleTodoStatus(Todo todo) async {
    try {
      await _todoService.toggleTodoStatus(todo);
      
      // Görev tamamlandığında veya tamamlanmış görev tekrar aktif yapıldığında
      // uygun tab'a geçiş yap
      if (todo.isCompleted && _tabController.index == 1) {
        // Tamamlanmış görev aktif yapıldıysa ve tamamlanan tab'daysa
        // aktif tab'a geç
        _tabController.animateTo(0);
      } else if (!todo.isCompleted && _tabController.index == 0) {
        // Aktif görev tamamlandıysa ve aktif tab'daysa
        // tamamlanan tab'a geç
        _tabController.animateTo(1);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Görev durumu değiştirilirken bir hata oluştu: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      print('Error toggling todo status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    if (authService.user == null) {
      return Center(
        child: Text(
          'Görevleri görüntülemek için giriş yapmalısınız.',
          style: GoogleFonts.poppins(),
        ),
      );
    }
    
    return Scaffold(
      body: Column(
        children: [
          // Tab bar at the top
          Container(
            color: Color(0xFF246EE9).withOpacity(0.05),
            child: TabBar(
              controller: _tabController,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.poppins(),
              labelColor: Color(0xFF246EE9),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Color(0xFF246EE9),
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'Aktif', icon: Icon(Icons.pending_actions)),
                Tab(text: 'Tamamlanan', icon: Icon(Icons.task_alt)),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF246EE9).withOpacity(0.05), Colors.white],
                ),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Active todos tab
                  _buildTodoList(false),
                  // Completed todos tab
                  _buildTodoList(true),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditTodoDialog(),
        backgroundColor: Color(0xFF246EE9),
        elevation: 4,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTodoList(bool showCompleted) {
    final stream = showCompleted ? _completedTodosStream : _activeTodosStream;
    
    return StreamBuilder<List<Todo>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Color(0xFF246EE9),
            ),
          );
        }
        
        if (snapshot.hasError) {
          print("StreamBuilder error: ${snapshot.error}");
          String errorMessage = 'Bir hata oluştu';
          
          // Handle Firestore index errors specifically
          if (snapshot.error.toString().contains('index')) {
            errorMessage = 'Firestore index hatası. Lütfen Firebase konsolu üzerinden gerekli indexi oluşturun.';
          }
          
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.withOpacity(0.7),
                ),
                SizedBox(height: 16),
                Text(
                  'Görevler yüklenirken hata oluştu',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh),
                  label: Text(
                    'Yeniden Dene',
                    style: GoogleFonts.poppins(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF246EE9),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _initTodosStreams();
                    });
                  },
                ),
              ],
            ),
          );
        }
        
        final todos = snapshot.data ?? [];
        
        if (todos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  showCompleted ? Icons.check_circle_outline : Icons.assignment,
                  size: 80,
                  color: Colors.grey.withOpacity(0.5),
                ),
                SizedBox(height: 16),
                Text(
                  showCompleted 
                      ? 'Henüz tamamlanmış görev yok' 
                      : 'Henüz görev eklenmemiş',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 20),
                if (!showCompleted)
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text(
                      'Görev Ekle',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _showAddEditTodoDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF246EE9),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: todos.length,
          itemBuilder: (context, index) {
            final todo = todos[index];
            final isOverdue = todo.deadline.isBefore(DateTime.now()) && !todo.isCompleted;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isOverdue
                      ? BorderSide(color: Colors.red.shade300, width: 1)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Checkbox
                          Transform.scale(
                            scale: 1.2,
                            child: Checkbox(
                              value: todo.isCompleted,
                              onChanged: (_) => _toggleTodoStatus(todo),
                              activeColor: Color(0xFF246EE9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          // Title
                          Expanded(
                            child: Text(
                              todo.title,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                decoration: todo.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: todo.isCompleted
                                    ? Colors.grey.shade600
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          // Action buttons
                          IconButton(
                            icon: Icon(Icons.edit, color: Color(0xFF246EE9)),
                            onPressed: () => _showAddEditTodoDialog(todo),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red.shade400),
                            onPressed: () => _deleteTodo(todo),
                          ),
                        ],
                      ),
                      if (todo.description.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.only(left: 46, top: 8, right: 8),
                          child: Text(
                            todo.description,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                      Padding(
                        padding: EdgeInsets.only(left: 46, top: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: isOverdue ? Colors.red : Colors.grey,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Son Tarih: ${DateFormat('dd MMM yyyy').format(todo.deadline)}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: isOverdue ? Colors.red : Colors.grey.shade700,
                                fontWeight: isOverdue ? FontWeight.w600 : null,
                              ),
                            ),
                            if (isOverdue) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Gecikmiş',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
} 