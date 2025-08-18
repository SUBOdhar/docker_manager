import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const DockerManagerApp());
}

// Service class to handle all API calls
class DockerService {
  final String apiUrl;
  DockerService(this.apiUrl);

  Future<List<dynamic>> getContainers() async {
    final response = await http.get(Uri.parse('$apiUrl/containers'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      // Assuming the API returns a list of container objects under a 'data' key
      return jsonResponse['data'];
    } else {
      throw Exception(
        'Failed to load containers. Status code: ${response.statusCode}',
      );
    }
  }

  Future<void> startContainer(String id) async {
    final response = await http.post(Uri.parse('$apiUrl/containers/$id/start'));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to start container. Status code: ${response.statusCode}',
      );
    }
  }

  Future<void> stopContainer(String id) async {
    final response = await http.post(Uri.parse('$apiUrl/containers/$id/stop'));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to stop container. Status code: ${response.statusCode}',
      );
    }
  }

  Future<void> restartContainer(String id) async {
    final response = await http.post(
      Uri.parse('$apiUrl/containers/$id/restart'),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to restart container. Status code: ${response.statusCode}',
      );
    }
  }

  Future<void> deleteContainer(String id) async {
    final response = await http.delete(Uri.parse('$apiUrl/containers/$id'));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete container. Status code: ${response.statusCode}',
      );
    }
  }

  Future<void> createContainer(String imageName, String containerName) async {
    final response = await http.post(
      Uri.parse('$apiUrl/containers'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'Image': imageName, 'name': containerName}),
    );
    if (response.statusCode != 201) {
      throw Exception(
        'Failed to create container. Status code: ${response.statusCode}',
      );
    }
  }

  Future<List<dynamic>> getImages() async {
    final response = await http.get(Uri.parse('$apiUrl/images'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return jsonResponse['data'];
    } else {
      throw Exception(
        'Failed to load images. Status code: ${response.statusCode}',
      );
    }
  }

  Future<void> deleteImage(String name) async {
    final response = await http.delete(Uri.parse('$apiUrl/images/$name'));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete image. Status code: ${response.statusCode}',
      );
    }
  }

  Future<void> pullImage(String name) async {
    final response = await http.post(Uri.parse('$apiUrl/images/$name/pull'));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to pull image. Status code: ${response.statusCode}',
      );
    }
  }

  Stream<String> getContainerLogs(String id) async* {
    try {
      final client = http.Client();
      final request = http.Request(
        'GET',
        Uri.parse('$apiUrl/containers/$id/logs'),
      );
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to get container logs. Status code: ${response.statusCode}',
        );
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        yield chunk;
      }
    } catch (e) {
      throw Exception('An error occurred while streaming logs: $e');
    }
  }
}

class DockerManagerApp extends StatelessWidget {
  const DockerManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docker Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String _dockerApiUrl = '';
  DockerService? _dockerService;
  static const String _apiUrlKey = 'docker_api_url';
  final TextEditingController _apiUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApiUrl();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_apiUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _dockerApiUrl = savedUrl;
      _dockerService = DockerService(_dockerApiUrl);
      setState(() {});
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showApiUrlDialog());
    }
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
              hintText: 'e.g., http://localhost:1113',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Submit'),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(_apiUrlKey, _apiUrlController.text);
                setState(() {
                  _dockerApiUrl = _apiUrlController.text;
                  _dockerService = DockerService(_dockerApiUrl);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dockerService == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ContainerListScreen(dockerService: _dockerService!),
          ImageListScreen(dockerService: _dockerService!),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.layers),
            label: 'Containers',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.image), label: 'Images'),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class ContainerListScreen extends StatefulWidget {
  final DockerService dockerService;
  const ContainerListScreen({super.key, required this.dockerService});

  @override
  State<ContainerListScreen> createState() => _ContainerListScreenState();
}

class _ContainerListScreenState extends State<ContainerListScreen> {
  List<dynamic> _containers = [];
  bool _isInitialLoad = true;
  Timer? _timer;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchContainers();
    _startAutoRefresh();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchContainers();
    });
  }

  Future<void> _fetchContainers() async {
    if (_isInitialLoad) {
      setState(() {
        _isInitialLoad = false;
      });
    }
    try {
      final containers = await widget.dockerService.getContainers();
      setState(() {
        _containers = containers;
      });
    } catch (e) {
      _showActionSnackbar('Failed to load containers: $e', isError: true);
    }
  }

  void _showActionSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.tertiary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleAction(
    Future<void> action,
    String loadingMessage,
    String successMessage,
    String errorMessage,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(loadingMessage),
          ],
        ),
      ),
    );

    try {
      await action;
      if (mounted) {
        Navigator.pop(context);
      }
      _showActionSnackbar(successMessage);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      _showActionSnackbar('$errorMessage: $e', isError: true);
    } finally {
      _fetchContainers();
    }
  }

  Future<void> _showCreateContainerDialog() async {
    final TextEditingController imageController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    const List<String> popularImages = [
      'nginx',
      'ubuntu',
      'mysql',
      'redis',
      'mongo',
      'node',
      'python',
    ];

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Create New Container',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: imageController,
                      decoration: const InputDecoration(
                        labelText: 'Image Name',
                        hintText: 'e.g., nginx:latest',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Image name is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Popular Suggestions',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      children: popularImages.map((image) {
                        return FilledButton.tonal(
                          onPressed: () {
                            imageController.text = image;
                          },
                          child: Text(image),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Container Name',
                        hintText: 'e.g., my-web-server',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Container name is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              Navigator.pop(context);
                              await _handleAction(
                                widget.dockerService.createContainer(
                                  imageController.text,
                                  nameController.text,
                                ),
                                'Creating container...',
                                'Container created successfully!',
                                'Failed to create container.',
                              );
                            }
                          },
                          child: const Text('Create'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getUptime(String createdAt) {
    if (createdAt.isEmpty) {
      return 'N/A';
    }
    try {
      final createdDate = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now().toLocal();
      final difference = now.difference(createdDate);

      if (difference.inDays > 0) {
        return 'Up for ${difference.inDays} day(s)';
      }
      if (difference.inHours > 0) {
        return 'Up for ${difference.inHours} hour(s)';
      }
      if (difference.inMinutes > 0) {
        return 'Up for ${difference.inMinutes} minute(s)';
      }
      return 'Up for a few seconds';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredContainers = _containers.where((container) {
      final name = container['name'].toLowerCase();
      final image = container['image'].toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || image.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Containers'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Manual Refresh',
            onPressed: _fetchContainers,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search containers by name or image...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _isInitialLoad
            ? const Center(child: CircularProgressIndicator())
            : filteredContainers.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inbox, size: 80, color: Colors.blueGrey),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No containers found.'
                          : 'No containers match your search.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the "+" button to create a new container.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: filteredContainers.length,
                itemBuilder: (context, index) {
                  final container = filteredContainers[index];
                  final String name = container['name'];
                  final String image = container['image'];
                  final String state = container['state'];
                  final String createdAt = container['createdAt'].toString();
                  final bool isRunning = state == 'running';

                  Color statusColor;
                  if (isRunning) {
                    statusColor = Colors.greenAccent.withOpacity(0.2);
                  } else if (state == 'exited') {
                    statusColor = Theme.of(context).colorScheme.errorContainer;
                  } else {
                    statusColor = Colors.grey;
                  }

                  return Card(
                    color: statusColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main container info row with status indicator
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isRunning
                                          ? _getUptime(createdAt)
                                          : 'Exited',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                              // Main action button
                              if (isRunning)
                                FilledButton(
                                  onPressed: () => _handleAction(
                                    widget.dockerService.stopContainer(
                                      container['id'],
                                    ),
                                    'Stopping container...',
                                    'Container stopped.',
                                    'Failed to stop container.',
                                  ),
                                  child: const Text('Stop'),
                                )
                              else
                                FilledButton(
                                  onPressed: () => _handleAction(
                                    widget.dockerService.startContainer(
                                      container['id'],
                                    ),
                                    'Starting container...',
                                    'Container started.',
                                    'Failed to start container.',
                                  ),
                                  child: const Text('Start'),
                                ),
                              // Overflow menu for other actions
                              PopupMenuButton<String>(
                                onSelected: (String result) {
                                  switch (result) {
                                    case 'Restart':
                                      _handleAction(
                                        widget.dockerService.restartContainer(
                                          container['id'],
                                        ),
                                        'Restarting container...',
                                        'Container restarted.',
                                        'Failed to restart container.',
                                      );
                                      break;
                                    case 'Delete':
                                      if (isRunning) {
                                        _showActionSnackbar(
                                          'Cannot delete a running container. Please stop it first.',
                                          isError: true,
                                        );
                                      } else {
                                        _handleAction(
                                          widget.dockerService.deleteContainer(
                                            container['id'],
                                          ),
                                          'Deleting container...',
                                          'Container deleted.',
                                          'Failed to delete container. Is it stopped?',
                                        );
                                      }
                                      break;
                                    case 'Logs':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LogScreen(
                                            dockerService: widget.dockerService,
                                            containerId: container['id'],
                                            containerName: name,
                                          ),
                                        ),
                                      );
                                      break;
                                  }
                                },
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuItem<String>>[
                                      if (isRunning)
                                        const PopupMenuItem<String>(
                                          value: 'Restart',
                                          child: ListTile(
                                            leading: Icon(Icons.refresh),
                                            title: Text('Restart'),
                                          ),
                                        ),
                                      const PopupMenuItem<String>(
                                        value: 'Delete',
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          title: Text('Delete'),
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'Logs',
                                        child: ListTile(
                                          leading: Icon(Icons.description),
                                          title: Text('Logs'),
                                        ),
                                      ),
                                    ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Secondary info (Image and ID)
                          Text(
                            'Image: $image',
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'ID: ${container['id'].substring(0, 12)}',
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateContainerDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Container'),
        heroTag: 'container-fab-hero', // Corrected: use the built-in heroTag
      ),
    );
  }
}

class ImageListScreen extends StatefulWidget {
  final DockerService dockerService;
  const ImageListScreen({super.key, required this.dockerService});

  @override
  State<ImageListScreen> createState() => _ImageListScreenState();
}

class _ImageListScreenState extends State<ImageListScreen> {
  List<dynamic> _images = [];
  bool _isInitialLoad = true;
  Timer? _timer;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchImages();
    _startAutoRefresh();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchImages();
    });
  }

  Future<void> _fetchImages() async {
    if (_isInitialLoad) {
      setState(() {
        _isInitialLoad = false;
      });
    }
    try {
      final images = await widget.dockerService.getImages();
      setState(() {
        _images = images;
      });
    } catch (e) {
      _showActionSnackbar('Failed to load images: $e', isError: true);
    }
  }

  void _showActionSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.tertiary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleAction(
    Future<void> action,
    String loadingMessage,
    String successMessage,
    String errorMessage,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(loadingMessage),
          ],
        ),
      ),
    );

    try {
      await action;
      if (mounted) {
        Navigator.pop(context);
      }
      _showActionSnackbar(successMessage);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      _showActionSnackbar('$errorMessage: $e', isError: true);
    } finally {
      _fetchImages();
    }
  }

  Future<void> _showPullImageDialog() async {
    final TextEditingController imageController = TextEditingController();
    const List<String> popularImages = [
      'nginx',
      'ubuntu',
      'mysql',
      'redis',
      'mongo',
      'node',
      'python',
    ];

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pull a new image',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: imageController,
                      decoration: const InputDecoration(
                        labelText: 'Image Name',
                        hintText: 'e.g., nginx:latest',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Image name is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Popular Suggestions',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      children: popularImages.map((image) {
                        return FilledButton.tonal(
                          onPressed: () {
                            imageController.text = image;
                          },
                          child: Text(image),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              Navigator.pop(context);
                              await _handleAction(
                                widget.dockerService.pullImage(
                                  imageController.text,
                                ),
                                'Pulling image...',
                                'Image pulled successfully!',
                                'Failed to pull image.',
                              );
                            }
                          },
                          child: const Text('Pull'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredImages = _images.where((image) {
      final name = image['name'].toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Images'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Manual Refresh',
            onPressed: _fetchImages,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search images by name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _isInitialLoad
            ? const Center(child: CircularProgressIndicator())
            : filteredImages.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.image_not_supported,
                      size: 80,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No images found.'
                          : 'No images match your search.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the "+" button to pull a new image.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: filteredImages.length,
                itemBuilder: (context, index) {
                  final image = filteredImages[index];
                  final String name = image['name'];
                  final String size = image['size'];
                  final String id = image['id'].substring(0, 12);

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.image),
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text('ID: $id'), Text('Size: $size')],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (String result) {
                          switch (result) {
                            case 'Delete':
                              _handleAction(
                                widget.dockerService.deleteImage(name),
                                'Deleting image...',
                                'Image deleted.',
                                'Failed to delete image.',
                              );
                              break;
                            case 'Pull':
                              _handleAction(
                                widget.dockerService.pullImage(name),
                                'Pulling image...',
                                'Image pulled.',
                                'Failed to pull image.',
                              );
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuItem<String>>[
                              const PopupMenuItem<String>(
                                value: 'Delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete),
                                  title: Text('Delete'),
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'Pull',
                                child: ListTile(
                                  leading: Icon(Icons.download),
                                  title: Text('Pull'),
                                ),
                              ),
                            ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPullImageDialog,
        icon: const Icon(Icons.add),
        label: const Text('Pull Image'),
        heroTag: 'image-fab-hero', // Corrected: use the built-in heroTag
      ),
    );
  }
}

class LogScreen extends StatefulWidget {
  final DockerService dockerService;
  final String containerId;
  final String containerName;

  const LogScreen({
    super.key,
    required this.dockerService,
    required this.containerId,
    required this.containerName,
  });

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final List<String> _logs = [];
  late final Stream<String> _logStream;

  @override
  void initState() {
    super.initState();
    _logStream = widget.dockerService.getContainerLogs(widget.containerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Logs for ${widget.containerName}')),
      body: SafeArea(
        child: StreamBuilder<String>(
          stream: _logStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 80,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load logs.',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The container might not be running or the Docker API is unreachable. Please check your connection and the container state.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasData) {
              _logs.add(snapshot.data!);
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(_logs.join()),
            );
          },
        ),
      ),
    );
  }
}
