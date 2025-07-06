import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gnucash_helper_flutter/database_validator.dart'; // Added import
import 'package:gnucash_helper_flutter/preferences_service.dart';
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
    Database? tempDb;
    try {
      // Note: For read-only access, you can use `readOnly: true`
      tempDb = await openDatabase(filePath);

      if (!await DatabaseValidator.isValidGnuCashDatabase(tempDb)) {
        await tempDb.close(); // Close the DB if it's not valid
        tempDb = null; // Ensure _db is not set with an invalid DB
        throw Exception('File is not a valid GnuCash database (missing "accounts" table).');
      }

      // If validation passes
      setState(() {
        _db = tempDb;
        _dbStatus = 'Successfully connected to GnuCash database!';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_dbStatus), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // Ensure tempDb is closed if it was opened and an error occurred
      // (e.g. during validation, or if openDatabase itself failed)
      if (tempDb != null && tempDb.isOpen) {
        await tempDb.close();
      }
      setState(() {
        _db = null; // Ensure _db is null on any error
        _dbStatus = 'Error: ${e.toString()}';
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
