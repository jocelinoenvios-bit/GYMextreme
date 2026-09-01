'use strict';

/**
 * Sobe os GIFs da Biblioteca Oficial (ExerciseDB) pro Firebase Storage
 * do projeto gymextreme-42c98 — SÓ a variante 360° (maior resolução),
 * hoje em assets/exercicios/gifs_360/ no repositório. A variante 180°
 * (assets/exercicios/gifs/) fica de fora de propósito: só uma
 * qualidade é hospedada, então não faz sentido pagar armazenamento/
 * banda por duas.
 *
 * Caminho no Storage: `exercicios/gifs/{id}.gif` — nomenclatura oficial
 * da ExerciseDB (o próprio id), sem renomeação. É o mesmo id, só que
 * agora é a ÚNICA cópia hospedada (a 360°) que vive nesse caminho.
 *
 * IMPORTANTE (pendência a resolver antes do upload de verdade): hoje
 * `ExerciseModel.gif360PathPara` (Dart) gera `exercicios/gifs_360/
 * {id}.gif`, não `exercicios/gifs/{id}.gif` — ou seja, o caminho que
 * este script usa ainda NÃO bate com o que o app pede. Isso precisa
 * ser alinhado no código Dart antes de rodar o upload de verdade,
 * senão o app não vai encontrar os arquivos.
 *
 * Preciso disso porque, a partir da Fase 2 da biblioteca de mídia, os
 * GIFs pararam de ser empacotados no APK (ver pubspec.yaml) — o app
 * baixa cada um sob demanda (com cache local) via `GifCacheService`.
 * Sem esse upload, nenhum exercício sem vídeo Vital Animations
 * consegue mostrar mídia nenhuma.
 *
 * Idempotente: pula qualquer arquivo que já exista no bucket com o
 * mesmo tamanho (dá pra rodar de novo com segurança se cair no meio).
 *
 * Uso:
 *   1. Autentique com uma identidade que tenha permissão de escrita no
 *      Storage do projeto gymextreme-42c98 — a mais simples é rodar
 *      `firebase login` (se tiver o Firebase CLI) e depois
 *      `gcloud auth application-default login`, OU apontar
 *      GOOGLE_APPLICATION_CREDENTIALS pra uma chave de service account
 *      com o papel "Storage Admin" desse projeto.
 *   2. cd functions && node scripts/upload-gifs-storage.js
 *
 * Nenhuma credencial fica neste arquivo nem no repositório — usa
 * sempre o Application Default Credentials do ambiente de quem roda.
 */

const path = require('node:path');
const fs = require('node:fs/promises');

const admin = require('firebase-admin');

const BUCKET = 'gymextreme-42c98.firebasestorage.app';

const PASTAS = [
  {
    local: path.join(__dirname, '..', '..', 'assets', 'exercicios', 'gifs_360'),
    remota: 'exercicios/gifs',
  },
];

async function main() {
  admin.initializeApp({ storageBucket: BUCKET });
  const bucket = admin.storage().bucket();

  let enviados = 0;
  let jaExistiam = 0;
  let falharam = 0;

  for (const pasta of PASTAS) {
    const arquivos = (await fs.readdir(pasta.local)).filter((nome) => nome.endsWith('.gif'));
    console.log(`\n${pasta.local} -> gs://${BUCKET}/${pasta.remota}/ (${arquivos.length} arquivos)`);

    for (const nomeArquivo of arquivos) {
      const caminhoLocal = path.join(pasta.local, nomeArquivo);
      const caminhoRemoto = `${pasta.remota}/${nomeArquivo}`;
      const destino = bucket.file(caminhoRemoto);

      try {
        const [existe] = await destino.exists();
        if (existe) {
          const tamanhoLocal = (await fs.stat(caminhoLocal)).size;
          const [metadados] = await destino.getMetadata();
          if (Number(metadados.size) === tamanhoLocal) {
            jaExistiam++;
            continue;
          }
        }

        await bucket.upload(caminhoLocal, {
          destination: caminhoRemoto,
          metadata: { contentType: 'image/gif' },
        });
        enviados++;
        if (enviados % 100 === 0) console.log(`  ${enviados} enviados...`);
      } catch (erro) {
        falharam++;
        console.error(`  FALHOU: ${caminhoRemoto} — ${erro.message}`);
      }
    }
  }

  console.log(
    `\nConcluído. Enviados: ${enviados} | já existiam (pulados): ${jaExistiam} | falharam: ${falharam}`,
  );
  if (falharam > 0) process.exitCode = 1;
}

main().catch((erro) => {
  console.error('Erro fatal:', erro);
  process.exitCode = 1;
});
