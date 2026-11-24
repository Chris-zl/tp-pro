import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

const String baseUrl = 'http://172.20.10.7/api-test/public';

void main() {
  runApp(const MonCvApp());
}

class MonCvApp extends StatelessWidget {
  const MonCvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 219, 101, 180),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 219, 101, 180),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class MembreFamille {
  final String? id;
  final String nom;
  final String postnom;
  final String prenom;
  final String lieuNaissance;
  final String dateNaissance;
  final String? image;
  final String? imageUrl;
  final String parente;

  MembreFamille({
    this.id,
    required this.nom,
    required this.postnom,
    required this.prenom,
    required this.lieuNaissance,
    required this.dateNaissance,
    this.image,
    this.imageUrl,
    required this.parente,
  });

  String get nomComplet {
    final parts = [nom, postnom, prenom]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'Membre' : parts.join(' ');
  }

  String? get resolvedImageUrl {
    if (imageUrl != null &&
        imageUrl!.trim().isNotEmpty &&
        imageUrl!.trim() != 'null') {
      return imageUrl!.trim();
    }
    if (image != null && image!.trim().isNotEmpty && image!.trim() != 'null') {
      final clean = image!.trim();
      if (clean.startsWith('http://') || clean.startsWith('https://')) {
        return clean;
      }
      final path = clean.startsWith('/') ? clean.substring(1) : clean;
      return '$baseUrl/$path';
    }
    return null;
  }

  factory MembreFamille.fromJson(Map<String, dynamic> json) {
    return MembreFamille(
      id: json['id']?.toString(),
      nom: json['nom']?.toString() ?? '',
      postnom: json['postnom']?.toString() ?? '',
      prenom: json['prenom']?.toString() ?? '',
      lieuNaissance: json['lieu_naissance']?.toString() ?? '',
      dateNaissance: json['date_naissance']?.toString() ?? '',
      image: json['image']?.toString(),
      imageUrl: json['image_url']?.toString(),
      parente: json['parente']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nom': nom.trim(),
      'postnom': postnom.trim(),
      'prenom': prenom.trim(),
      'lieu_naissance': lieuNaissance.trim(),
      'date_naissance': dateNaissance.trim(),
      'parente': parente.trim(),
    };
  }
}

class ApiService {
  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static String _extractError(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final msg = decoded['message']?.toString() ?? fallback;
        if (decoded['errors'] is Map) {
          final errs = (decoded['errors'] as Map)
              .values
              .map((v) => v.toString())
              .join(' • ');
          return '$msg ($errs)';
        }
        return msg;
      }
    } catch (_) {}
    return '$fallback (HTTP ${response.statusCode})';
  }

  // POST /accounts/login
  static Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/accounts/login'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return null;
        }
      }
      return _extractError(response, 'Email ou mot de passe incorrect');
    } catch (e) {
      return 'Erreur réseau : vérifiez XAMPP et l’IP ($baseUrl) — $e';
    }
  }

  // POST /accounts/register
  static Future<String?> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/accounts/register'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return null;
        }
      }
      return _extractError(response, 'Échec de création du compte');
    } catch (e) {
      return 'Erreur réseau : vérifiez XAMPP et l’IP ($baseUrl) — $e';
    }
  }

  // GET /famille-membres
  static Future<List<MembreFamille>> getMembres() async {
    final response = await http.get(
      Uri.parse('$baseUrl/famille-membres'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final rawList = decoded is Map<String, dynamic>
          ? (decoded['data'] ?? [])
          : (decoded is List ? decoded : []);
      return (rawList as List)
          .map((item) => MembreFamille.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    throw Exception(_extractError(response, 'Impossible de charger la famille'));
  }

  // POST /famille-membres (JSON sans image, ou multipart/form-data avec image)
  static Future<String?> createMembre(
      MembreFamille membre, File? imageFile) async {
    try {
      if (imageFile == null) {
        final response = await http.post(
          Uri.parse('$baseUrl/famille-membres'),
          headers: _jsonHeaders,
          body: jsonEncode(membre.toJson()),
        );
        if (response.statusCode == 201 || response.statusCode == 200) {
          return null;
        }
        return _extractError(response, 'Erreur lors de la création');
      } else {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/famille-membres'),
        );
        request.headers['Accept'] = 'application/json';
        request.fields.addAll({
          'nom': membre.nom.trim(),
          'postnom': membre.postnom.trim(),
          'prenom': membre.prenom.trim(),
          'lieu_naissance': membre.lieuNaissance.trim(),
          'date_naissance': membre.dateNaissance.trim(),
          'parente': membre.parente.trim(),
        });
        request.files
            .add(await http.MultipartFile.fromPath('image', imageFile.path));

        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode == 201 || response.statusCode == 200) {
          return null;
        }
        return _extractError(response, 'Erreur lors de la création avec image');
      }
    } catch (e) {
      return 'Erreur réseau : $e';
    }
  }

  // PUT /famille-membres/{id} (JSON sans changer l'image)
  // ou POST /famille-membres/{id} (multipart/form-data pour changer l'image)
  static Future<String?> updateMembre(
      MembreFamille membre, File? nouvelleImage) async {
    if (membre.id == null) return 'ID manquant';
    try {
      if (nouvelleImage == null) {
        final response = await http.put(
          Uri.parse('$baseUrl/famille-membres/${membre.id}'),
          headers: _jsonHeaders,
          body: jsonEncode(membre.toJson()),
        );
        if (response.statusCode == 200) return null;
        return _extractError(response, 'Erreur lors de la modification');
      } else {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/famille-membres/${membre.id}'),
        );
        request.headers['Accept'] = 'application/json';
        request.fields.addAll({
          'nom': membre.nom.trim(),
          'postnom': membre.postnom.trim(),
          'prenom': membre.prenom.trim(),
          'lieu_naissance': membre.lieuNaissance.trim(),
          'date_naissance': membre.dateNaissance.trim(),
          'parente': membre.parente.trim(),
        });
        request.files
            .add(await http.MultipartFile.fromPath('image', nouvelleImage.path));

        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode == 200 || response.statusCode == 201) {
          return null;
        }
        return _extractError(
            response, 'Erreur lors de la modification avec image');
      }
    } catch (e) {
      return 'Erreur réseau : $e';
    }
  }

  // DELETE /famille-membres/{id}
  static Future<String?> deleteMembre(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/famille-membres/$id'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return null;
      }
      return _extractError(response, 'Erreur lors de la suppression');
    } catch (e) {
      return 'Erreur réseau : $e';
    }
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final err = await ApiService.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (err == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    }
  }

  void _ouvrirInscription() {
    final emailCtrl = TextEditingController(text: _emailController.text);
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Créer un compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (max 100 car.)',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe (min 6 car.)',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              final pass = passCtrl.text;
              if (email.isEmpty || pass.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Email obligatoire et mot de passe d’au moins 6 caractères.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final err = await ApiService.register(email, pass);
              if (!mounted) return;
              setState(() => _isLoading = false);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      err ?? 'Compte créé ! Vous pouvez maintenant vous connecter.'),
                  backgroundColor: err == null ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: Color.fromARGB(255, 219, 101, 180),
                      child:
                          Icon(Icons.lock_person, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Connexion',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 219, 101, 180),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Mon CV',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Identifiant (Email)',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Entrez votre email'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Entrez votre mot de passe'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _seConnecter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 219, 101, 180),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Se connecter',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isLoading ? null : _ouvrirInscription,
                      child: const Text('Créer un compte'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    CvHomePage(),
    FamillePage(),
    ContactPage(),
  ];

  final List<String> _titles = const [
    'Mon CV',
    'Famille',
    'Contact',
  ];

  void _deconnexion() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: _deconnexion,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Color.fromARGB(255, 219, 101, 180)),
              accountName: Text(
                'ZAWADI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text('Étudiant - ISIG'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  'NM',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 219, 101, 180),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('Accueil (CV)'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom),
              title: const Text('Famille'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone),
              title: const Text('Contact'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title:
                  const Text('Déconnexion', style: TextStyle(color: Colors.red)),
              onTap: _deconnexion,
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromARGB(255, 219, 101, 180),
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.badge), label: 'CV'),
          BottomNavigationBarItem(
              icon: Icon(Icons.family_restroom), label: 'Famille'),
          BottomNavigationBarItem(
              icon: Icon(Icons.contact_mail), label: 'Contact'),
        ],
      ),
    );
  }
}

class CvHomePage extends StatelessWidget {
  const CvHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: Color.fromARGB(255, 219, 101, 180),
                  child: Text(
                    'NM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'zawadi christelle',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 219, 101, 180),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('Développeur Mobile & Étudiant en Informatique',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Né le 05/01/2005 à Kiliba',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _sectionTitle('Profil'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Né le 5 janvier 2005 à Kiliba. J’ai grandi au Burundi à Sosumo, effectué mon parcours scolaire à Gihofi (Sosumo), Montatos Orthodoxe, à l’Institut Mwanga d’Uvira (secondaire et humanités), puis poursuivi mes études universitaires à l’ISIG.',
            ),
          ),
        ),
        const SizedBox(height: 14),
        _sectionTitle('Formation'),
        const Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.school, color: Color.fromARGB(255, 219, 101, 180)),
                title: Text('Université'),
                subtitle: Text('ISIG'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.school, color: Color.fromARGB(255, 219, 101, 180)),
                title: Text('Secondaire & Humanités'),
                subtitle: Text('Institut Mwanga d’Uvira'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.school, color: Color.fromARGB(255, 219, 101, 180)),
                title: Text('École primaire'),
                subtitle: Text('Montatos Orthodoxe (Sosumo, Burundi)'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.school, color: Color.fromARGB(255, 219, 101, 180)),
                title: Text('École maternelle'),
                subtitle: Text('Gihofi — Sosumo (Burundi)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionTitle('Expériences & Projets'),
        const Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.phone_android, color: Colors.teal),
                title: Text('Application Mobile CV & Famille (Flutter)'),
                subtitle: Text(
                    'Authentification et gestion dynamique de la famille via API REST.'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.code, color: Colors.teal),
                title: Text('Projets Académiques'),
                subtitle: Text('Développement logiciel et bases de données.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionTitle('Compétences'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Techniques :', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text('Flutter & Dart')),
                    Chip(label: Text('API REST')),
                    Chip(label: Text('MySQL')),
                    Chip(label: Text('Git & GitHub')),
                  ],
                ),
                SizedBox(height: 10),
                Text('Linguistiques :',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text('Français')),
                    Chip(label: Text('Swahili')),
                    Chip(label: Text('Kirundi')),
                    Chip(label: Text('Anglais')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _sectionTitle('Centres d’intérêt'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(label: Text('Programmation')),
                Chip(label: Text('Football')),
                Chip(label: Text('Musique')),
                Chip(label: Text('Lecture')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 219, 101, 180),
        ),
      ),
    );
  }
}

class FamillePage extends StatefulWidget {
  const FamillePage({super.key});

  @override
  State<FamillePage> createState() => _FamillePageState();
}

class _FamillePageState extends State<FamillePage> {
  List<MembreFamille> _membres = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getMembres();
      if (!mounted) return;
      setState(() {
        _membres = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _ouvrirFormulaire({MembreFamille? existant}) {
    final formKey = GlobalKey<FormState>();
    final nomCtrl = TextEditingController(text: existant?.nom ?? '');
    final postnomCtrl = TextEditingController(text: existant?.postnom ?? '');
    final prenomCtrl = TextEditingController(text: existant?.prenom ?? '');
    final lieuCtrl = TextEditingController(text: existant?.lieuNaissance ?? '');
    final dateCtrl = TextEditingController(text: existant?.dateNaissance ?? '');
    final parenteCtrl = TextEditingController(text: existant?.parente ?? '');
    File? pickedImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existant == null ? 'Ajouter un membre' : 'Modifier'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomCtrl,
                    decoration: const InputDecoration(labelText: 'Nom *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  TextFormField(
                    controller: postnomCtrl,
                    decoration: const InputDecoration(labelText: 'Postnom *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  TextFormField(
                    controller: prenomCtrl,
                    decoration: const InputDecoration(labelText: 'Prénom *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  TextFormField(
                    controller: lieuCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Lieu de naissance *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  TextFormField(
                    controller: dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Date naissance (AAAA-MM-JJ) *',
                      hintText: '1975-05-12',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  TextFormField(
                    controller: parenteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Parenté (Père, Mère, Frère...) *',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pickedImage != null
                              ? 'Image choisie'
                              : 'Image : facultative',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Choisir'),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                          );
                          if (file != null) {
                            setDialogState(() => pickedImage = File(file.path));
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final membre = MembreFamille(
                  id: existant?.id,
                  nom: nomCtrl.text,
                  postnom: postnomCtrl.text,
                  prenom: prenomCtrl.text,
                  lieuNaissance: lieuCtrl.text,
                  dateNaissance: dateCtrl.text,
                  parente: parenteCtrl.text,
                );

                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                final err = existant == null
                    ? await ApiService.createMembre(membre, pickedImage)
                    : await ApiService.updateMembre(membre, pickedImage);

                if (!mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: Colors.red),
                  );
                }
                await _charger();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _supprimer(MembreFamille m) async {
    if (m.id == null) return;
    setState(() => _isLoading = true);
    final err = await ApiService.deleteMembre(m.id!);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    }
    await _charger();
  }

  Widget _avatar(MembreFamille m) {
    final url = m.resolvedImageUrl;
    if (url != null) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return const CircleAvatar(
      radius: 26,
      backgroundColor: Color.fromARGB(255, 219, 101, 180),
      child: Icon(Icons.person, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _charger,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _charger,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _membres.isEmpty
                    ? const Center(child: Text('Aucun membre enregistré.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _membres.length,
                        itemBuilder: (context, i) {
                          final m = _membres[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: _avatar(m),
                              title: Text(
                                m.nomComplet,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${m.parente} • Né(e) à ${m.lieuNaissance} (${m.dateNaissance})',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () =>
                                        _ouvrirFormulaire(existant: m),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _supprimer(m),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(),
        backgroundColor: const Color.fromARGB(255, 219, 101, 180),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’ouvrir $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.phone, color: Colors.green),
            title: const Text('Téléphone'),
            subtitle: const Text('+243974602407'),
            onTap: () => _open(context, 'tel:+243974602407'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.email, color: Colors.red),
            title: const Text('E-mail'),
            subtitle: const Text('zawadilufungulochristelle@g,mail.com'),
            onTap: () => _open(context, 'mailto:zadi.lufungulochristelle@example.com'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.location_on, color: Colors.orange),
            title: Text('Adresse'),
            subtitle: Text('Goma, Nord-Kivu, RDC'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub'),
            subtitle: const Text('github.com/Chris-zl'),
            onTap: () =>
                _open(context, 'https://github.com/Chris-zl'),
          ),
        ),
      ],
    );
  }
}