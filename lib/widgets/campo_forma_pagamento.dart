import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// As formas de pagamento aceitas na academia. O texto é o que fica
/// gravado no campo `formaPagamento` (mesmo campo de antes, que era
/// digitado à mão).
const formasPagamento = <(String, IconData)>[
  ('Pix', Icons.pix),
  ('Cartão', Icons.credit_card),
  ('Dinheiro', Icons.payments_outlined),
];

/// Escolha da forma de pagamento em 3 botões (Pix, Cartão, Dinheiro), no
/// lugar do campo de texto livre. Trabalha sobre o mesmo
/// [TextEditingController] que as telas já usavam — o salvar não muda, e
/// quem preenche o controller por fora (ex.: Nova cobrança copiando a forma
/// de pagamento da matrícula) aparece selecionado na hora.
///
/// Opcional: tocar de novo no botão escolhido desmarca. Obrigatório: valida
/// junto com o resto do formulário.
///
/// Registro antigo, digitado à mão com outro texto (ex.: "Transferência"),
/// aparece como um 4º botão já marcado, pra não ser apagado sem querer.
class CampoFormaPagamento extends StatelessWidget {
  const CampoFormaPagamento({
    super.key,
    required this.controller,
    this.obrigatorio = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool obrigatorio;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (_) => obrigatorio && controller.text.trim().isEmpty
          ? 'Escolha a forma de pagamento.'
          : null,
      builder: (field) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final atual = controller.text.trim();
          final opcoes = [
            ...formasPagamento,
            if (atual.isNotEmpty && !formasPagamento.any((f) => f.$1 == atual))
              (atual, Icons.history),
          ];

          void escolher(String forma) {
            controller.text = (!obrigatorio && forma == atual) ? '' : forma;
            field.didChange(controller.text);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  obrigatorio ? 'Forma de pagamento' : 'Forma de pagamento (opcional)',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < opcoes.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _Opcao(
                        rotulo: opcoes[i].$1,
                        icone: opcoes[i].$2,
                        selecionada: opcoes[i].$1 == atual,
                        onTap: enabled ? () => escolher(opcoes[i].$1) : null,
                      ),
                    ),
                  ],
                ],
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 6),
                  child: Text(
                    field.errorText!,
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.rotulo,
    required this.icone,
    required this.selecionada,
    required this.onTap,
  });

  final String rotulo;
  final IconData icone;
  final bool selecionada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final desabilitada = onTap == null;
    final corConteudo = selecionada ? AppColors.black : AppColors.textPrimary;
    return Opacity(
      opacity: desabilitada ? 0.5 : 1,
      child: Semantics(
        button: true,
        selected: selecionada,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 64,
              decoration: BoxDecoration(
                color: selecionada ? AppColors.gold : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selecionada ? AppColors.gold : AppColors.surfaceHigh,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icone, size: 22, color: selecionada ? AppColors.black : AppColors.gold),
                  const SizedBox(height: 4),
                  Text(
                    rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: corConteudo,
                      fontWeight: selecionada ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
