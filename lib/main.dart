import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gnucash_helper_flutter/preferences_service.dart';
import 'package:sqflite/sqflite.dart';
// Use this import if you're running on desktop platforms
import 'package:sqflite_common_ffi/sqflite_ffi.dart';


void main() async {
  // Ensure that widget binding is initialized before using platform channels.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for sqflite if running on desktop (Windows, Linux, macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GnuCash Helper',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'GnuCash File Setup'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PreferencesService _preferencesService = PreferencesService();
  String? _gnucashFilePath;
  Database? _db;
  bool _isLoading = true;
  String _dbStatus = 'No database connected.';

  @override
  void initState() {
    super.initState();
    _checkAndLoadGnuCashPath();
  }

  @override
  void dispose() {
    _closeDatabase();
    super.dispose();
  }

  Future<void> _closeDatabase() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      setState(() {
        _db = null;
        _dbStatus = 'Database closed.';
      });
    }
  }

  Future<void> _connectToDatabase(String filePath) async {
    await _closeDatabase(); // Close any existing connection first
    try {
      // Note: For read-only access, you can use `readOnly: true`
      // final db = await openDatabase(filePath, readOnly: true);
      final db = await openDatabase(filePath);
      setState(() {
        _db = db;
        _dbStatus = 'Successfully connected to GnuCash database!';
        // You could potentially query some basic info here to verify the database
        // For example, list tables:
        // db.query('sqlite_master', columns: ['type', 'name']).then((value) {
        //   print(value);
        // });
      });
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_dbStatus), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() {
        _dbStatus = 'Error connecting to database: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_dbStatus), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _checkAndLoadGnuCashPath() async {
    setState(() {
      _isLoading = true;
      _dbStatus = 'Checking for GnuCash file...';
    });
    String? path = await _preferencesService.getGnuCashFilePath();
    if (path != null && await File(path).exists()) {
      setState(() {
        _gnucashFilePath = path;
      });
      await _connectToDatabase(path);
    } else {
      if (path != null) {
        await _preferencesService.clearGnuCashFilePath();
      }
      setState(() {
        _gnucashFilePath = null;
        _dbStatus = 'GnuCash file not found or not set.';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pickAndSetGnuCashFile(showAlert: true);
        }
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickAndSetGnuCashFile({bool showAlert = false}) async {
    if (showAlert && mounted) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('GnuCash File Not Found or Invalid'),
            content: const Text(
                'The previously selected GnuCash file was not found, is invalid, or a file has not been selected yet. Please select your GnuCash SQLite file.'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gnucash', 'sqlite', 'db', 'sqlite3'],
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      await _preferencesService.setGnuCashFilePath(path);
      setState(() {
        _gnucashFilePath = path;
      });
      await _connectToDatabase(path);
    } else {
      if (mounted && _gnucashFilePath == null) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No GnuCash file selected. Please select a file to continue.')),
        );
        setState(() {
          _dbStatus = 'No GnuCash file selected.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_dbStatus),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      _gnucashFilePath ?? 'No GnuCash file selected.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _dbStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _db != null && _db!.isOpen ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _pickAndSetGnuCashFile(showAlert: _gnucashFilePath == null),
                      child: Text(_gnucashFilePath == null ? 'Select GnuCash File' : 'Change GnuCash File'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
