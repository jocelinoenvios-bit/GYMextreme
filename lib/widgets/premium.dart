import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Peças do visual "premium" das telas iniciais (ADM/Personal e aluno):
/// ícones dourados com volume, cards escuros com brilho dourado embaixo,
/// botões em degradê dourado e a faixa dourada do rodapé.
///
/// Tudo desenhado em código — os ícones são os mesmos SVGs do mockup
/// aprovado, então o app fica igual ao desenho, sem nenhum arquivo de
/// imagem por ícone.
abstract final class OuroPremium {
  static const claro = Color(0xFFFFE27A);
  static const medio = Color(0xFFF5C02A);
  static const escuro = Color(0xFFC98F12);

  /// Linha dourada da borda de baixo dos cards.
  static const linha = Color(0xFFE0A818);

  /// Dourado de texto e ícone de traço sobre o fundo preto.
  static const texto = Color(0xFFFFC72C);

  /// Detalhes escuros desenhados por cima dos ícones dourados.
  static const detalhe = Color(0xFF2B1E04);

  /// Texto e ícones sobre o dourado (botões).
  static const tinta = Color(0xFF1A1200);

  static const degrade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [claro, medio, escuro],
    stops: [0, 0.48, 1],
  );

  static const brilho = Color(0x66FFBE28);
}

/// Um desenho SVG de ícone: o `viewBox` e o miolo (as formas). Os
/// degradês são acrescentados por [IconePremium], então todo desenho
/// pode usar `url(#ouro)`, `url(#ouroLado)`, `url(#ouroTopo)` e
/// `url(#prata)` sem declarar nada.
class DesenhoPremium {
  const DesenhoPremium(this.viewBox, this.formas);

  final String viewBox;
  final String formas;
}

class IconePremium extends StatelessWidget {
  const IconePremium(
    this.desenho, {
    super.key,
    this.largura = 44,
    this.altura = 44,
  });

  final DesenhoPremium desenho;
  final double largura;
  final double altura;

  static const _degrades = '''
<defs>
  <linearGradient id="ouro" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFEB8A"/>
    <stop offset="0.45" stop-color="#F7C431"/>
    <stop offset="1" stop-color="#B9800C"/>
  </linearGradient>
  <linearGradient id="ouroLado" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#D99A12"/>
    <stop offset="1" stop-color="#8E5F08"/>
  </linearGradient>
  <linearGradient id="ouroTopo" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#FFF1A8"/>
    <stop offset="1" stop-color="#F5C02A"/>
  </linearGradient>
  <linearGradient id="prata" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#F2F2F2"/>
    <stop offset="0.5" stop-color="#8F8F8F"/>
    <stop offset="1" stop-color="#CFCFCF"/>
  </linearGradient>
</defs>''';

  /// O SVG completo — exposto pra o teste conseguir validar cada desenho
  /// sem montar a tela inteira.
  static String svgDe(DesenhoPremium desenho) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="${desenho.viewBox}">'
      '$_degrades${desenho.formas}</svg>';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      svgDe(desenho),
      width: largura,
      height: altura,
      excludeFromSemantics: true,
    );
  }
}

/// Os desenhos dos ícones, tirados do mockup aprovado.
abstract final class Desenhos {
  static const painel = DesenhoPremium('0 0 48 48', '''
<rect x="6" y="6" width="16" height="16" rx="3" fill="url(#ouro)"/>
<rect x="26" y="6" width="16" height="16" rx="3" fill="url(#ouro)"/>
<rect x="6" y="26" width="16" height="16" rx="3" fill="url(#ouro)"/>
<rect x="26" y="26" width="16" height="16" rx="3" fill="url(#ouro)"/>''');

  static const alunos = DesenhoPremium(
    '0 1 24 22',
    '''
<path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z" fill="url(#ouro)"/>''',
  );

  static const enviarMensagem = DesenhoPremium('0 0 24 24', '''
<g transform="rotate(-28 12 12)">
  <path d="M2.01 3 23 12h-6L2 10z" fill="url(#ouro)"/>
  <path d="M2 14l15-2h6L2.01 21z" fill="url(#ouroLado)"/>
</g>''');

  static const planos = DesenhoPremium(
    '0 0 48 48',
    '''
<rect x="4" y="9" width="32" height="30" rx="4" fill="url(#ouro)"/>
<rect x="4" y="9" width="32" height="8" rx="4" fill="url(#ouroLado)"/>
<rect x="10" y="5" width="4" height="9" rx="2" fill="#2B1E04"/>
<rect x="26" y="5" width="4" height="9" rx="2" fill="#2B1E04"/>
<rect x="9" y="21" width="5" height="4" rx="1" fill="#2B1E04"/>
<rect x="17" y="21" width="5" height="4" rx="1" fill="#2B1E04"/>
<rect x="25" y="21" width="5" height="4" rx="1" fill="#2B1E04"/>
<rect x="9" y="29" width="5" height="4" rx="1" fill="#2B1E04"/>
<rect x="17" y="29" width="5" height="4" rx="1" fill="#2B1E04"/>
<circle cx="35" cy="35" r="10" fill="url(#ouro)" stroke="#0E0E0E" stroke-width="2"/>
<path d="M35 29.5v5.5l3.8 2.2" fill="none" stroke="#2B1E04" stroke-width="2.4" stroke-linecap="round"/>''',
  );

  /// Cartão de identificação — "Matrículas" do staff e "Dados pessoais"
  /// do aluno usam o mesmo.
  static const cartao = DesenhoPremium('0 0 48 46', '''
<rect x="3" y="8" width="42" height="30" rx="5" fill="url(#ouro)"/>
<circle cx="15" cy="19.5" r="5" fill="#2B1E04"/>
<path d="M7.5 32c0-4.5 3.4-7 7.5-7s7.5 2.5 7.5 7z" fill="#2B1E04"/>
<rect x="26" y="16" width="14" height="3.2" rx="1.6" fill="#2B1E04"/>
<rect x="26" y="22.5" width="14" height="3.2" rx="1.6" fill="#2B1E04"/>
<rect x="26" y="29" width="9" height="3.2" rx="1.6" fill="#2B1E04"/>''');

  static const contasReceber = DesenhoPremium(
    '0 0 48 48',
    '''
<path d="M9 3h24v39l-4-3-4 3-4-3-4 3-4-3-4 3z" fill="url(#ouro)"/>
<rect x="14" y="10" width="14" height="3.2" rx="1.6" fill="#2B1E04"/>
<rect x="14" y="16.5" width="14" height="3.2" rx="1.6" fill="#2B1E04"/>
<rect x="14" y="23" width="9" height="3.2" rx="1.6" fill="#2B1E04"/>
<circle cx="34" cy="35" r="9" fill="url(#ouroLado)" stroke="#0E0E0E" stroke-width="2"/>
<path d="M36.4 32.3c-.5-.8-1.4-1.2-2.4-1.2-1.4 0-2.3.7-2.3 1.7 0 2.3 4.9 1.4 4.9 3.8 0 1.1-1 1.9-2.6 1.9-1.1 0-2-.4-2.6-1.2" fill="none" stroke="#FFE27A" stroke-width="1.7" stroke-linecap="round"/>
<path d="M34 29.5v11" stroke="#FFE27A" stroke-width="1.7" stroke-linecap="round"/>''',
  );

  static const caixa = DesenhoPremium('0 0 48 46', '''
<rect x="13" y="3" width="18" height="9" rx="2" fill="url(#ouroLado)"/>
<rect x="16" y="5.5" width="12" height="4" rx="1" fill="#2B1E04"/>
<path d="M8 14h32l4 18H4z" fill="url(#ouro)"/>
<rect x="11" y="18" width="4" height="3" rx="1" fill="#2B1E04"/>
<rect x="17" y="18" width="4" height="3" rx="1" fill="#2B1E04"/>
<rect x="23" y="18" width="4" height="3" rx="1" fill="#2B1E04"/>
<rect x="29" y="18" width="4" height="3" rx="1" fill="#2B1E04"/>
<rect x="10" y="24" width="4" height="3" rx="1" fill="#2B1E04"/>
<rect x="16" y="24" width="4" height="3" rx="1" fill="#2B1E04"/>
<rect x="22" y="24" width="4" height="3" rx="1" fill="#2B1E04"/>
<rect x="28" y="24" width="4" height="3" rx="1" fill="#2B1E04"/>
<rect x="34" y="24" width="4" height="3" rx="1" fill="#2B1E04"/>
<rect x="2" y="34" width="44" height="9" rx="2" fill="url(#ouroLado)"/>
<rect x="17" y="37.5" width="14" height="2.4" rx="1.2" fill="#2B1E04"/>''');

  static const contasPagar = DesenhoPremium(
    '0 0 48 48',
    '''
<path d="M10 3h20l10 10v32H10z" fill="url(#ouro)"/>
<path d="M30 3v10h10z" fill="url(#ouroLado)"/>
<rect x="14" y="16" width="20" height="22" rx="3" fill="none" stroke="#2B1E04" stroke-width="2.4"/>
<path d="M28 22c-.9-1.4-2.4-2-4-2-2.3 0-3.8 1.2-3.8 2.9 0 3.9 8.2 2.3 8.2 6.3 0 1.8-1.7 3.2-4.4 3.2-1.8 0-3.4-.7-4.3-2" fill="none" stroke="#2B1E04" stroke-width="2.6" stroke-linecap="round"/>
<path d="M24 18.5v17" stroke="#2B1E04" stroke-width="2.6" stroke-linecap="round"/>''',
  );

  static const produtos = DesenhoPremium(
    '0 0 48 48',
    '''
<path d="M24 5 42 13 24 21 6 13z" fill="url(#ouroTopo)"/>
<path d="M6 13 24 21v22L6 35z" fill="url(#ouro)"/>
<path d="M42 13 24 21v22l18-8z" fill="url(#ouroLado)"/>
<path d="M14 9.5 32 17.5v6l-3.5-1.6v-4.2L10.5 11z" fill="#2B1E04" opacity="0.35"/>''',
  );

  static const biblioteca = DesenhoPremium('0 0 48 44', '''
<rect x="11" y="20" width="26" height="4" rx="2" fill="url(#prata)"/>
<rect x="3" y="13" width="5" height="18" rx="2" fill="url(#ouro)"/>
<rect x="8" y="9" width="6" height="26" rx="2" fill="url(#ouro)"/>
<rect x="34" y="9" width="6" height="26" rx="2" fill="url(#ouro)"/>
<rect x="40" y="13" width="5" height="18" rx="2" fill="url(#ouro)"/>''');

  static const funcionarios = DesenhoPremium(
    '0 0 48 48',
    '''
<circle cx="24" cy="13" r="9" fill="url(#ouro)"/>
<path d="M7 45c0-11 7.5-17 17-17s17 6 17 17z" fill="url(#ouro)"/>
<path d="M24 28.5l-3.2 3.2 2.2 2-2.2 9.3 3.2 2.5 3.2-2.5-2.2-9.3 2.2-2z" fill="#2B1E04"/>''',
  );

  static const ficha = DesenhoPremium('0 0 44 48', '''
<rect x="6" y="6" width="32" height="40" rx="5" fill="url(#ouro)"/>
<rect x="14" y="2" width="16" height="9" rx="3" fill="url(#ouroLado)"/>
<circle cx="13.5" cy="20" r="2" fill="#2B1E04"/>
<rect x="18" y="18.4" width="14" height="3.2" rx="1.6" fill="#2B1E04"/>
<circle cx="13.5" cy="28" r="2" fill="#2B1E04"/>
<rect x="18" y="26.4" width="14" height="3.2" rx="1.6" fill="#2B1E04"/>
<circle cx="13.5" cy="36" r="2" fill="#2B1E04"/>
<rect x="18" y="34.4" width="10" height="3.2" rx="1.6" fill="#2B1E04"/>''');

  static const medidas = DesenhoPremium('0 0 48 46', '''
<ellipse cx="17" cy="20" rx="14" ry="11" fill="url(#ouroLado)"/>
<ellipse cx="17" cy="16" rx="14" ry="11" fill="url(#ouro)"/>
<ellipse cx="17" cy="16" rx="5" ry="4" fill="#2B1E04"/>
<path d="M28 22h17v10H24z" fill="url(#ouro)"/>
<rect x="29" y="22" width="1.6" height="4" fill="#2B1E04"/>
<rect x="33" y="22" width="1.6" height="6" fill="#2B1E04"/>
<rect x="37" y="22" width="1.6" height="4" fill="#2B1E04"/>
<rect x="41" y="22" width="1.6" height="6" fill="#2B1E04"/>''');

  static const anamnese = DesenhoPremium('0 0 44 48', '''
<rect x="6" y="6" width="32" height="40" rx="5" fill="url(#ouro)"/>
<rect x="14" y="2" width="16" height="9" rx="3" fill="url(#ouroLado)"/>
<circle cx="22" cy="28" r="10" fill="#2B1E04"/>
<rect x="19.5" y="21" width="5" height="14" rx="1.2" fill="url(#ouro)"/>
<rect x="15" y="25.5" width="14" height="5" rx="1.2" fill="url(#ouro)"/>''');

  static const evolucao = DesenhoPremium(
    '0 0 48 48',
    '''
<rect x="5" y="30" width="9" height="14" rx="2" fill="url(#ouro)"/>
<rect x="18" y="23" width="9" height="21" rx="2" fill="url(#ouro)"/>
<rect x="31" y="15" width="9" height="29" rx="2" fill="url(#ouro)"/>
<path d="M5 22 18 12l8 6L40 6" fill="none" stroke="#F7C431" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M33 5h8v8" fill="none" stroke="#F7C431" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round"/>''',
  );

  static const mensagens = DesenhoPremium('0 0 48 46', '''
<path d="M8 4h32a6 6 0 0 1 6 6v18a6 6 0 0 1-6 6H22l-10 9v-9H8a6 6 0 0 1-6-6V10a6 6 0 0 1 6-6z" fill="url(#ouro)"/>
<circle cx="15" cy="19" r="3" fill="#2B1E04"/>
<circle cx="24" cy="19" r="3" fill="#2B1E04"/>
<circle cx="33" cy="19" r="3" fill="#2B1E04"/>''');

  /// Destaque da tela do ADM/Personal/Funcionário.
  static const escudo = DesenhoPremium(
    '0 0 120 120',
    '''
<path d="M60 6 104 22v30c0 30-19 52-44 62C35 104 16 82 16 52V22z" fill="url(#ouro)"/>
<path d="M60 15 95 28v25c0 25-15 43-35 52C40 96 25 78 25 53V28z" fill="#151515"/>
<circle cx="60" cy="49" r="13" fill="url(#ouro)"/>
<path d="M36 88c0-15 11-24 24-24s24 9 24 24z" fill="url(#ouro)"/>
<circle cx="90" cy="90" r="17" fill="url(#ouro)" stroke="#0A0A0A" stroke-width="3"/>
<path d="M81 90l6 6 12-13" fill="none" stroke="#2B1E04" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>''',
  );

  /// Destaque da tela do aluno.
  static const halter = DesenhoPremium('0 0 220 124', '''
<g transform="rotate(-12 110 62)">
  <rect x="52" y="55" width="116" height="14" rx="7" fill="url(#prata)"/>
  <rect x="86" y="55" width="1.6" height="14" fill="#5E5E5E"/>
  <rect x="92" y="55" width="1.6" height="14" fill="#5E5E5E"/>
  <rect x="126" y="55" width="1.6" height="14" fill="#5E5E5E"/>
  <rect x="132" y="55" width="1.6" height="14" fill="#5E5E5E"/>
  <rect x="12" y="32" width="15" height="60" rx="6" fill="url(#ouroLado)"/>
  <rect x="26" y="18" width="24" height="88" rx="8" fill="url(#ouro)"/>
  <rect x="31" y="23" width="4" height="78" rx="2" fill="#FFFFFF" opacity="0.38"/>
  <rect x="48" y="49" width="8" height="26" rx="3" fill="url(#prata)"/>
  <rect x="164" y="49" width="8" height="26" rx="3" fill="url(#prata)"/>
  <rect x="170" y="18" width="24" height="88" rx="8" fill="url(#ouro)"/>
  <rect x="175" y="23" width="4" height="78" rx="2" fill="#FFFFFF" opacity="0.38"/>
  <rect x="193" y="32" width="15" height="60" rx="6" fill="url(#ouroLado)"/>
</g>''');

  /// Silhuetas de halteres atrás do escudo — lembram o fundo de
  /// academia do desenho de referência, sem precisar de uma foto.
  static const silhuetas = DesenhoPremium('0 0 240 110', '''
<g fill="#2A2A2A">
  <rect x="6" y="38" width="16" height="44" rx="4"/>
  <rect x="22" y="30" width="18" height="60" rx="5"/>
  <rect x="40" y="56" width="26" height="8" rx="4" fill="#3A3A3A"/>
  <rect x="200" y="30" width="18" height="60" rx="5"/>
  <rect x="218" y="38" width="16" height="44" rx="4"/>
  <rect x="174" y="56" width="26" height="8" rx="4" fill="#3A3A3A"/>
</g>''');

  /// Todos — pro teste validar que cada um é um SVG que carrega.
  static const todos = [
    painel,
    alunos,
    enviarMensagem,
    planos,
    cartao,
    contasReceber,
    caixa,
    contasPagar,
    produtos,
    biblioteca,
    funcionarios,
    ficha,
    medidas,
    anamnese,
    evolucao,
    mensagens,
    escudo,
    halter,
    silhuetas,
  ];
}

/// Card escuro com brilho dourado na borda de baixo: ícone + rótulo
/// dentro do próprio card.
class CardPremium extends StatelessWidget {
  const CardPremium({
    super.key,
    required this.desenho,
    required this.rotulo,
    required this.onTap,
    this.naoLidas = 0,
  });

  final DesenhoPremium desenho;
  final String rotulo;
  final VoidCallback onTap;

  /// Quantidade no selo vermelho do canto. Zero esconde o selo.
  final int naoLidas;

  static const _raio = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: _raio,
        boxShadow: [
          BoxShadow(
            color: OuroPremium.brilho,
            blurRadius: 16,
            spreadRadius: -6,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _raio,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: _raio,
              border: Border.all(color: const Color(0xFF2A2A2A)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1D1D1D), Color(0xFF0F0F0F)],
              ),
            ),
            child: InkWell(
              onTap: onTap,
              splashColor: const Color(0x33FFC72C),
              highlightColor: const Color(0x14FFC72C),
              child: Stack(
                children: [
                  // Reflexo dourado subindo da borda de baixo.
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00E0A818), Color(0x2EE0A818)],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 2.5,
                    child: ColoredBox(color: OuroPremium.linha),
                  ),
                  // FittedBox: garante que ícone + rótulo de 2 linhas
                  // nunca estourem a altura fixa da célula da grade, em
                  // qualquer tela ou tamanho de fonte (já tivemos esse
                  // bug de verdade, ver o histórico de _TileMenuPerfil).
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 100,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconePremium(desenho),
                              const SizedBox(height: 8),
                              Text(
                                rotulo,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFF5F5F5),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (naoLidas > 0)
                    Positioned(
                      top: 9,
                      right: 9,
                      child: _SeloNaoLidas(naoLidas),
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

class _SeloNaoLidas extends StatelessWidget {
  const _SeloNaoLidas(this.quantidade);

  final int quantidade;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFF121212), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        quantidade > 9 ? '9+' : '$quantidade',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Botão largo em degradê dourado: ícone à esquerda, rótulo no centro,
/// seta à direita.
class BotaoOuro extends StatelessWidget {
  const BotaoOuro({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.onTap,
    this.giroIcone = 0,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;

  /// Em radianos — o halter do Material (`fitness_center`) é desenhado na
  /// diagonal, e no desenho aprovado ele fica deitado.
  final double giroIcone;

  static const _raio = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        borderRadius: _raio,
        boxShadow: [
          BoxShadow(
            color: Color(0xBFFFBE28),
            blurRadius: 20,
            spreadRadius: -8,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: _raio,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: OuroPremium.degrade),
          child: InkWell(
            onTap: onTap,
            splashColor: const Color(0x331A1200),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Transform.rotate(
                      angle: giroIcone,
                      child: Icon(icone, color: OuroPremium.tinta, size: 28),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rotulo,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OuroPremium.tinta,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 40,
                    child: Icon(
                      Icons.chevron_right,
                      color: OuroPremium.tinta,
                      size: 28,
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

/// Destaque do topo: o desenho principal com um brilho dourado atrás.
class DestaquePremium extends StatelessWidget {
  const DestaquePremium({
    super.key,
    required this.desenho,
    required this.largura,
    required this.altura,
    this.comSilhuetas = false,
  });

  final DesenhoPremium desenho;
  final double largura;
  final double altura;

  /// Halteres escuros nas laterais, lembrando um fundo de academia.
  final bool comSilhuetas;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: altura + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // O raio 0.5 faz o brilho sumir de vez exatamente nas bordas de
          // cima e de baixo (senão ele é cortado ainda aceso e vira um
          // retângulo visível); o esticão horizontal transforma o círculo
          // numa elipse larga, como no desenho.
          Positioned.fill(
            child: Transform.scale(
              scaleX: 2.2,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.5,
                    colors: [Color(0x40FFBA1E), Color(0x00FFBA1E)],
                  ),
                ),
              ),
            ),
          ),
          if (comSilhuetas)
            const Opacity(
              opacity: 0.55,
              child: IconePremium(
                Desenhos.silhuetas,
                largura: 240,
                altura: 110,
              ),
            ),
          IconePremium(desenho, largura: largura, altura: altura),
        ],
      ),
    );
  }
}

/// "Bem-vindo," em branco e o nome em dourado.
class SaudacaoPremium extends StatelessWidget {
  const SaudacaoPremium({
    super.key,
    required this.nome,
    this.tamanho = 30,
    this.nomeItalico = false,
  });

  final String nome;
  final double tamanho;
  final bool nomeItalico;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'Bem-vindo, ',
        children: [
          TextSpan(
            text: nome,
            style: TextStyle(
              color: OuroPremium.texto,
              fontStyle: nomeItalico ? FontStyle.italic : FontStyle.normal,
              fontWeight: nomeItalico ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFFF5F5F5),
        fontSize: tamanho,
        fontWeight: FontWeight.w700,
        height: 1.15,
        shadows: const [
          Shadow(
            color: Color(0x99000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// Faixa dourada brilhante cruzando o rodapé, atrás do conteúdo.
class FaixaDouradaRodape extends StatelessWidget {
  const FaixaDouradaRodape({super.key, this.altura = 170});

  final double altura;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: altura,
        width: double.infinity,
        child: const CustomPaint(painter: _FaixaPainter()),
      ),
    );
  }
}

class _FaixaPainter extends CustomPainter {
  const _FaixaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final retangulo = Offset.zero & size;

    final principal = Path()
      ..moveTo(0, h - 2)
      ..cubicTo(w * 0.33, h * 0.81, w * 0.64, h * 0.63, w, h * 0.28);

    final preenchimento = Path.from(principal)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      preenchimento,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x29FFC72C), Color(0x00FFC72C)],
        ).createShader(retangulo),
    );

    final degradeLinha = const LinearGradient(
      colors: [Color(0x00FFC72C), Color(0xFFFFC72C), Color(0xFFFFE680)],
      stops: [0, 0.55, 1],
    ).createShader(retangulo);

    // Brilho: o mesmo traço, mais grosso e desfocado, por baixo.
    canvas.drawPath(
      principal,
      Paint()
        ..shader = degradeLinha
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      principal,
      Paint()
        ..shader = degradeLinha
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final secundaria = Path()
      ..moveTo(0, h)
      ..cubicTo(w * 0.38, h * 0.89, w * 0.69, h * 0.79, w, h * 0.61);
    canvas.drawPath(
      secundaria,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FFC72C), Color(0x8CFFC72C), Color(0x8CFFE680)],
          stops: [0, 0.55, 1],
        ).createShader(retangulo)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(_FaixaPainter oldDelegate) => false;
}

/// Fundo de toda página do app: preto com a faixa dourada no rodapé.
///
/// Aplicado uma vez só, por [TransicaoPremium], em vez de tela por tela.
/// Por isso o Scaffold do tema é transparente — quem pinta o fundo é
/// isto aqui, por trás de cada página.
class FundoPremium extends StatelessWidget {
  const FundoPremium({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0A0A0A),
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FaixaDouradaRodape(altura: 150),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// A transição de tela padrão da plataforma, com [FundoPremium] por trás
/// de cada página.
///
/// O fundo vai DENTRO da transição de propósito: cada página leva o seu,
/// opaco, então durante a animação a página de baixo nunca aparece
/// através do Scaffold transparente da de cima.
class TransicaoPremium extends PageTransitionsBuilder {
  const TransicaoPremium(this.base);

  final PageTransitionsBuilder base;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return base.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      FundoPremium(child: child),
    );
  }
}

/// Decoração dos cards desenhados à mão nas telas — o mesmo degradê
/// escuro e brilho dourado dos cards da tela inicial.
abstract final class DecoracaoPremium {
  static const gradienteCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1C1C1C), Color(0xFF111111)],
  );

  static const bordaCard = Color(0xFF2A2A2A);

  static const sombraCard = [
    BoxShadow(
      color: Color(0x40FFBE28),
      blurRadius: 14,
      spreadRadius: -6,
      offset: Offset(0, 6),
    ),
  ];
}
