import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa as câmeras do aparelho
  try {
    cameras = await availableCameras();
  } catch (e) {
    print("Erro ao inicializar câmeras: $e");
  }

  await dotenv.load(fileName: ".env");

  // Inicializa o Supabase usando as variáveis de ambiente
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const PokeTcgApp());
}

class PokeTcgApp extends StatelessWidget {
  const PokeTcgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokémon TCG Manager',
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _carregandoApi = false;

  Future<void> _buscarCartaPorNumero() async {
    String textoDigitado = _numeroController.text.trim();

    if (textoDigitado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite ou escaneie o número primeiro!')),
      );
      return;
    }

    String numeroCarta = textoDigitado;
    String? totalColecao;

    // Se o usuário digitou com barra (ex: 087/217)
    if (textoDigitado.contains('/')) {
      final partes = textoDigitado.split('/');
      numeroCarta = partes.first.trim();
      totalColecao = partes.last.trim();
    }

    // Remove os zeros à esquerda do número da carta (ex: 087 -> 87)
    numeroCarta = numeroCarta.replaceFirst(RegExp(r'^0+'), '');
    if (numeroCarta.isEmpty) numeroCarta = '0';

    setState(() {
      _carregandoApi = true;
    });

    try {
      final dio = Dio();

      // Buscamos na API apenas pelo número puro
      final response = await dio.get(
        'https://api.pokemontcg.io/v2/cards',
        queryParameters: {'q': 'number:$numeroCarta'},
      );

      final listaDeCartas = response.data['data'] as List;

      if (listaDeCartas.isNotEmpty) {
        Map<String, dynamic>? cartaEncontrada;

        // Se o usuário informou o total da coleção (ex: 217), filtramos na lista retornada
        if (totalColecao != null) {
          for (var carta in listaDeCartas) {
            // Convertemos para String para garantir a comparação correta
            final totalNaApi = carta['set']?['printedTotal']?.toString();
            if (totalNaApi == totalColecao) {
              cartaEncontrada = carta as Map<String, dynamic>;
              break;
            }
          }
        }

        // Se o usuário não digitou a barra, ou se o filtro por total falhou,
        // pegamos a primeira carta da lista
        cartaEncontrada ??= listaDeCartas.first as Map<String, dynamic>;
        final String nomePokemon = cartaEncontrada['name'];

        setState(() {
          _nomeController.text = nomePokemon;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Carta encontrada: $nomePokemon!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhuma carta encontrada na API.')),
          );
        }
      }
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na busca: $erro'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _carregandoApi = false;
      });
    }
  }

  Future<void> _adicionarCarta() async {
    final String nome = _nomeController.text.trim();
    final String numero = _numeroController.text.trim();

    if (nome.isNotEmpty && numero.isNotEmpty) {
      try {
        await _supabase.from('cartas').insert({'nome': nome, 'numero': numero});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Carta adicionada com sucesso!')),
          );
        }

        _nomeController.clear();
        _numeroController.clear();
        FocusScope.of(context).unfocus();
      } catch (erro) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar: $erro'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Função que abre a tela da câmera e recebe o número escaneado de volta
  Future<void> _abrirScanner() async {
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma câmera encontrada no dispositivo.'),
        ),
      );
      return;
    }

    final resultadoScan = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(camera: cameras.first),
      ),
    );

    if (resultadoScan != null && mounted) {
      setState(() {
        _numeroController.text = resultadoScan;
      });
      // Já dispara a busca na API automaticamente após scannear!
      _buscarCartaPorNumero();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Coleção Pokémon'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome do Pokémon',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Campo de número com o botão de Câmera embutido!
            TextField(
              controller: _numeroController,
              decoration: InputDecoration(
                labelText: 'Número da Carta (ex: 087/217)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.red),
                  onPressed: _abrirScanner,
                ),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _carregandoApi ? null : _buscarCartaPorNumero,
              icon: _carregandoApi
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_carregandoApi ? 'Buscando...' : 'Buscar Nome'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(45),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _adicionarCarta,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar à Coleção'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabase.from('cartas').stream(primaryKey: ['id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(child: Text('Erro: ${snapshot.error}'));
                  final cartas = snapshot.data ?? [];
                  if (cartas.isEmpty)
                    return const Center(
                      child: Text('Nenhuma carta adicionada.'),
                    );

                  return ListView.builder(
                    itemCount: cartas.length,
                    itemBuilder: (context, index) {
                      final carta = cartas[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.style, color: Colors.red),
                          title: Text(carta['nome'] ?? ''),
                          subtitle: Text('Número: ${carta['numero']}'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TELA DA CÂMERA COM RECONHECIMENTO DE TEXTO (OCR) ---
class ScannerScreen extends StatefulWidget {
  final CameraDescription camera;
  const ScannerScreen({super.key, required this.camera});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _cameraController.initialize();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _escanearImagem() async {
    if (_processando) return;

    setState(() {
      _processando = true;
    });

    try {
      await _initializeControllerFuture;
      // Tira uma foto temporária
      final imagem = await _cameraController.takePicture();

      // Converte a foto para o formato que o ML Kit entende
      final inputImage = InputImage.fromFilePath(imagem.path);

      // Roda a IA de leitura de texto
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      // Padrão Regex para encontrar formatos tipo "087/217" ou "151/165"
      final RegExp regexNumeroPokemon = RegExp(r'\d+/\d+');
      String? numeroEncontrado;

      // Percorre as linhas de texto encontradas pela câmera
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          if (regexNumeroPokemon.hasMatch(line.text)) {
            numeroEncontrado = regexNumeroPokemon.stringMatch(line.text);
            break;
          }
        }
        if (numeroEncontrado != null) break;
      }

      if (numeroEncontrado != null && mounted) {
        // Devolve o número encontrado para a tela anterior
        Navigator.pop(context, numeroEncontrado);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não encontramos o número da carta. Aproxime mais o canto inferior!',
              ),
            ),
          );
        }
      }
    } catch (e) {
      print("Erro ao scannear: $e");
    } finally {
      if (mounted) {
        setState(() {
          _processando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aponte para o número da carta'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_cameraController),
                if (_processando)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _escanearImagem,
        backgroundColor: Colors.red,
        child: const Icon(Icons.camera, size: 40, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
