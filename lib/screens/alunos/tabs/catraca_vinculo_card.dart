import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/app_user.dart';
import '../../../models/catraca.dart';
import '../../../services/acesso_service.dart';
import '../../../theme/app_colors.dart';

/// Parte "Catraca" da ficha do aluno: qual código do leitor facial
/// (iDFace) é este aluno. Fluxo: a recepção cadastra o rosto no próprio
/// aparelho, o aparelho dá um número ao aluno, e esse número é informado
/// aqui. Sem vínculo, o porteiro não sabe quem é e a catraca não libera.
class CatracaVinculoCard extends StatefulWidget {
  const CatracaVinculoCard({
    super.key,
    required this.alunoUid,
    required this.acessoService,
    required this.staffAtual,
  });

  final String alunoUid;
  final AcessoService acessoService;
  final AppUser staffAtual;

  @override
  State<CatracaVinculoCard> createState() => _CatracaVinculoCardState();
}

class _CatracaVinculoCardState extends State<CatracaVinculoCard> {
  late Future<CatracaDoAluno> _catraca = widget.acessoService.carregarCatraca(widget.alunoUid);

  void _recarregar() {
    // Corpo em bloco de propósito: `setState(() => _catraca = ...)`
    // devolveria o Future, e o Flutter recusa callback de setState que
    // devolve Future.
    setState(() {
      _catraca = widget.acessoService.carregarCatraca(widget.alunoUid);
    });
  }

  void _erro(Object erro) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(erro is AcessoServiceException ? erro.message : 'Erro ao salvar. Tente novamente.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _vincular(List<DispositivoAcesso> dispositivos) async {
    final resultado = await showDialog<(DispositivoAcesso, String)>(
      context: context,
      builder: (_) => _DialogoVincular(dispositivos: dispositivos),
    );
    if (resultado == null) return;
    final (dispositivo, codigo) = resultado;
    try {
      await widget.acessoService.vincularCodigo(
        dispositivoId: dispositivo.id,
        codigo: codigo,
        alunoUid: widget.alunoUid,
        staff: widget.staffAtual,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Código $codigo vinculado no leitor ${dispositivo.nome}.')),
        );
      }
      _recarregar();
    } catch (erro) {
      _erro(erro);
    }
  }

  Future<void> _desvincular(VinculoCatraca vinculo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvincular código?'),
        content: Text(
          'O código ${vinculo.codigo} deixa de ser este aluno, e a catraca para de liberar '
          'para ele. Lembre de apagar o rosto no próprio leitor também, se for o caso.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('DESVINCULAR')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.acessoService.desvincularCodigo(
        dispositivoId: vinculo.dispositivo.id,
        codigo: vinculo.codigo,
      );
      _recarregar();
    } catch (erro) {
      _erro(erro);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: FutureBuilder<CatracaDoAluno>(
        future: _catraca,
        builder: (context, snapshot) {
          final titulo = Row(
            children: [
              Icon(Icons.sensor_door_outlined, color: AppColors.gold),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Catraca', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          );
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(children: [titulo, const SizedBox(height: 12), const LinearProgressIndicator()]);
          }
          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titulo,
                const SizedBox(height: 8),
                Text('Erro ao carregar a catraca.', style: TextStyle(color: AppColors.error)),
              ],
            );
          }
          final dados = snapshot.data!;
          final secundario = TextStyle(color: AppColors.textSecondary, fontSize: 13);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo,
              const SizedBox(height: 8),
              if (dados.dispositivos.isEmpty)
                Text(
                  'Nenhum leitor cadastrado ainda. O leitor é cadastrado no computador '
                  'da academia (guia do porteiro, passo 6).',
                  style: secundario,
                )
              else ...[
                if (dados.vinculos.isEmpty)
                  Text(
                    'Ainda não vinculado ao leitor — a catraca não vai liberar. Cadastre o '
                    'rosto no leitor e informe aqui o código que ele der ao aluno.',
                    style: TextStyle(color: AppColors.gold, fontSize: 13),
                  )
                else
                  for (final vinculo in dados.vinculos)
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: const Color(0xFF4CAF6D), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dados.dispositivos.length == 1
                                ? 'Código ${vinculo.codigo}'
                                : 'Código ${vinculo.codigo} · ${vinculo.dispositivo.nome}',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Desvincular',
                          icon: Icon(Icons.link_off, color: AppColors.textSecondary),
                          onPressed: () => _desvincular(vinculo),
                        ),
                      ],
                    ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _vincular(dados.dispositivos),
                    icon: const Icon(Icons.add_link),
                    label: const Text('VINCULAR CÓDIGO'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DialogoVincular extends StatefulWidget {
  const _DialogoVincular({required this.dispositivos});

  final List<DispositivoAcesso> dispositivos;

  @override
  State<_DialogoVincular> createState() => _DialogoVincularState();
}

class _DialogoVincularState extends State<_DialogoVincular> {
  final _formKey = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  late String _dispositivoId = widget.dispositivos.first.id;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;
    final dispositivo = widget.dispositivos.firstWhere((d) => d.id == _dispositivoId);
    Navigator.of(context).pop((dispositivo, _codigo.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vincular código do leitor'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.dispositivos.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: _dispositivoId,
                decoration: const InputDecoration(labelText: 'Leitor'),
                items: [
                  for (final d in widget.dispositivos) DropdownMenuItem(value: d.id, child: Text(d.nome)),
                ],
                onChanged: (id) => setState(() => _dispositivoId = id ?? _dispositivoId),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _codigo,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Código no leitor',
                helperText: 'O número que o leitor deu ao aluno',
              ),
              validator: validarCodigoCatraca,
              onFieldSubmitted: (_) => _salvar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCELAR')),
        TextButton(onPressed: _salvar, child: const Text('VINCULAR')),
      ],
    );
  }
}
