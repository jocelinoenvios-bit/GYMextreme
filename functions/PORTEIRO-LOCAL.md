# Porteiro da catraca — instalação no computador da academia

O **porteiro** é o programa que fica rodando no computador da recepção e
responde ao leitor facial **iDFace Pro**: o aluno olha pro leitor, o
leitor pergunta ao porteiro "posso liberar?", o porteiro confere no
Firebase (matrícula, mensalidade, bloqueio) e responde. Tudo pela rede
da academia, **sem nenhum serviço pago** — usa o plano gratuito do
Firebase.

```
 Aluno ──> iDFace Pro ──(rede da academia)──> computador da recepção (porteiro)
                                                       │
                                                       └──(internet)──> Firebase (grátis)
```

Precisa: o computador ligado e com internet enquanto a academia estiver
aberta, na **mesma rede** (mesmo roteador) do iDFace.

---

## 1. Instalar o Node.js (uma vez)

1. Entre em **https://nodejs.org** e baixe a versão **LTS**.
2. Instale com as opções padrão (Avançar, Avançar, Concluir).

## 2. Baixar o projeto (uma vez)

1. Entre no repositório no GitHub → botão verde **Code** → **Download ZIP**.
2. Extraia em `C:\GymXtreme` (vai ficar `C:\GymXtreme\functions\...`).

## 3. Chave do Firebase (uma vez)

É o "crachá" que deixa o porteiro consultar o banco. **Grátis.**

1. Abra o **Firebase Console** → ⚙️ **Configurações do projeto** →
   aba **Contas de serviço** → **Gerar nova chave privada** → **Gerar chave**.
2. Salve o arquivo baixado como `C:\GymXtreme\chave-firebase.json`.
3. Na pasta `C:\GymXtreme\functions`, copie `porteiro.env.exemplo` e
   renomeie a cópia para `porteiro.env`. Confira se o caminho da chave
   está certo lá dentro.

> ⚠️ Essa chave dá acesso total ao banco. Não mande por WhatsApp/e-mail,
> não coloque no GitHub (o projeto já ignora esse arquivo) e guarde só
> nesse computador. Se vazar, apague a chave no mesmo lugar e gere outra.

## 4. Instalar e testar o porteiro

1. Abra a pasta `C:\GymXtreme\functions`, clique na barra de endereço,
   digite `cmd` e Enter (abre o terminal já na pasta).
2. Digite `npm install` e Enter (uma vez; demora um pouco).
3. Digite `npm run porteiro` e Enter. Deve aparecer
   **"Porteiro GYM XTREME no ar, na porta 8080"**.
4. No navegador do computador, abra `http://localhost:8080` — tem que
   aparecer `"funcionando": true`.

## 5. Endereço fixo do computador

O iDFace precisa saber onde o porteiro está.

1. No terminal, digite `ipconfig` e anote o **Endereço IPv4**
   (ex.: `192.168.0.10`).
2. No roteador, reserve esse IP para o computador (procure por
   "Reserva de DHCP" / "IP fixo"), senão ele pode mudar.
3. Na primeira vez que o porteiro rodar, o Windows pergunta sobre o
   firewall: marque **Redes privadas** e clique **Permitir acesso**.
4. Teste de outro aparelho na mesma rede (ex.: o celular no Wi-Fi da
   academia): abra `http://192.168.0.10:8080` (com o seu IP).

## 6. Cadastrar o iDFace no sistema (uma vez por aparelho)

No terminal da pasta `functions`:

```
npm run catraca -- cadastrar-dispositivo "Entrada principal"
```

Aparecem o **id** e o **token** do aparelho. **Anote o token na hora** —
ele não aparece de novo.

Depois, na tela de configuração do iDFace (pelo navegador, no IP do
aparelho), em **Modo de operação → Online / Pro**:

- **Servidor:** `192.168.0.10` (o IP do passo 5), **porta** `8080`
- **Caminho / endpoint:** `/api/integrations/controlid/events/new-user-identified`
- **Token:** se o aparelho tiver campo de cabeçalho, use o cabeçalho
  `X-Device-Token` com o token; se não tiver, coloque no fim do endereço:
  `...new-user-identified?token=SEU_TOKEN`

> 🔎 **A confirmar no aparelho:** os nomes exatos desses campos no iDFace.
> O porteiro aceita tanto o caminho acima quanto o padrão do aparelho
> (`/new_user_identified.fcgi`), e o token no cabeçalho ou no endereço.

## 7. Cadastrar cada aluno

1. Cadastre o rosto do aluno **no próprio iDFace** e anote o **código
   (ID do usuário)** que o aparelho der pra ele.
2. Vincule esse código ao aluno:
   - **pelo app:** ficha do aluno → aba **Frequência** → **Catraca** → **Vincular código**; ou
   - **pelo terminal:**
     `npm run catraca -- vincular ID_DO_APARELHO CODIGO email@do.aluno`

Quem não estiver vinculado é negado ("aluno não encontrado").

## 8. Ligar sozinho com o Windows

1. Aperte **Windows + R**, digite `shell:startup` e Enter (abre a pasta
   Inicializar).
2. Clique com o botão direito em `C:\GymXtreme\functions\iniciar-porteiro.bat`
   → **Criar atalho**, e mova o atalho pra pasta Inicializar.

Agora o porteiro abre sozinho quando o computador ligar, e se fechar por
algum erro ele se reinicia em 5 segundos. **Não feche a janela preta
"Porteiro GYM XTREME".**

## 9. Abrir a catraca (relé) — com cuidado

Faça os testes **sem a fechadura/solenoide ligada** primeiro.

- Até aqui, o porteiro só responde "liberado"/"negado" e o iDFace mostra
  na tela. Pra ele **acionar o relé**, é preciso dizer qual comando o
  seu aparelho usa (depende de como o relé está ligado). Num iDFace Pro
  com módulo de acionamento (SecBox/MAE), foi confirmado este formato:

  ```
  npm run catraca -- configurar-abertura ID_DO_APARELHO "[{\"action\":\"sec_box\",\"parameters\":{\"id\":65793,\"reason\":3}}]"
  ```

  O `id` (65793) é do módulo de **outro** aparelho — confira o do seu
  na tela do iDFace antes.
- Só depois de ver o relé estalar certo, ligue a solenoide de 12 V.

---

## Como funciona no dia a dia

| Situação | O que acontece |
|---|---|
| Aluno em dia, com matrícula | Libera |
| Mensalidade atrasada além da tolerância | Nega |
| Sem matrícula ativa / matrícula vencida | Nega ("plano expirado") |
| Aluno bloqueado ou inativo | Nega |
| Rosto cadastrado mas não vinculado no sistema | Nega |
| Pagou na recepção | Libera na hora (o pagamento renova a matrícula) |

Toda tentativa fica registrada e aparece na ficha do aluno, aba
**Frequência**. A janela do porteiro também mostra cada entrada
(LIBERADO / NEGADO) em tempo real.

**Se cair a internet ou o computador desligar:** o iDFace não consegue
perguntar ao porteiro e segue a regra de "sem conexão" configurada nele
mesmo (o recomendado é **não liberar**, pra ninguém entrar sem conferir a
mensalidade). A recepção pode liberar manualmente pelo próprio aparelho.

## Comandos úteis

```
npm run porteiro                         inicia o porteiro
npm run catraca                          lista os comandos de configuração
npm run catraca -- listar-dispositivos   aparelhos cadastrados e quantos alunos vinculados
```

## Para quem mantém o código

- O porteiro é `porteiro-local.js`; reaproveita `lib/access/` inteiro
  (o mesmo da Cloud Function `controlIdNewUserIdentified`, que fica no
  código pro dia em que o projeto usar o plano Blaze).
- Testes: `npm run test:porteiro` (servidor HTTP de verdade contra o
  Firestore Emulator) e `npm test` (lógica pura).
- A pasta `catraca-servico-local/` na raiz é um desenho antigo (solenoide
  controlada por um computador, sem iDFace) e não é usada.
