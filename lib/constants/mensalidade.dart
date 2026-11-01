/// Tolerância (em dias) após o vencimento da mensalidade antes do bloqueio
/// de acesso — regra de negócio confirmada com o cliente (mensalidade,
/// aplicativo e catraca todos usam este mesmo número.
///
/// Zero (pedido do cliente): vence no dia e, no dia seguinte, já bloqueia.
/// No próprio dia do vencimento o aluno ainda está em dia.
const int toleranciaMensalidadeDias = 0;
