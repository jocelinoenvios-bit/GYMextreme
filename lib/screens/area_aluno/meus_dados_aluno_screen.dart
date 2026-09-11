import 'package:flutter/material.dart';

import '../../models/aluno.dart';
import '../../models/app_user.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';

/// Dados de cadastro do próprio aluno, somente leitura — quem
/// cadastra/edita é a recepção/academia (ver `DadosTab`, usado pelo
/// staff). O aluno não tem hoje nenhuma funcionalidade de autoedição
/// desses campos, então esta tela só exibe.
class MeusDadosAlunoScreen extends StatelessWidget {
  const MeusDadosAlunoScreen({
    super.key,
    required this.usuario,
    required this.uid,
    required this.alunoService,
  });

  final AppUser usuario;
  final String uid;
  final AlunoService alunoService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dados pessoais')),
      body: SafeArea(
        child: StreamBuilder<Aluno?>(
          stream: alunoService.watchAluno(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final aluno = snapshot.data;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _Secao('Conta', [
                  _Linha('Nome', usuario.nome),
                  _Linha('E-mail', usuario.email),
                ]),
                if (aluno != null) ...[
                  _Secao('Dados pessoais', [
                    if (aluno.sexo != null) _Linha('Sexo', aluno.sexo!.label),
                    if (aluno.dataNascimento != null)
                      _Linha('Nascimento', _formatarData(aluno.dataNascimento!)),
                    if (aluno.idade != null) _Linha('Idade', '${aluno.idade} anos'),
                    if (aluno.cpf != null && aluno.cpf!.isNotEmpty) _Linha('CPF', aluno.cpf!),
                    if (aluno.rg != null && aluno.rg!.isNotEmpty) _Linha('RG', aluno.rg!),
                  ]),
                  _Secao('Contato', [
                    if (aluno.telefone != null && aluno.telefone!.isNotEmpty)
                      _Linha('Telefone', aluno.telefone!),
                    if (aluno.whatsapp != null && aluno.whatsapp!.isNotEmpty)
                      _Linha('WhatsApp', aluno.whatsapp!),
                  ]),
                  if (aluno.endereco.estaPreenchido)
                    _Secao('Endereço', [
                      _Linha(
                        'Endereço',
                        [
                          aluno.endereco.logradouro,
                          aluno.endereco.numero,
                        ].where((v) => v != null && v.isNotEmpty).join(', '),
                      ),
                      if (aluno.endereco.bairro != null && aluno.endereco.bairro!.isNotEmpty)
                        _Linha('Bairro', aluno.endereco.bairro!),
                      if (aluno.endereco.cidade != null && aluno.endereco.cidade!.isNotEmpty)
                        _Linha(
                          'Cidade/UF',
                          '${aluno.endereco.cidade}'
                              '${aluno.endereco.uf != null ? ' - ${aluno.endereco.uf}' : ''}',
                        ),
                      if (aluno.endereco.cep != null && aluno.endereco.cep!.isNotEmpty)
                        _Linha('CEP', aluno.endereco.cep!),
                    ]),
                  if ((aluno.contatoEmergenciaNome ?? '').isNotEmpty)
                    _Secao('Contato de emergência', [
                      _Linha('Nome', aluno.contatoEmergenciaNome!),
                      if (aluno.contatoEmergenciaTelefone != null &&
                          aluno.contatoEmergenciaTelefone!.isNotEmpty)
                        _Linha('Telefone', aluno.contatoEmergenciaTelefone!),
                    ]),
                  if (aluno.dataInicio != null)
                    _Secao('Matrícula', [
                      _Linha('Início na academia', _formatarData(aluno.dataInicio!)),
                    ]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }
}

class _Secao extends StatelessWidget {
  const _Secao(this.titulo, this.linhas);

  final String titulo;
  final List<_Linha> linhas;

  @override
  Widget build(BuildContext context) {
    if (linhas.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          ...linhas,
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(this.rotulo, this.valor);

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    if (valor.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          children: [
            TextSpan(text: '$rotulo: '),
            TextSpan(
              text: valor,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
