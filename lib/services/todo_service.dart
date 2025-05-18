import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/todo.dart';

/*
 * NOT: Firestore'da 'userId' ve 'deadline' alanlarına göre sıralama yapan bir sorgu için özel bir index oluşturmanız gerekiyor.
 * İndeks oluşturmak için:
 * 
 * 1. Firebase konsolunda https://console.firebase.google.com/ projenize gidin
 * 2. Sol menüden "Firestore Database" seçin
 * 3. "Indexes" sekmesine tıklayın
 * 4. "Create index" butonuna tıklayın
 * 5. Collection ID alanına "plans" yazın
 * 6. İlk alan için: Field path: "userId", Order: Ascending seçin
 * 7. "Add field" tıklayarak ikinci alan ekleyin: Field path: "deadline", Order: Ascending seçin
 * 8. "Create index" butonuna tıklayın ve indexin oluşmasını bekleyin
 * 
 * Index oluştuktan sonra todo_service.dart dosyasındaki `getTodos` metodunda
 * `.where('userId', isEqualTo: userId)` sonrasında `.orderBy('deadline', descending: false)` ekleyebiliriz.
 */
class TodoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'plans';

  // Get all todos for a specific user
  Stream<List<Todo>> getTodos(String userId, {bool descending = false}) {
    try {
      print("Fetching todos for user: $userId");
      return _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
            List<Todo> todos = snapshot.docs.map((doc) => Todo.fromFirestore(doc)).toList();
            // Client-side sorting to avoid index requirement
            todos.sort((a, b) => descending 
                ? b.deadline.compareTo(a.deadline) 
                : a.deadline.compareTo(b.deadline));
            return todos;
          });
    } catch (e) {
      print("Error fetching todos: $e");
      // Return empty stream on error
      return Stream.value([]);
    }
  }
  
  // Get active (not completed) todos for a specific user
  Stream<List<Todo>> getActiveTodos(String userId, {bool descending = false}) {
    try {
      print("Fetching active todos for user: $userId");
      return _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
            List<Todo> todos = snapshot.docs.map((doc) => Todo.fromFirestore(doc)).toList();
            // Client-side sorting to avoid index requirement
            todos.sort((a, b) => descending 
                ? b.deadline.compareTo(a.deadline) 
                : a.deadline.compareTo(b.deadline));
            return todos;
          });
    } catch (e) {
      print("Error fetching active todos: $e");
      // Return empty stream on error
      return Stream.value([]);
    }
  }
  
  // Get completed todos for a specific user
  Stream<List<Todo>> getCompletedTodos(String userId, {bool descending = false}) {
    try {
      print("Fetching completed todos for user: $userId");
      return _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
            List<Todo> todos = snapshot.docs.map((doc) => Todo.fromFirestore(doc)).toList();
            // Client-side sorting to avoid index requirement
            todos.sort((a, b) => descending 
                ? b.deadline.compareTo(a.deadline) 
                : a.deadline.compareTo(b.deadline));
            return todos;
          });
    } catch (e) {
      print("Error fetching completed todos: $e");
      // Return empty stream on error
      return Stream.value([]);
    }
  }

  // Add a new todo
  Future<void> addTodo(Todo todo) async {
    try {
      await _firestore.collection(_collection).add(todo.toMap());
      print("Todo added successfully");
    } catch (e) {
      print("Error adding todo: $e");
      rethrow;
    }
  }

  // Update an existing todo
  Future<void> updateTodo(Todo todo) async {
    try {
      await _firestore.collection(_collection).doc(todo.id).update(todo.toMap());
      print("Todo updated successfully: ${todo.id}");
    } catch (e) {
      print("Error updating todo: $e");
      rethrow;
    }
  }

  // Delete a todo
  Future<void> deleteTodo(String todoId) async {
    try {
      await _firestore.collection(_collection).doc(todoId).delete();
      print("Todo deleted successfully: $todoId");
    } catch (e) {
      print("Error deleting todo: $e");
      rethrow;
    }
  }

  // Toggle todo completion status
  Future<void> toggleTodoStatus(Todo todo) async {
    try {
      await _firestore.collection(_collection).doc(todo.id).update({
        'isCompleted': !todo.isCompleted,
      });
      print("Todo status toggled: ${todo.id}, new status: ${!todo.isCompleted}");
    } catch (e) {
      print("Error toggling todo status: $e");
      rethrow;
    }
  }
} 