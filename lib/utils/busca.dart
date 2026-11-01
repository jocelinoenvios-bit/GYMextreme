const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
const _semAcento = 'aaaaaeeeeiiiiooooouuuucn';

/// Texto pronto pra comparar numa busca: minúsculo e sem acento — assim
/// "flavio" acha "Flávio" e "joao" acha "JOÃO".
String paraBusca(String texto) {
  final minusculo = texto.toLowerCase();
  final saida = StringBuffer();
  for (final rune in minusculo.runes) {
    final letra = String.fromCharCode(rune);
    final i = _comAcento.indexOf(letra);
    saida.write(i < 0 ? letra : _semAcento[i]);
  }
  return saida.toString();
}
