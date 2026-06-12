import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  // Controladores para capturar o que o usuário digita
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();

  final _supabase = Supabase.instance.client;

  bool _carregandoApi = false;

  Future<void> _buscarCartaPorNumero() async {
    String textoDigitado = _numeroController.text.trim();

    if (textoDigitado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o número da carta primeiro!')),
      );
      return;
    }

    String numeroCarta = textoDigitado;
    String? totalColecao;

    // Se o usuário digitou com barra (ex: 087/217)
    if (textoDigitado.contains('/')) {
      final partes = textoDigitado.split('/');
      numeroCarta = partes.first.trim();
      totalColecao = partes.last.trim(); // Guarda o '217'
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
        // pegamos a primeira carta da lista como plano de fundo
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
            const SnackBar(
              content: Text('Nenhuma carta encontrada na API com esse número.'),
            ),
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
        // Faz o INSERT na tabela 'cartas' do Supabase
        await _supabase.from('cartas').insert({'nome': nome, 'numero': numero});

        // Se deu certo, mostra um aviso na tela
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Carta adicionada com sucesso no Supabase!'),
            ),
          );
        }

        // Limpa os campos e fecha o teclado
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
            // Campo: Nome do Pokémon
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome do Pokémon (ex: Charizard)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Campo: Número da Carta
            TextField(
              controller: _numeroController,
              decoration: const InputDecoration(
                labelText: 'Número da Carta (ex: 151/165)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _carregandoApi ? null : _buscarCartaPorNumero,
              icon: _carregandoApi
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(
                _carregandoApi ? 'Buscando na API...' : 'Buscar Nome da Carta',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(45),
              ),
            ),
            const SizedBox(height: 16),

            // Botão Salvar
            ElevatedButton.icon(
              onPressed: _adicionarCarta,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar à Coleção'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Cartas na Minha Pasta:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Lista que mostra as cartas adicionadas
            // Lista em tempo real conectada ao Supabase
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                // Dizemos ao Supabase para "ouvir" a tabela 'cartas' em tempo real
                stream: _supabase.from('cartas').stream(primaryKey: ['id']),
                builder: (context, snapshot) {
                  // Se o banco ainda estiver carregando os dados
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Se houver algum erro na conexão
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Erro ao carregar cartas: ${snapshot.error}'),
                    );
                  }

                  final cartas = snapshot.data ?? [];

                  // Se o banco estiver vazio
                  if (cartas.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma carta na sua coleção ainda.'),
                    );
                  }

                  // Se tiver cartas, desenha a lista na tela
                  return ListView.builder(
                    itemCount: cartas.length,
                    itemBuilder: (context, index) {
                      final carta = cartas[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.style, color: Colors.red),
                          title: Text(carta['nome'] ?? 'Sem nome'),
                          subtitle: Text('Número: ${carta['numero'] ?? 'S/N'}'),
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
