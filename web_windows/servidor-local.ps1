# Servidor local do GYM XTREME (versao Web) para Windows.
# Serve esta pasta em http://localhost e abre o navegador. Nao precisa
# instalar nada: usa so o PowerShell que ja vem no Windows.
# (Arquivo so com caracteres ASCII de proposito: o PowerShell 5.1 le
# .ps1 sem BOM como ANSI.)

$ErrorActionPreference = 'Stop'
$raiz = [IO.Path]::GetFullPath($PSScriptRoot)

$tipos = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript'; '.mjs' = 'text/javascript'
  '.json' = 'application/json'; '.css' = 'text/css'; '.wasm' = 'application/wasm'
  '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif'
  '.webp' = 'image/webp'; '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon'
  '.ttf' = 'font/ttf'; '.otf' = 'font/otf'; '.woff' = 'font/woff'; '.woff2' = 'font/woff2'
  '.mp4' = 'video/mp4'; '.txt' = 'text/plain; charset=utf-8'
}

# Primeira porta livre entre 8090 e 8099.
$listener = $null
$porta = 0
foreach ($p in 8090..8099) {
  $tentativa = New-Object System.Net.HttpListener
  $tentativa.Prefixes.Add("http://localhost:$p/")
  try { $tentativa.Start(); $listener = $tentativa; $porta = $p; break } catch { $tentativa.Close() }
}
if ($null -eq $listener) {
  Write-Host 'Nao consegui abrir nenhuma porta entre 8090 e 8099.'
  exit 1
}

$endereco = "http://localhost:$porta/"
Write-Host ''
Write-Host "  GYM XTREME aberto em $endereco"
Write-Host '  Deixe esta janela aberta enquanto usa o app.'
Write-Host '  Para encerrar, feche esta janela.'
Write-Host ''
Start-Process $endereco

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $resposta = $ctx.Response
  try {
    $relativo = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if ($relativo -eq '') { $relativo = 'index.html' }
    $arquivo = [IO.Path]::GetFullPath((Join-Path $raiz $relativo))
    # Fora da pasta ou inexistente: devolve o app (rotas internas do Flutter).
    if (-not $arquivo.StartsWith($raiz, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $arquivo -PathType Leaf)) {
      $arquivo = Join-Path $raiz 'index.html'
    }
    $ext = [IO.Path]::GetExtension($arquivo).ToLower()
    if ($tipos.ContainsKey($ext)) { $resposta.ContentType = $tipos[$ext] } else { $resposta.ContentType = 'application/octet-stream' }
    if ($ext -eq '.html' -or $relativo -eq 'flutter_service_worker.js') { $resposta.AddHeader('Cache-Control', 'no-cache') }
    $bytes = [IO.File]::ReadAllBytes($arquivo)
    $resposta.ContentLength64 = $bytes.Length
    $resposta.OutputStream.Write($bytes, 0, $bytes.Length)
  } catch {
    # Navegador cancelou o pedido no meio, por exemplo. Segue atendendo.
    try { $resposta.StatusCode = 500 } catch { }
  } finally {
    try { $resposta.OutputStream.Close() } catch { }
  }
}
