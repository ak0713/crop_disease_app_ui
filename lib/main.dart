import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() { 
  runApp(const AgroVisionApp()); 
}

class AgroVisionApp extends StatelessWidget { 
  const AgroVisionApp({super.key});

  @override 
  Widget build(BuildContext context) { 
    return MaterialApp( 
      title: 'AgroVision', 
      debugShowCheckedModeBanner: false, 
      theme: ThemeData( 
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)), 
        useMaterial3: true, 
        fontFamily: 'Roboto', 
      ), 
      home: LayoutBuilder(
        builder: (context, constraints) {
          // If screen is wider than 600px (PC Browser)
          if (constraints.maxWidth > 600) {
            return Scaffold(
              backgroundColor: Colors.grey.shade900,
              body: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: const SizedBox(
                    width: 450,
                    child: MainNavigationWrapper(),
                  ),
                ),
              ),
            );
          }
          // If screen is narrow (Mobile Phone)
          return const MainNavigationWrapper();
        },
      ),
    ); 
  } 
}
// ========================================================
// 1. MAIN NAVIGATION WRAPPER (3 TABS)
// ========================================================
class MainNavigationWrapper extends StatefulWidget { 
  const MainNavigationWrapper({super.key});

  @override 
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState(); 
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> { 
  int _selectedIndex = 0;

  final List<Widget> _screens = const [ 
    ScannerHomePage(), 
    MandiPricesScreen(), 
    CommunityHubScreen(),
  ];

  @override 
  Widget build(BuildContext context) { 
    return Scaffold( 
      body: _screens[_selectedIndex], 
      bottomNavigationBar: NavigationBar( 
        selectedIndex: _selectedIndex, 
        onDestinationSelected: (int index) { 
          setState(() { _selectedIndex = index; }); 
        }, 
        backgroundColor: Colors.white, 
        indicatorColor: Colors.green.shade100, 
        destinations: const [ 
          NavigationDestination( 
            icon: Icon(Icons.document_scanner_outlined), 
            selectedIcon: Icon(Icons.document_scanner, color: Color(0xFF1B5E20)), 
            label: 'AI Scanner', 
          ), 
          NavigationDestination( 
            icon: Icon(Icons.storefront_outlined), 
            selectedIcon: Icon(Icons.storefront, color: Color(0xFF1B5E20)), 
            label: 'Mandi Prices', 
          ), 
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum, color: Color(0xFF1B5E20)),
            label: 'Kisan Sabha',
          ),
        ], 
      ), 
    ); 
  } 
}

// ========================================================
// 2. SCANNER HOME PAGE
// ========================================================
class ScannerHomePage extends StatefulWidget { 
  const ScannerHomePage({super.key});

  @override 
  State<ScannerHomePage> createState() => _ScannerHomePageState(); 
}

class _ScannerHomePageState extends State<ScannerHomePage> { 
  bool _isLoading = false; 
  Map<String, dynamic>? _diagnosisData;
  String _selectedCrop = 'Unknown'; 
  String _selectedLang = 'en'; 
  final List<String> _cropOptions = ['Unknown', 'Tomato', 'Potato'];

  String _buyLink = ''; 
  String _buyPrice = '';

  final Map<String, Map<String, String>> _uiText = { 
    'en': {'scan': 'Scan a Crop', 'cam': 'Camera', 'gal': 'Gallery', 'dash': 'Diagnosis Dashboard', 'plan': 'Action Plan', 'treat': 'Treatment & Pesticides'}, 
    'hi': {'scan': 'फसल स्कैन करें', 'cam': 'कैमरा', 'gal': 'गैलरी', 'dash': 'निदान डैशबोर्ड', 'plan': 'कार्य योजना', 'treat': 'उपचार और कीटनाशक'}, 
  };

  Future<void> _pickAndUploadImage(ImageSource source) async { 
    final ImagePicker picker = ImagePicker(); 
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        _isLoading = true;
        _diagnosisData = null;
        _buyLink = '';
        _buyPrice = '';
      });

      try {
        final bytes = await image.readAsBytes();
        
        var uri = Uri.parse('http://127.0.0.1:8000/diagnose?crop_type=$_selectedCrop&lang=$_selectedLang');
        var request = http.MultipartRequest('POST', uri);
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: image.name));

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final decodedData = jsonDecode(response.body);
          setState(() {
            _diagnosisData = decodedData;
            if (decodedData.containsKey('expert_treatment')) {
              _buyLink = decodedData['expert_treatment']['best_price_link'] ?? '';
              _buyPrice = decodedData['expert_treatment']['est_price'] ?? '';
            }
          });
        } else {
          _showErrorSnackBar('Server Error: ${response.statusCode}');
        }
      } catch (e) {
         _showErrorSnackBar('Connection Error: Is the FastAPI server running?');
      } finally {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _launchURL() async { 
    if (_buyLink.isNotEmpty) { 
      final Uri url = Uri.parse(_buyLink); 
      if (!await launchUrl(url)) { 
        _showErrorSnackBar('Could not launch $_buyLink'); 
      } 
    } 
  }

  void _showErrorSnackBar(String message) { 
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent)); 
  }

  @override 
  Widget build(BuildContext context) { 
    final t = _uiText[_selectedLang]!;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 15, top: 10),
                child: ToggleButtons(
                  isSelected: [_selectedLang == 'en', _selectedLang == 'hi'],
                  onPressed: (index) {
                    setState(() {
                      _selectedLang = index == 0 ? 'en' : 'hi';
                      _diagnosisData = null; 
                      _buyLink = ''; 
                    });
                  },
                  color: Colors.white70,
                  selectedColor: const Color(0xFF2E7D32),
                  fillColor: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  constraints: const BoxConstraints(minHeight: 35, minWidth: 50),
                  children: const [
                    Text('EN', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('हिंदी', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('AgroVision', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(child: Icon(Icons.energy_savings_leaf, size: 80, color: Colors.white38)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text(t['scan']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                          const SizedBox(height: 15),
                          DropdownButtonFormField<String>(
                            value: _selectedCrop,
                            decoration: InputDecoration(
                              labelText: 'Target Crop',
                              prefixIcon: const Icon(Icons.grass, color: Color(0xFF4CAF50)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                              filled: true, fillColor: Colors.grey.shade50,
                            ),
                            items: _cropOptions.map((String crop) => DropdownMenuItem<String>(value: crop, child: Text(crop))).toList(),
                            onChanged: (String? newValue) { setState(() { _selectedCrop = newValue!; }); },
                          ),
                          const SizedBox(height: 20),
                          if (_isLoading)
                            const Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _pickAndUploadImage(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                                    label: Text(t['cam']!, style: const TextStyle(color: Colors.white, fontSize: 16)),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickAndUploadImage(ImageSource.gallery),
                                    icon: const Icon(Icons.photo_library, color: Color(0xFF2E7D32)),
                                    label: Text(t['gal']!, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 16)),
                                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), side: const BorderSide(color: Color(0xFF2E7D32), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  
                  if (_diagnosisData != null) ...[
                    Text(t['dash']!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 15),
                    Card(
                      color: Colors.white, elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),
                        leading: CircleAvatar(backgroundColor: Colors.red.shade100, radius: 30, child: const Icon(Icons.coronavirus, color: Colors.redAccent, size: 30)),
                        title: Text(_diagnosisData!['diagnosis']['disease'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text('Confidence: ${_diagnosisData!['diagnosis']['confidence']}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(children: [const Icon(Icons.water_drop, color: Colors.blue), const SizedBox(height: 8), Text(_diagnosisData!['environmental_context']['average_humidity'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Card(
                            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(children: [const Icon(Icons.thermostat, color: Colors.orange), const SizedBox(height: 8), Text(_diagnosisData!['environmental_context']['average_temperature'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Card(
                      color: const Color(0xFFE8F5E9), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.green.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [const Icon(Icons.assignment, color: Color(0xFF2E7D32)), const SizedBox(width: 10), Text(t['plan']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)))]),
                            const Divider(),
                            ...(_diagnosisData!['farmer_instructions'] as List).map((instruction) => 
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [const Icon(Icons.play_arrow, size: 16, color: Color(0xFF2E7D32)), const SizedBox(width: 8), Expanded(child: Text(instruction.toString(), style: const TextStyle(fontSize: 15, height: 1.4)))],
                                ),
                              )
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    if (_diagnosisData!.containsKey('expert_treatment') && _diagnosisData!['expert_treatment']['chemical_pesticide'] != "None needed.") ...[
                      const SizedBox(height: 15),
                      Card(
                        color: const Color(0xFFFFF3E0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.orange.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.science, color: Colors.deepOrange),
                                  const SizedBox(width: 10),
                                  Text(t['treat']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                ]
                              ),
                              const Divider(),
                              Text("💡 ${_diagnosisData!['expert_treatment']['simple_advice']}", style: const TextStyle(fontSize: 15, height: 1.4)),
                              const SizedBox(height: 10),
                              Text("🧪 Chemical: ${_diagnosisData!['expert_treatment']['chemical_pesticide']} (${_diagnosisData!['expert_treatment']['dosage']})", style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Text("🌿 Organic: ${_diagnosisData!['expert_treatment']['organic_alternative']}", style: const TextStyle(fontSize: 15, height: 1.4)),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (_buyLink.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _launchURL,
                        icon: const Icon(Icons.shopping_cart, color: Colors.white),
                        label: Text(
                          _buyPrice == 'Varies' || _buyPrice.isEmpty 
                              ? 'Find Pesticides Online' 
                              : 'Buy Pesticide Now - $_buyPrice',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  } 
}

// ========================================================
// 3. MANDI PRICES SCREEN
// ========================================================
class MandiPricesScreen extends StatefulWidget { 
  const MandiPricesScreen({super.key});

  @override 
  State<MandiPricesScreen> createState() => _MandiPricesScreenState(); 
}

class _MandiPricesScreenState extends State<MandiPricesScreen> { 
  bool _isLoading = true; 
  Map<String, dynamic>? _marketData;

  final Map<String, dynamic> _fallbackData = { 
    "date": "Today", 
    "location": "Tezpur APMC Wholesale Market, Assam", 
    "commodities": [ 
      { "name": "Tomato", "variety": "Local / Hybrid", "min_price": 32, "max_price": 40, "trend": "up", "icon": "🍅" }, 
      { "name": "Potato", "variety": "Jyoti / Local", "min_price": 18, "max_price": 24, "trend": "stable", "icon": "🥔" } 
    ] 
  };

  @override void initState() { 
    super.initState(); 
    _fetchPrices(); 
  }

  Future<void> _fetchPrices() async { 
    try { 
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/mandi_prices')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        setState(() {
          _marketData = jsonDecode(response.body);
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _marketData = _fallbackData;
      _isLoading = false;
    });
  }

  @override 
  Widget build(BuildContext context) { 
    return Scaffold( 
      backgroundColor: const Color(0xFFF5F7F5), 
      appBar: AppBar( 
        title: const Text('Live Mandi Prices', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
        backgroundColor: const Color(0xFF2E7D32), 
        actions: [ 
          IconButton( 
            icon: const Icon(Icons.refresh, color: Colors.white), 
            onPressed: () { 
              setState(() => _isLoading = true); 
              _fetchPrices(); 
            }, 
          ) 
        ], 
      ), 
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))) 
          : Padding( 
              padding: const EdgeInsets.all(20.0), 
              child: Column( 
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [ 
                  Text(_marketData!['location'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)), 
                  const SizedBox(height: 4), 
                  Text("Market Date: ${_marketData!['date']}", style: TextStyle(fontSize: 15, color: Colors.grey.shade700)), 
                  const SizedBox(height: 20), 
                  Expanded( 
                    child: ListView.builder( 
                      itemCount: _marketData!['commodities'].length, 
                      itemBuilder: (context, index) { 
                        var item = _marketData!['commodities'][index]; 
                        return Card( 
                          elevation: 3, 
                          margin: const EdgeInsets.only(bottom: 16), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), 
                          child: Padding( 
                            padding: const EdgeInsets.all(20.0), 
                            child: Column( 
                              children: [ 
                                Row( 
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                                  children: [ 
                                    Row( 
                                      children: [ 
                                        Text(item['icon'], style: const TextStyle(fontSize: 32)), 
                                        const SizedBox(width: 14), 
                                        Column( 
                                          crossAxisAlignment: CrossAxisAlignment.start, 
                                          children: [ 
                                            Text(item['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), 
                                            Text("Variety: ${item['variety']}", style: TextStyle(color: Colors.grey.shade600)), 
                                          ], 
                                        ), 
                                      ], 
                                    ), 
                                    Icon( 
                                      item['trend'] == 'up' ? Icons.trending_up : Icons.trending_flat, 
                                      color: item['trend'] == 'up' ? Colors.green : Colors.orange, 
                                      size: 30, 
                                    ) 
                                  ], 
                                ), 
                                const Divider(height: 30), 
                                Row( 
                                  mainAxisAlignment: MainAxisAlignment.spaceAround, 
                                  children: [ 
                                    Column( 
                                      children: [ 
                                        const Text("Min Rate", style: TextStyle(color: Colors.grey, fontSize: 13)), 
                                        const SizedBox(height: 4), 
                                        Text("₹${item['min_price']} / kg", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)), 
                                      ], 
                                    ), 
                                    Column( 
                                      children: [ 
                                        const Text("Max Rate", style: TextStyle(color: Colors.grey, fontSize: 13)), 
                                        const SizedBox(height: 4), 
                                        Text("₹${item['max_price']} / kg", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)), 
                                      ], 
                                    ), 
                                  ], 
                                ) 
                              ], 
                            ), 
                          ), 
                        ); 
                      }, 
                    ), 
                  ) 
                ], 
              ), 
            ), 
    ); 
  } 
}

// ========================================================
// 4. KISAN SABHA (COMMUNITY HUB) WITH DELETE FEATURE
// ========================================================
class KisanPost {
  final int id;
  final String farmerName;
  final String description;
  final List<String> images;
  final List<dynamic> comments;

  KisanPost({
    required this.id,
    required this.farmerName,
    required this.description,
    required this.images,
    required this.comments,
  });
}

class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> {
  final ImagePicker _picker = ImagePicker();
  List<KisanPost> posts = [];
  bool _isLoading = true;
  final String _serverIp = 'http://127.0.0.1:8000'; 
  final Set<int> _expandedPosts = {};

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  void _toggleComments(int postId) {
    setState(() {
      if (_expandedPosts.contains(postId)) {
        _expandedPosts.remove(postId);
      } else {
        _expandedPosts.add(postId);
      }
    });
  }

  Future<void> _fetchPosts() async {
    try {
      final response = await http.get(Uri.parse('$_serverIp/forum/feed'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          int fallbackId = 0; 
          posts = (data['posts'] as List).map((p) {
            fallbackId++;
            return KisanPost(
              id: p['id'] ?? fallbackId, 
              farmerName: p['farmer_name'],
              description: p['description'],
              images: List<String>.from(p['images']),
              comments: p['comments'] ?? [],
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadPost(List<XFile> images, String description) async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_serverIp/forum/create_post'));
      request.fields['farmer_name'] = 'Farmer (Demo)';
      request.fields['description'] = description;

      for (var img in images) {
        final bytes = await img.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes('files', bytes, filename: img.name));
      }
      
      var response = await request.send();
      if (response.statusCode == 200) await _fetchPosts();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReply(int postId, String text) async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_serverIp/forum/add_comment'));
      request.fields['post_id'] = postId.toString();
      request.fields['author'] = 'Expert / Peer';
      request.fields['text'] = text;

      var response = await request.send();
      if (response.statusCode == 200) {
        await _fetchPosts();
        Future.delayed(const Duration(milliseconds: 100), () {
          setState(() {
            _expandedPosts.add(postId);
          });
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePost(int postId) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.delete(Uri.parse('$_serverIp/forum/delete_post/$postId'));
      if (response.statusCode == 200) {
        await _fetchPosts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete post.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection Error: Could not delete.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPostDialog(List<XFile> images) {
    final TextEditingController descController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Describe your field issue'),
        content: TextField(
          controller: descController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'What is happening to your crop?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (descController.text.isNotEmpty) {
                _uploadPost(images, descController.text);
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(int postId) {
    final TextEditingController replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Write a Reply'),
        content: TextField(
          controller: replyController,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Offer advice or a solution...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (replyController.text.isNotEmpty) {
                _submitReply(postId, replyController.text);
              }
            },
            child: const Text('Reply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text('Kisan Sabha', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final bool isExpanded = _expandedPosts.contains(post.id);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row with Delete Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(post.farmerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                            onPressed: () => _deletePost(post.id),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(post.description, style: const TextStyle(fontSize: 15, height: 1.4)),
                      const SizedBox(height: 12),
                      
                      if (post.images.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: PageView.builder(
                            itemCount: post.images.length,
                            itemBuilder: (context, imgIndex) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network('$_serverIp/${post.images[imgIndex]}', fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      const Divider(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () => _toggleComments(post.id),
                            icon: Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more, 
                              color: const Color(0xFF2E7D32)
                            ),
                            label: Text(
                              isExpanded ? 'Hide Replies' : 'Show Replies (${post.comments.length})', 
                              style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showReplyDialog(post.id),
                            icon: const Icon(Icons.reply, size: 20, color: Color(0xFF2E7D32)),
                            label: const Text('Reply', style: TextStyle(color: Color(0xFF2E7D32))),
                          ),
                        ],
                      ),

                      if (isExpanded) ...[
                        const SizedBox(height: 10),
                        if (post.comments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Text("No replies yet. Be the first to help!", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                          )
                        else
                          ...post.comments.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.person, size: 16, color: Color(0xFF2E7D32)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text("${c['author']}: ${c['text']}", style: const TextStyle(fontSize: 14))),
                                ],
                              ),
                            ),
                          )),
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final images = await _picker.pickMultiImage();
          if (images.isNotEmpty) _showPostDialog(images);
        },
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }
}