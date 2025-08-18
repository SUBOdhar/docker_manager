import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const DockerManagerApp());
}

class DockerManagerApp extends StatelessWidget {
  const DockerManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docker Manager',
      // Define the Material Design theme for the application
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ContainerListScreen(),
    );
  }
}

// Service class to handle all API calls
class DockerService {
  final String apiUrl;
  DockerService(this.apiUrl);

  Future<List<dynamic>> getContainers() async {
    final response = await http.get(Uri.parse('$apiUrl/containers'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load containers');
    }
  }

  Future<void> startContainer(String id) async {
    final response = await http.post(Uri.parse('$apiUrl/containers/$id/start'));
    if (response.statusCode != 200) {
      throw Exception('Failed to start container');
    }
  }

  Future<void> stopContainer(String id) async {
    final response = await http.post(Uri.parse('$apiUrl/containers/$id/stop'));
    if (response.statusCode != 200) {
      throw Exception('Failed to stop container');
    }
  }

  Future<void> restartContainer(String id) async {
    final response = await http.post(
      Uri.parse('$apiUrl/containers/$id/restart'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to restart container');
    }
  }

  Future<void> deleteContainer(String id) async {
    final response = await http.delete(Uri.parse('$apiUrl/containers/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete container');
    }
  }

  Future<void> createContainer(String imageName, String containerName) async {
    final response = await http.post(
      Uri.parse('$apiUrl/containers'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'Image': imageName, 'name': containerName}),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create container');
    }
  }
}

class ContainerListScreen extends StatefulWidget {
  const ContainerListScreen({super.key});

  @override
  State<ContainerListScreen> createState() => _ContainerListScreenState();
}

class _ContainerListScreenState extends State<ContainerListScreen> {
  late Future<List<dynamic>> _containers;
  final TextEditingController _apiUrlController = TextEditingController();
  String _dockerApiUrl = '';
  DockerService? _dockerService;

  @override
  void initState() {
    super.initState();
    // Initially, show a dialog to get the API URL
    WidgetsBinding.instance.addPostFrameCallback((_) => _showApiUrlDialog());
  }

  void _showApiUrlDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Docker API URL'),
          content: TextField(
            controller: _apiUrlController,
            decoration: const InputDecoration(
              hintText: 'e.g., http://localhost:3000',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Submit'),
              onPressed: () {
                setState(() {
                  _dockerApiUrl = _apiUrlController.text;
                  _dockerService = DockerService(_dockerApiUrl);
                  _fetchContainers();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _fetchContainers() {
    if (_dockerService != null) {
      setState(() {
        _containers = _dockerService!.getContainers();
      });
    }
  }

  void _showActionSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _performAction(
    Function action,
    String successMessage,
    String errorMessage,
  ) async {
    try {
      await action();
      _showActionSnackbar(successMessage);
      _fetchContainers();
    } catch (e) {
      _showActionSnackbar(errorMessage, isError: true);
    }
  }

  Future<void> _showCreateContainerDialog() async {
    final TextEditingController imageController = TextEditingController();
    final TextEditingController nameController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Container'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: imageController,
                decoration: const InputDecoration(labelText: 'Image Name'),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Container Name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (imageController.text.isNotEmpty &&
                    nameController.text.isNotEmpty) {
                  _performAction(
                    () => _dockerService!.createContainer(
                      imageController.text,
                      nameController.text,
                    ),
                    'Container created successfully!',
                    'Failed to create container.',
                  );
                  Navigator.pop(context);
                } else {
                  _showActionSnackbar(
                    'Image and Name are required.',
                    isError: true,
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Docker Container Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchContainers,
          ),
        ],
      ),
      body: _dockerService == null
          ? const Center(
              child: CircularProgressIndicator(),
            ) // Or a different loading state
          : FutureBuilder<List<dynamic>>(
              future: _containers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No containers found.'));
                } else {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final container = snapshot.data![index];
                      final String id = container['id'].substring(0, 12);
                      final String name = container['name'];
                      final String image = container['image'];
                      final String status = container['status'];
                      final String state = container['state'];
                      final bool isRunning = state == 'running';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID: $id',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('Name: $name'),
                              Text('Image: $image'),
                              Text('Status: $status'),
                              Text('State: $state'),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!isRunning)
                                    ElevatedButton(
                                      onPressed: () => _performAction(
                                        () => _dockerService!.startContainer(
                                          container['id'],
                                        ),
                                        'Container started.',
                                        'Failed to start container.',
                                      ),
                                      child: const Text('Start'),
                                    ),
                                  if (isRunning)
                                    ElevatedButton(
                                      onPressed: () => _performAction(
                                        () => _dockerService!.stopContainer(
                                          container['id'],
                                        ),
                                        'Container stopped.',
                                        'Failed to stop container.',
                                      ),
                                      child: const Text('Stop'),
                                    ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _performAction(
                                      () => _dockerService!.restartContainer(
                                        container['id'],
                                      ),
                                      'Container restarted.',
                                      'Failed to restart container.',
                                    ),
                                    child: const Text('Restart'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (isRunning) {
                                        _showActionSnackbar(
                                          'Cannot delete a running container. Please stop it first.',
                                          isError: true,
                                        );
                                      } else {
                                        _performAction(
                                          () => _dockerService!.deleteContainer(
                                            container['id'],
                                          ),
                                          'Container deleted.',
                                          'Failed to delete container. Is it stopped?',
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_dockerService != null) {
            _showCreateContainerDialog();
          } else {
            _showActionSnackbar(
              'Please enter the API URL first.',
              isError: true,
            );
          }
        },
        tooltip: 'Create Container',
        child: const Icon(Icons.add),
      ),
    );
  }
}
