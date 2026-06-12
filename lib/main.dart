import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  // Uma lista local na memória para simular o banco de dados por enquanto
  final List<Map<String, String>> _minhaColecao = [];

  void _adicionarCarta() {
    final String nome = _nomeController.text.trim();
    final String numero = _numeroController.text.trim();

    if (nome.isNotEmpty && numero.isNotEmpty) {
      setState(() {
        _minhaColecao.add({'nome': nome, 'numero': numero});
      });

      // Limpa os campos depois de salvar
      _nomeController.clear();
      _numeroController.clear();

      // Fecha o teclado virtual
      FocusScope.of(context).unfocus();
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
            Expanded(
              child: _minhaColecao.isEmpty
                  ? const Center(child: Text('Nenhuma carta adicionada ainda.'))
                  : ListView.builder(
                      itemCount: _minhaColecao.length,
                      itemBuilder: (context, index) {
                        final carta = _minhaColecao[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.style, color: Colors.red),
                            title: Text(carta['nome'] ?? ''),
                            subtitle: Text('Número: ${carta['numero']}'),
                          ),
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
