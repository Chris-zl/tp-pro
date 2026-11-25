import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

const violet = Color(0xFF7041A6);
const rose = Color(0xFFE7A4C7);
const fond = Color(0xFFFFF8FC);

const String baseUrl = 'http://localhost/api-test/public';

void main() {
  runApp(const ZawadiApp());
}

class ZawadiApp extends StatelessWidget {
  const ZawadiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CV Zawadi Christelle',
      theme: ThemeData(
        scaffoldBackgroundColor: fond,
        colorScheme: ColorScheme.fromSeed(
          seedColor: violet,
          primary: violet,
          secondary: rose,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: violet,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const ConnexionPage(),
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
      return 'Erreur réseau !($baseUrl) — $e';
    }
  }

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

  static Future<void> _attachImage(
    http.MultipartRequest request,
    XFile imageFile,
  ) async {
    final bytes = await imageFile.readAsBytes();
    final filename = imageFile.name.isNotEmpty ? imageFile.name : 'photo.jpg';
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: filename),
    );
  }

  // POST /famille-membres (JSON sans image, ou multipart/form-data avec image)
  static Future<String?> createMembre(
    MembreFamille membre,
    XFile? imageFile,
  ) async {
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
        await _attachImage(request, imageFile);

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
    MembreFamille membre,
    XFile? nouvelleImage,
  ) async {
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
        await _attachImage(request, nouvelleImage);

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

class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
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
        MaterialPageRoute(builder: (_) => const AccueilPage()),
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
        backgroundColor: fond,
        title: const Text(
          'Créer un compte',
          style: TextStyle(color: violet, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (max 100 car.)',
                prefixIcon: Icon(Icons.email, color: violet),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe (min 6 car.)',
                prefixIcon: Icon(Icons.lock, color: violet),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: violet)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: violet,
              foregroundColor: Colors.white,
            ),
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [violet, rose],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_pin, size: 88, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text(
                      'BIENVENUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Zawadi Lufungulo Christelle',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: fond,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email, color: violet),
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
                                prefixIcon:
                                    const Icon(Icons.lock, color: violet),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: violet,
                                  ),
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
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: violet,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: violet),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _seConnecter,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: violet,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Se connecter',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _isLoading ? null : _ouvrirInscription,
                              child: const Text(
                                'Créer un compte',
                                style: TextStyle(
                                  color: violet,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  int page = 0;

  final pages = const [CvPage(), FamillePage(), ContactPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fond,
      body: pages[page],
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (index) {
          setState(() {
            page = index;
          });
        },
        indicatorColor: rose.withValues(alpha: 0.3),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Mon CV',
          ),
          NavigationDestination(
            icon: Icon(Icons.family_restroom),
            label: 'Famille',
          ),
          NavigationDestination(
            icon: Icon(Icons.contact_phone),
            label: 'Contact',
          ),
        ],
      ),
    );
  }
}

class CvPage extends StatelessWidget {
  const CvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fond,
      appBar: AppBar(
        title: const Text(
          'Curriculum Vitae',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: violet,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [violet, rose],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/2.jpg',
                    width: 125,
                    height: 125,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 125,
                        height: 125,
                        color: Colors.white,
                        child: const Icon(
                          Icons.person,
                          size: 75,
                          color: violet,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'ZAWADI LUFUNGULO CHRISTELLE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Étudiante à l’ISIG',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          sectionTitre('INFORMATIONS PERSONNELLES'),
          info('Date de naissance', '05 janvier 2005'),
          info('Lieu de naissance', 'Kiliba'),
          info('Situation familiale', 'Non précisée'),
          sectionTitre('PARCOURS SCOLAIRE ET ACADÉMIQUE'),
          info('École maternelle', 'SOSUMO, Gihofi, Burundi'),
          info('École primaire', 'Montatos Orthodoxe'),
          info('École secondaire', 'Institut Mwanga d’Uvira'),
          info('Humanités', 'Institut Mwanga d’Uvira'),
          info('Université', 'ISIG'),
          sectionTitre('COMPÉTENCES'),
          const Text(
            'Les compétences professionnelles et informatiques '
            'seront ajoutées lorsque les informations seront disponibles.',
            style: TextStyle(fontSize: 15),
          ),
          sectionTitre('LANGUES'),
          const Text(
            'Les langues parlées seront précisées.',
            style: TextStyle(fontSize: 15),
          ),
          sectionTitre('CENTRES D’INTÉRÊT'),
          const Text(
            'Informations à compléter.',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              '© Zawadi Lufungulo Christelle',
              style: TextStyle(color: violet, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
    XFile? pickedImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: fond,
          title: Text(
            existant == null ? 'Ajouter un membre' : 'Modifier un membre',
            style: const TextStyle(color: violet, fontWeight: FontWeight.bold),
          ),
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
                      hintText: '1970-05-12',
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
                          style: const TextStyle(fontSize: 12, color: violet),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.photo_library,
                            size: 18, color: violet),
                        label: const Text('Choisir',
                            style: TextStyle(color: violet)),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                          );
                          if (file != null) {
                            setDialogState(() => pickedImage = file);
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
              child: const Text('Annuler', style: TextStyle(color: violet)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: violet,
                foregroundColor: Colors.white,
              ),
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
        backgroundColor: rose.withValues(alpha: 0.4),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: rose.withValues(alpha: 0.4),
      child: const Icon(Icons.person, color: violet),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fond,
      appBar: AppBar(
        title: const Text('Ma famille', style: TextStyle(color: Colors.white)),
        backgroundColor: violet,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _charger,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [violet, rose]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                children: [
                  Icon(Icons.family_restroom, color: Colors.white, size: 65),
                  SizedBox(height: 10),
                  Text(
                    'MA FAMILLE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: violet)),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: violet,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _charger,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              )
            else if (_membres.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  'Aucun membre enregistré sur le serveur. Appuyez sur + pour ajouter.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._membres.map(
                (m) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      _avatar(m),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.nomComplet,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              m.parente,
                              style: const TextStyle(color: violet),
                            ),
                            if (m.lieuNaissance.isNotEmpty ||
                                m.dateNaissance.isNotEmpty)
                              Text(
                                '${m.lieuNaissance} • ${m.dateNaissance}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: violet),
                        onPressed: () => _ouvrirFormulaire(existant: m),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _supprimer(m),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Column(
                children: [
                  Icon(Icons.store, color: violet, size: 35),
                  SizedBox(height: 8),
                  Text(
                    'Profession des parents',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  Text('Commerçants', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 15),
                  Icon(Icons.person_outline, color: violet, size: 30),
                  Text(
                    'Fille unique',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  Text('Pas de frères ni de sœurs'),
                ],
              ),
            ),
            const SizedBox(height: 70),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: violet,
        foregroundColor: Colors.white,
        onPressed: () => _ouvrirFormulaire(),
        child: const Icon(Icons.add),
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
    return Scaffold(
      backgroundColor: fond,
      appBar: AppBar(
        title: const Text(
          'Me contacter',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: violet,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ClipOval(
              child: Image.asset(
                'assets/2.jpg',
                width: 110,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 110,
                    height: 110,
                    color: rose,
                    child: const Icon(
                      Icons.person,
                      size: 65,
                      color: violet,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 15),
          const SizedBox(height: 15),
          const Text(
            'Zawadi Lufungulo Christelle',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: violet,
            ),
          ),
          const SizedBox(height: 25),
          InkWell(
            onTap: () => _open(context, 'tel:+243974602407'),
            child: info('Téléphone', '+243 974 602 407'),
          ),
          info('Facebook', 'Zawadi Chris'),
          info('TikTok', 'Chris'),
          info('Lieu de naissance', 'Kiliba'),
        ],
      ),
    );
  }
}

Widget sectionTitre(String titre) {
  return Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(
      titre,
      style: const TextStyle(
        color: violet,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget info(String titre, String valeur) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titre,
          style: const TextStyle(color: violet, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(valeur, style: const TextStyle(fontSize: 15)),
      ],
    ),
  );
}