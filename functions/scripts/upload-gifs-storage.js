'use strict';

/**
 * Sobe os GIFs da Biblioteca Oficial (ExerciseDB) — hoje só em
 * assets/exercicios/gifs/ e gifs_360/ no repositório — pro Firebase
 * Storage do projeto gymextreme-42c98, no mesmo caminho que
 * `ExerciseModel.gif180PathPara`/`gif360PathPara` (Dart) já esperam:
 * `exercicios/gifs/{id}.gif` e `exercicios/gifs_360/{id}.gif`.
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
  { local: path.join(__dirname, '..', '..', 'assets', 'exercicios', 'gifs'), remota: 'exercicios/gifs' },
  {
    local: path.join(__dirname, '..', '..', 'assets', 'exercicios', 'gifs_360'),
    remota: 'exercicios/gifs_360',
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
