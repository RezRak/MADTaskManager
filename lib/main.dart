import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(TaskManagerApp());
}

class TaskManagerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TaskProvider>(
      create: (_) => TaskProvider(),
      child: MaterialApp(
        title: 'Task Manager App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: AuthenticationWrapper(),
      ),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return TaskListScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}

// Task Provider
class TaskProvider extends ChangeNotifier {
  final CollectionReference _taskCollection = FirebaseFirestore.instance
      .collection('tasks')
      .doc(FirebaseAuth.instance.currentUser?.uid)
      .collection('userTasks');

  Stream<List<Task>> get tasks {
    return _taskCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Future<void> addTask(Task task) async {
    await _taskCollection.add(task.toMap());
  }

  Future<void> updateTask(Task task) async {
    await _taskCollection.doc(task.id).update(task.toMap());
  }

  Future<void> deleteTask(String id) async {
    await _taskCollection.doc(id).delete();
  }
}

// Task Model
class Task {
  String id;
  String name;
  bool isCompleted;
  String timeSlot; // For nested tasks
  List<SubTask> subTasks;

  Task({
    required this.id,
    required this.name,
    this.isCompleted = false,
    required this.timeSlot,
    required this.subTasks,
  });

  factory Task.fromMap(Map<String, dynamic> data, String documentId) {
    return Task(
      id: documentId,
      name: data['name'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      timeSlot: data['timeSlot'] ?? '',
      subTasks: data['subTasks'] != null
          ? List<SubTask>.from(
              data['subTasks'].map((subTask) => SubTask.fromMap(subTask)))
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isCompleted': isCompleted,
      'timeSlot': timeSlot,
      'subTasks': subTasks.map((subTask) => subTask.toMap()).toList(),
    };
  }
}

class SubTask {
  String name;

  SubTask({required this.name});

  factory SubTask.fromMap(Map<String, dynamic> data) {
    return SubTask(
      name: data['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }
}

// Login Screen
class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  bool isLogin = true;
  String email = '';
  String password = '';
  String errorMessage = '';

  void _submit() async {
    try {
      if (isLogin) {
        await _auth.signInWithEmailAndPassword(
            email: email.trim(), password: password.trim());
      } else {
        await _auth.createUserWithEmailAndPassword(
            email: email.trim(), password: password.trim());
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? 'An error occurred';
      });
    }
  }

  void _toggleForm() {
    setState(() {
      isLogin = !isLogin;
      errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Task Manager App'),
        ),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(children: [
            TextField(
              decoration: InputDecoration(labelText: 'Email'),
              onChanged: (value) => email = value,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
              onChanged: (value) => password = value,
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _submit,
              child: Text(isLogin ? 'Login' : 'Sign Up'),
            ),
            TextButton(
              onPressed: _toggleForm,
              child:
                  Text(isLogin ? 'Create new account' : 'I already have an account'),
            ),
            if (errorMessage.isNotEmpty)
              Text(errorMessage, style: TextStyle(color: Colors.red)),
          ]),
        ));
  }
}

// Task List Screen
class TaskListScreen extends StatefulWidget {
  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _timeSlotController = TextEditingController();
  final TextEditingController _subTaskController = TextEditingController();
  List<SubTask> _subTasks = [];

  void _addTask() async {
    if (_taskController.text.isEmpty || _timeSlotController.text.isEmpty) {
      return;
    }

    Task newTask = Task(
      id: '',
      name: _taskController.text,
      timeSlot: _timeSlotController.text,
      subTasks: _subTasks,
    );

    await Provider.of<TaskProvider>(context, listen: false).addTask(newTask);

    _taskController.clear();
    _timeSlotController.clear();
    _subTaskController.clear();
    setState(() {
      _subTasks = [];
    });
  }

  void _addSubTask() {
    if (_subTaskController.text.isEmpty) {
      return;
    }

    setState(() {
      _subTasks.add(SubTask(name: _subTaskController.text));
      _subTaskController.clear();
    });
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    return Scaffold(
        appBar: AppBar(
          title: Text('Task Manager'),
          actions: [
            IconButton(onPressed: _logout, icon: Icon(Icons.logout)),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(children: [
            TextField(
              controller: _taskController,
              decoration: InputDecoration(labelText: 'Task Name'),
            ),
            TextField(
              controller: _timeSlotController,
              decoration:
                  InputDecoration(labelText: 'Time Slot (e.g., Monday 9am-10am)'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subTaskController,
                    decoration: InputDecoration(labelText: 'Sub-Task'),
                  ),
                ),
                IconButton(
                  onPressed: _addSubTask,
                  icon: Icon(Icons.add),
                ),
              ],
            ),
            Wrap(
              children: _subTasks
                  .map((subTask) => Chip(
                        label: Text(subTask.name),
                      ))
                  .toList(),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _addTask,
              child: Text('Add Task'),
            ),
            SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<Task>>(
                stream: taskProvider.tasks,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final tasks = snapshot.data!;
                    if (tasks.isEmpty) {
                      return Center(child: Text('No tasks added.'));
                    }
                    return ListView(
                      children: tasks.map((task) {
                        return TaskWidget(task: task);
                      }).toList(),
                    );
                  } else if (snapshot.hasError) {
                    return Center(child: Text('An error occurred.'));
                  } else {
                    return Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ),
          ]),
        ));
  }
}

// Task Widget
class TaskWidget extends StatelessWidget {
  final Task task;

  TaskWidget({required this.task});

  void _toggleCompletion(BuildContext context, bool? newValue) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    task.isCompleted = newValue ?? false;
    taskProvider.updateTask(task);
  }

  void _deleteTask(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    taskProvider.deleteTask(task.id);
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        '${task.timeSlot}: ${task.name}',
        style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null),
      ),
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: (newValue) => _toggleCompletion(context, newValue),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete),
        onPressed: () => _deleteTask(context),
      ),
      children: task.subTasks.map((subTask) {
        return ListTile(
          title: Text(subTask.name),
        );
      }).toList(),
    );
  }
}