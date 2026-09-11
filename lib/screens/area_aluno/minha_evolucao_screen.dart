import 'package:flutter/material.dart';

import '../../constants/circunferencia_fields.dart';
import '../../models/avaliacao_fisica.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';

/// Evolução das avaliações físicas do aluno ao longo do tempo — peso,
/// IMC (calculado) e circunferências, sempre a partir dos mesmos dados
/// de `AvaliacaoFisica` (nunca inventa %gordura/massa muscular, que
/// não existem no modelo atual). Só calcula uma evolução quando há
/// pelo menos 2 avaliações com aquele campo preenchido — com 1 só ou
/// nenhuma, mostra estado vazio em vez de "0% de evolução".
class MinhaEvolucaoScreen extends StatefulWidget {
  const MinhaEvolucaoScreen({super.key, required this.uid, required this.alunoService});

  final String uid;
  final AlunoService alunoService;

  @override
  State<MinhaEvolucaoScreen> createState() => _MinhaEvolucaoScreenState();
}

class _MinhaEvolucaoScreenState extends State<MinhaEvolucaoScreen> {
  String? _circunferenciaSelecionada;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minha evolução')),
      body: SafeArea(
        child: StreamBuilder<List<AvaliacaoFisica>>(
          stream: widget.alunoService.watchAvaliacoes(widget.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Mais antiga primeiro pra desenhar a evolução na ordem certa —
            // watchAvaliacoes() devolve mais recente primeiro, então inverte.
            final avaliacoes = (snapshot.data ?? []).reversed.toList();
            if (avaliacoes.length < 2) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    avaliacoes.isEmpty
                        ? 'Você ainda não possui uma avaliação física cadastrada.'
                        : 'Você tem só 1 avaliação registrada — a evolução aparece a '
                              'partir da segunda.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            final pesoPontos = _pontosDe(avaliacoes, (a) => a.pesoKg);
            final imcPontos = _pontosDe(avaliacoes, (a) => a.imc);

            final circunferenciasDisponiveis = circunferenciaFields
                .where(
                  (campo) =>
                      avaliacoes.where((a) => a.circunferenciasCm[campo.key] != null).length >= 2,
                )
                .toList();
            final chaveSelecionada =
                _circunferenciaSelecionada ??
                (circunferenciasDisponiveis.isEmpty ? null : circunferenciasDisponiveis.first.key);
            final circunferenciaPontos = chaveSelecionada == null
                ? const <_Ponto>[]
                : _pontosDe(avaliacoes, (a) => a.circunferenciasCm[chaveSelecionada]);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pesoPontos.length >= 2)
                  _EvolucaoCard(titulo: 'Peso', unidade: 'kg', pontos: pesoPontos),
                if (imcPontos.length >= 2) ...[
                  const SizedBox(height: 16),
                  _EvolucaoCard(titulo: 'IMC', unidade: '', pontos: imcPontos, casasDecimais: 1),
                ],
                if (circunferenciasDisponiveis.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final campo in circunferenciasDisponiveis)
                        ChoiceChip(
                          label: Text(campo.label),
                          selected: chaveSelecionada == campo.key,
                          onSelected: (_) => setState(() => _circunferenciaSelecionada = campo.key),
                          selectedColor: AppColors.gold,
                          backgroundColor: AppColors.surface,
                          labelStyle: TextStyle(
                            color: chaveSelecionada == campo.key
                                ? AppColors.black
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (circunferenciaPontos.length >= 2)
                    _EvolucaoCard(
                      titulo:
                          circunferenciaFields
                              .firstWhere((c) => c.key == chaveSelecionada)
                              .label,
                      unidade: 'cm',
                      pontos: circunferenciaPontos,
                    ),
                ],
                if (pesoPontos.length < 2 && imcPontos.length < 2 && circunferenciasDisponiveis.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Ainda não há duas avaliações com o mesmo dado preenchido pra '
                      'calcular uma evolução.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<_Ponto> _pontosDe(List<AvaliacaoFisica> avaliacoes, double? Function(AvaliacaoFisica) valor) {
    return [
      for (final avaliacao in avaliacoes)
        if (valor(avaliacao) != null) _Ponto(avaliacao.data, valor(avaliacao)!),
    ];
  }
}

class _Ponto {
  const _Ponto(this.data, this.valor);

  final DateTime data;
  final double valor;
}

class _EvolucaoCard extends StatelessWidget {
  const _EvolucaoCard({
    required this.titulo,
    required this.unidade,
    required this.pontos,
    this.casasDecimais = 1,
  });

  final String titulo;
  final String unidade;
  final List<_Ponto> pontos;
  final int casasDecimais;

  @override
  Widget build(BuildContext context) {
    final inicial = pontos.first.valor;
    final atual = pontos.last.valor;
    final diferenca = atual - inicial;
    final percentual = inicial == 0 ? null : (diferenca / inicial) * 100;
    // Sem cor de "bom/ruim" de propósito: subir ou descer não tem um
    // sentido universal aqui (ex.: peso subindo é a meta de quem está
    // em bulking, descendo é a meta de quem está em cutting) — só
    // destaca em dourado quando houve alguma mudança.
    final corDiferenca = diferenca == 0 ? AppColors.textSecondary : AppColors.goldBright;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: CustomPaint(
              size: Size.infinite,
              painter: _LinhaEvolucaoPainter(pontos: pontos.map((p) => p.valor).toList()),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _Metrica('Inicial', '${_fmt(inicial)}$unidade'),
              _Metrica('Atual', '${_fmt(atual)}$unidade'),
              _Metrica(
                'Diferença',
                '${diferenca > 0 ? '+' : ''}${_fmt(diferenca)}$unidade',
                cor: corDiferenca,
              ),
              if (percentual != null)
                _Metrica(
                  'Evolução',
                  '${percentual > 0 ? '+' : ''}${percentual.toStringAsFixed(1)}%',
                  cor: corDiferenca,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(casasDecimais);
}

class _Metrica extends StatelessWidget {
  const _Metrica(this.rotulo, this.valor, {this.cor});

  final String rotulo;
  final String valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rotulo,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            color: cor ?? AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

/// Gráfico de linha minimalista, sem depender de nenhuma biblioteca de
/// terceiros — só o necessário pra mostrar a tendência (sobe/desce),
/// não uma ferramenta de análise. Eixos sem números de propósito, os
/// valores exatos já aparecem nos cartões de "Inicial/Atual/Diferença".
class _LinhaEvolucaoPainter extends CustomPainter {
  _LinhaEvolucaoPainter({required this.pontos});

  final List<double> pontos;

  @override
  void paint(Canvas canvas, Size size) {
    if (pontos.length < 2) return;

    final minimo = pontos.reduce((a, b) => a < b ? a : b);
    final maximo = pontos.reduce((a, b) => a > b ? a : b);
    final intervalo = (maximo - minimo).abs() < 0.001 ? 1.0 : maximo - minimo;

    const margem = 6.0;
    final larguraUtil = size.width - margem * 2;
    final alturaUtil = size.height - margem * 2;

    Offset posicaoDe(int indice) {
      final x = margem + (larguraUtil * indice / (pontos.length - 1));
      final proporcao = (pontos[indice] - minimo) / intervalo;
      final y = margem + alturaUtil * (1 - proporcao);
      return Offset(x, y);
    }

    final linha = Path()..moveTo(posicaoDe(0).dx, posicaoDe(0).dy);
    for (var i = 1; i < pontos.length; i++) {
      final p = posicaoDe(i);
      linha.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(
      linha,
      Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (var i = 0; i < pontos.length; i++) {
      final p = posicaoDe(i);
      final destaque = i == 0 || i == pontos.length - 1;
      canvas.drawCircle(
        p,
        destaque ? 4.5 : 2.5,
        Paint()..color = destaque ? AppColors.goldBright : AppColors.gold,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinhaEvolucaoPainter oldDelegate) =>
      oldDelegate.pontos != pontos;
}
