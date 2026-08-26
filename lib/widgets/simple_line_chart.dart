import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Um ponto de dado simples (data + valor) pra [SimpleLineChart].
class ChartPoint {
  const ChartPoint(this.data, this.valor);
  final DateTime data;
  final double valor;
}

/// Gráfico de linha minimalista, desenhado com [CustomPainter] — sem
/// nenhuma dependência externa de gráficos. Usado só pela tela de
/// evolução física pra plotar peso/IMC ao longo do tempo; não pretende
/// ser um gráfico genérico (sem eixos, zoom, tooltip etc.), só o
/// suficiente pra mostrar a tendência com poucos pontos.
class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    super.key,
    required this.pontos,
    required this.corLinha,
    this.altura = 160,
    this.sufixo = '',
  });

  final List<ChartPoint> pontos;
  final Color corLinha;
  final double altura;
  final String sufixo;

  @override
  Widget build(BuildContext context) {
    if (pontos.length < 2) {
      return SizedBox(
        height: altura,
        child: Center(
          child: Text(
            pontos.isEmpty
                ? 'Sem dados suficientes para o gráfico.'
                : '${pontos.single.valor.toStringAsFixed(1)}$sufixo',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final valores = pontos.map((p) => p.valor).toList();
    final minValor = valores.reduce((a, b) => a < b ? a : b);
    final maxValor = valores.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: altura,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _LineChartPainter(
                pontos: pontos,
                corLinha: corLinha,
                minValor: minValor,
                maxValor: maxValor,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Text(
              '${maxValor.toStringAsFixed(1)}$sufixo',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Text(
              '${minValor.toStringAsFixed(1)}$sufixo',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.pontos,
    required this.corLinha,
    required this.minValor,
    required this.maxValor,
  });

  final List<ChartPoint> pontos;
  final Color corLinha;
  final double minValor;
  final double maxValor;

  @override
  void paint(Canvas canvas, Size size) {
    final amplitude = (maxValor - minValor).abs();
    final range = amplitude == 0 ? 1 : amplitude;

    double xDe(int i) =>
        pontos.length == 1 ? size.width / 2 : size.width * i / (pontos.length - 1);
    double yDe(double valor) => size.height - ((valor - minValor) / range) * size.height;

    final linePaint = Paint()
      ..color = corLinha
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = 0; i < pontos.length; i++) {
      final x = xDe(i);
      final y = yDe(pontos[i].valor);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = corLinha;
    for (var i = 0; i < pontos.length; i++) {
      canvas.drawCircle(Offset(xDe(i), yDe(pontos[i].valor)), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.pontos != pontos ||
        oldDelegate.minValor != minValor ||
        oldDelegate.maxValor != maxValor;
  }
}
