#!/usr/bin/env bash
# =====================================================================
#  Dev Studio — installation dans le conteneur LXC (Debian 12)
#  Usage (DANS le conteneur, en root) :  bash devstudio-install.sh
#  Relançable sans risque : ton mot de passe et tes projets sont conservés.
# =====================================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 LANG=C.UTF-8

ROOT="${DS_ROOT:-}"
DASH="$ROOT/var/www/dashboard"
DATA="$ROOT/var/lib/devstudio"

c_ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
c_step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
c_warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }

write_files() {
  rm -rf "$DASH"
  mkdir -p "$DASH/inc" "$DASH/assets"
cat > "$DASH/index.php" <<'DSEOF_0_INDEX_PHP'
<?php
declare(strict_types=1);
require __DIR__ . '/inc/common.php';
ds_session();

$error = '';

if (isset($_GET['logout'])) {
    $_SESSION = [];
    session_destroy();
    header('Location: ./');
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST' && ($_POST['do'] ?? '') === 'login') {
    $cfg  = ds_config();
    $user = (string)($_POST['username'] ?? '');
    $pass = (string)($_POST['password'] ?? '');
    $okUser = hash_equals((string)($cfg['username'] ?? ''), $user);
    $okPass = password_verify($pass, (string)($cfg['password_hash'] ?? ''));
    if ($okUser && $okPass) {
        session_regenerate_id(true);
        $_SESSION['user'] = $user;
        $_SESSION['csrf'] = bin2hex(random_bytes(16));
        header('Location: ./');
        exit;
    }
    sleep(1);
    $error = 'Identifiant ou mot de passe incorrect.';
}

$v = DS_VERSION;
$h = fn($s) => htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8');

if (!ds_logged()):
?><!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dev Studio — Connexion</title>
<link rel="stylesheet" href="assets/app.css?v=<?= $v ?>">
</head>
<body class="login-body">
  <form class="login-card" method="post" autocomplete="on">
    <div class="login-logo"><span class="logo-mark">&lt;/&gt;</span> Dev&nbsp;Studio</div>
    <p class="login-sub">Serveur de dev local · Proxmox</p>
    <input type="hidden" name="do" value="login">
    <label>Identifiant
      <input name="username" autocomplete="username" required autofocus value="<?= $h($_POST['username'] ?? '') ?>">
    </label>
    <label>Mot de passe
      <input name="password" type="password" autocomplete="current-password" required>
    </label>
    <?php if ($error): ?><div class="login-error"><?= $h($error) ?></div><?php endif; ?>
    <button class="btn btn-primary btn-block" type="submit">Se connecter</button>
  </form>
</body>
</html>
<?php
exit;
endif;

$cm = 'https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.13';
?><!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dev Studio</title>
<link rel="stylesheet" href="<?= $cm ?>/codemirror.min.css">
<link rel="stylesheet" href="<?= $cm ?>/addon/dialog/dialog.min.css">
<link rel="stylesheet" href="assets/app.css?v=<?= $v ?>">
<script>window.DS = { csrf: <?= json_encode(ds_csrf()) ?>, user: <?= json_encode($_SESSION['user']) ?>, version: <?= json_encode($v) ?> };</script>
<?php foreach ([
  'codemirror.min.js',
  'mode/xml/xml.min.js', 'mode/javascript/javascript.min.js', 'mode/css/css.min.js',
  'mode/htmlmixed/htmlmixed.min.js', 'mode/clike/clike.min.js', 'mode/php/php.min.js',
  'mode/sql/sql.min.js', 'mode/markdown/markdown.min.js', 'mode/jsx/jsx.min.js',
  'mode/shell/shell.min.js', 'mode/yaml/yaml.min.js',
  'addon/edit/closebrackets.min.js', 'addon/edit/closetag.min.js', 'addon/edit/matchbrackets.min.js',
  'addon/fold/xml-fold.min.js', 'addon/edit/matchtags.min.js', 'addon/selection/active-line.min.js',
  'addon/dialog/dialog.min.js', 'addon/search/searchcursor.min.js', 'addon/search/search.min.js',
  'addon/comment/comment.min.js',
] as $s): ?>
<script src="<?= $cm ?>/<?= $s ?>"></script>
<?php endforeach; ?>
</head>
<body>
<div class="app">
  <nav class="rail">
    <div class="rail-logo" title="Dev Studio">&lt;/&gt;</div>
    <button class="rail-btn active" data-view="projects" title="Projets"><i data-icon="grid"></i><span>Projets</span></button>
    <button class="rail-btn" data-view="editor" title="Éditeur"><i data-icon="code"></i><span>Éditeur</span></button>
    <button class="rail-btn" data-view="db" title="Base de données"><i data-icon="database"></i><span>SQL</span></button>
    <button class="rail-btn" data-view="terminal" title="Terminal"><i data-icon="terminal"></i><span>Terminal</span></button>
    <div class="rail-spacer"></div>
    <button class="rail-btn" data-view="settings" title="Paramètres"><i data-icon="sliders"></i><span>Réglages</span></button>
    <a class="rail-btn" href="?logout=1" title="Déconnexion"><i data-icon="logout"></i><span>Sortir</span></a>
  </nav>

  <main class="main">
    <!-- PROJETS -->
    <section class="view active" id="view-projects">
      <header class="page-head">
        <div>
          <h1>Projets</h1>
          <p class="muted">Tout ce qui est dans <code>/var/www</code>. Chaque dossier est servi sur <code id="host-hint"></code>.</p>
        </div>
        <button class="btn btn-primary" id="btn-new-project"><i data-icon="plus"></i>Nouveau projet</button>
      </header>
      <div class="stats" id="stats"></div>
      <div class="project-grid" id="project-grid"></div>
    </section>

    <!-- ÉDITEUR -->
    <section class="view" id="view-editor">
      <aside class="explorer" id="explorer">
        <div class="explorer-head">
          <div class="crumbs" id="crumbs"></div>
          <div class="explorer-tools">
            <button class="icon-btn" id="ex-up" title="Dossier parent"><i data-icon="arrowUp"></i></button>
            <button class="icon-btn" id="ex-newfile" title="Nouveau fichier"><i data-icon="filePlus"></i></button>
            <button class="icon-btn" id="ex-newfolder" title="Nouveau dossier"><i data-icon="folderPlus"></i></button>
            <button class="icon-btn" id="ex-upload" title="Importer des fichiers"><i data-icon="upload"></i></button>
            <button class="icon-btn" id="ex-upload-dir" title="Importer un dossier"><i data-icon="folderUp"></i></button>
            <button class="icon-btn" id="ex-refresh" title="Actualiser"><i data-icon="refresh"></i></button>
          </div>
        </div>
        <div class="file-list" id="file-list"></div>
        <div class="drop-hint"><i data-icon="upload"></i> Glisse des fichiers ou des dossiers depuis ton PC</div>
        <div class="upload-bar hidden" id="upload-bar"><div class="upload-fill" id="upload-fill"></div><span id="upload-text"></span></div>
        <div class="drop-overlay" id="drop-overlay"><div><i data-icon="upload"></i><b>Dépose ici</b><span id="drop-target"></span></div></div>
        <input type="file" id="file-input" multiple hidden>
        <input type="file" id="dir-input" webkitdirectory multiple hidden>
      </aside>

      <div class="editor-area">
        <div class="tabs-bar">
          <div class="tabs" id="tabs"></div>
          <div class="editor-tools">
            <button class="btn btn-ghost btn-sm" id="ed-save" title="Ctrl+S"><i data-icon="save"></i>Enregistrer</button>
            <button class="btn btn-ghost btn-sm" id="ed-preview" title="Aperçu à côté"><i data-icon="columns"></i>Aperçu</button>
            <button class="btn btn-ghost btn-sm" id="ed-open" title="Ouvrir dans un nouvel onglet"><i data-icon="external"></i>Onglet</button>
          </div>
        </div>
        <div class="editor-split">
          <div class="editor-host" id="editor-host">
            <div class="empty-editor" id="empty-editor">
              <div class="empty-mark">&lt;/&gt;</div>
              <p>Ouvre un fichier depuis l'explorateur.</p>
              <p class="muted small">Ctrl+S enregistrer · Ctrl+F rechercher · Ctrl+/ commenter</p>
            </div>
          </div>
          <div class="preview-pane hidden" id="preview-pane">
            <div class="preview-bar">
              <button class="icon-btn" id="pv-reload" title="Recharger"><i data-icon="refresh"></i></button>
              <input class="preview-url" id="pv-url" spellcheck="false">
              <button class="icon-btn" id="pv-ext" title="Ouvrir dans un onglet"><i data-icon="external"></i></button>
              <button class="icon-btn" id="pv-close" title="Fermer"><i data-icon="x"></i></button>
            </div>
            <iframe id="pv-frame" title="Aperçu"></iframe>
          </div>
        </div>
        <div class="status-bar"><span id="st-file">—</span><span id="st-mode"></span><span id="st-pos"></span></div>
      </div>
    </section>

    <!-- BASE DE DONNÉES -->
    <section class="view" id="view-db">
      <aside class="db-side">
        <div class="side-head">
          <b>Bases de données</b>
          <button class="icon-btn" id="db-new" title="Nouvelle base"><i data-icon="plus"></i></button>
        </div>
        <div class="db-tree" id="db-tree"></div>
      </aside>
      <div class="db-main">
        <div class="db-head">
          <div class="db-title" id="db-title">Choisis une base</div>
          <div class="db-tabs" id="db-tabs">
            <button data-dbtab="tables" class="active">Tables</button>
            <button data-dbtab="data">Données</button>
            <button data-dbtab="structure">Structure</button>
            <button data-dbtab="sql">SQL</button>
          </div>
        </div>
        <div class="db-body">
          <div class="db-pane active" id="db-pane-tables"></div>
          <div class="db-pane" id="db-pane-data"></div>
          <div class="db-pane" id="db-pane-structure"></div>
          <div class="db-pane" id="db-pane-sql">
            <div class="sql-toolbar">
              <button class="btn btn-primary btn-sm" id="sql-run"><i data-icon="play"></i>Exécuter <kbd>Ctrl+Entrée</kbd></button>
              <span class="muted small" id="sql-db-label"></span>
              <div class="grow"></div>
              <button class="btn btn-ghost btn-sm" data-snippet="select">SELECT</button>
              <button class="btn btn-ghost btn-sm" data-snippet="insert">INSERT</button>
              <button class="btn btn-ghost btn-sm" data-snippet="update">UPDATE</button>
              <button class="btn btn-ghost btn-sm" data-snippet="create">CREATE TABLE</button>
            </div>
            <div class="sql-editor" id="sql-editor"></div>
            <div class="sql-results" id="sql-results"></div>
          </div>
        </div>
      </div>
    </section>

    <!-- TERMINAL -->
    <section class="view" id="view-terminal">
      <div class="term-main">
        <div class="term-head">
          <label class="term-cwd">Dossier
            <select id="term-cwd"></select>
          </label>
          <div class="term-quick" id="term-quick">
            <button class="btn btn-ghost btn-sm" data-cmd="npm install">npm install</button>
            <button class="btn btn-ghost btn-sm" data-cmd="npm run build">npm run build</button>
            <button class="btn btn-ghost btn-sm" data-cmd="npm run dev">npm run dev</button>
            <button class="btn btn-ghost btn-sm" data-cmd="ls -la">ls -la</button>
            <button class="btn btn-ghost btn-sm" data-cmd="php -v && node -v && npm -v">versions</button>
          </div>
        </div>
        <div class="term-out" id="term-out"><div class="muted">Lance une commande ci-dessous ou un bouton rapide. Les commandes tournent en arrière-plan : tu peux changer d'onglet.</div></div>
        <form class="term-input" id="term-form">
          <span class="prompt" id="term-prompt">$</span>
          <input id="term-cmd" autocomplete="off" spellcheck="false" placeholder="ex : npm install axios">
          <button class="btn btn-primary btn-sm" type="submit"><i data-icon="play"></i>Lancer</button>
        </form>
      </div>
      <aside class="jobs-side">
        <div class="side-head"><b>Processus</b><button class="icon-btn" id="jobs-clear" title="Effacer les terminés"><i data-icon="trash"></i></button></div>
        <div class="jobs-list" id="jobs-list"></div>
      </aside>
    </section>

    <!-- PARAMÈTRES -->
    <section class="view" id="view-settings">
      <header class="page-head"><div><h1>Paramètres</h1><p class="muted">Compte, sécurité et infos de connexion.</p></div></header>
      <div class="settings-grid">
        <form class="card" id="form-password">
          <h2><i data-icon="lock"></i>Mot de passe</h2>
          <label>Mot de passe actuel<input type="password" name="current" autocomplete="current-password" required></label>
          <label>Nouveau mot de passe<input type="password" name="new" autocomplete="new-password" minlength="8" required></label>
          <label>Confirmer<input type="password" name="confirm" autocomplete="new-password" minlength="8" required></label>
          <div class="pw-meter"><div id="pw-meter-fill"></div></div>
          <button class="btn btn-primary" type="submit">Changer le mot de passe</button>
        </form>
        <form class="card" id="form-username">
          <h2><i data-icon="user"></i>Identifiant</h2>
          <label>Nouvel identifiant<input name="username" required pattern="[A-Za-z0-9_.\-]{3,32}"></label>
          <label>Mot de passe actuel<input type="password" name="current" autocomplete="current-password" required></label>
          <button class="btn btn-primary" type="submit">Changer l'identifiant</button>
        </form>
        <div class="card" id="card-dbinfo">
          <h2><i data-icon="database"></i>MySQL pour tes projets PHP</h2>
          <div id="dbinfo"></div>
        </div>
        <div class="card" id="card-server">
          <h2><i data-icon="server"></i>Serveur</h2>
          <div id="serverinfo"></div>
        </div>
      </div>
    </section>
  </main>
</div>
<div id="modal-root"></div>
<div id="toasts"></div>
<script src="assets/app.js?v=<?= $v ?>"></script>
</body>
</html>
DSEOF_0_INDEX_PHP
cat > "$DASH/api.php" <<'DSEOF_1_API_PHP'
<?php
declare(strict_types=1);
require __DIR__ . '/inc/common.php';

ds_session();
header('Cache-Control: no-store');

if (!ds_logged()) {
    http_response_code(401);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => 'Session expirée, reconnecte-toi']);
    exit;
}

$action = (string)($_GET['action'] ?? '');
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'POST' && !hash_equals((string)($_SESSION['csrf'] ?? ''), (string)($_SERVER['HTTP_X_CSRF_TOKEN'] ?? ''))) {
    http_response_code(403);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => 'Jeton CSRF invalide, recharge la page']);
    exit;
}

// Libère le verrou de session (sauf pour les actions qui modifient la session)
if (!in_array($action, ['settings_username'], true)) session_write_close();

$IN = [];
if ($method === 'POST') {
    $ct = $_SERVER['CONTENT_TYPE'] ?? '';
    if (stripos($ct, 'application/json') !== false) {
        $IN = json_decode((string)file_get_contents('php://input'), true) ?: [];
    } else {
        $IN = $_POST;
    }
}

function in(string $k, $d = null) { global $IN; return $IN[$k] ?? $_GET[$k] ?? $d; }
function out(array $data = []): void {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['ok' => true] + $data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE | JSON_PARTIAL_OUTPUT_ON_ERROR);
    exit;
}
function need_post(): void { global $method; if ($method !== 'POST') throw new DsError('Méthode POST requise'); }

try {
    switch ($action) {

    /* ================= FICHIERS ================= */
    case 'list': {
        $rel = ds_rel((string)in('path', ''));
        $dir = ds_abs($rel);
        if (!is_dir($dir) || !ds_inside($dir)) { $rel = ''; $dir = DS_WWW; }
        $items = [];
        foreach (scandir($dir) ?: [] as $f) {
            if ($f === '.' || $f === '..') continue;
            if ($rel === '' && $f === DS_SELF) continue;
            $full = "$dir/$f";
            $isDir = is_dir($full);
            $items[] = [
                'name'  => $f,
                'path'  => ltrim("$rel/$f", '/'),
                'dir'   => $isDir,
                'size'  => $isDir ? 0 : (int)@filesize($full),
                'mtime' => (int)@filemtime($full),
                'link'  => is_link($full),
            ];
        }
        usort($items, fn($a, $b) => [$b['dir'], strtolower($a['name'])] <=> [$a['dir'], strtolower($b['name'])]);
        out(['path' => $rel, 'items' => $items]);
    }

    case 'read': {
        $f = ds_existing((string)in('path', ''));
        if (!is_file($f)) throw new DsError("Ce n'est pas un fichier");
        $size = filesize($f);
        if ($size > 3 * 1024 * 1024) throw new DsError('Fichier trop gros pour l\'éditeur (> 3 Mo)');
        $c = (string)file_get_contents($f);
        $binary = strpos(substr($c, 0, 8000), "\0") !== false;
        out(['path' => ds_relof($f), 'content' => $binary ? '' : $c, 'binary' => $binary, 'size' => $size, 'mtime' => filemtime($f)]);
    }

    case 'save': {
        need_post();
        $rel = (string)in('path', '');
        $abs = file_exists(ds_abs($rel)) ? ds_existing($rel) : ds_new($rel);
        if (is_dir($abs)) throw new DsError('Impossible : c\'est un dossier');
        if (file_put_contents($abs, (string)in('content', '')) === false) throw new DsError('Écriture impossible (permissions ?)');
        clearstatcache();
        out(['size' => filesize($abs), 'mtime' => filemtime($abs)]);
    }

    case 'create_file': {
        need_post();
        $abs = ds_new((string)in('path', ''));
        if (file_exists($abs)) throw new DsError('Existe déjà');
        if (file_put_contents($abs, '') === false) throw new DsError('Création impossible');
        out(['path' => ds_relof($abs)]);
    }

    case 'mkdir': {
        need_post();
        $abs = ds_new((string)in('path', ''));
        if (file_exists($abs)) throw new DsError('Existe déjà');
        if (!mkdir($abs, 0775, true)) throw new DsError('Création impossible');
        out(['path' => ds_relof($abs)]);
    }

    case 'rename': {
        need_post();
        $from = ds_existing((string)in('from', ''));
        $to   = ds_new((string)in('to', ''));
        if (file_exists($to)) throw new DsError('La destination existe déjà');
        if ($from === DS_WWW) throw new DsError('Interdit');
        if (!rename($from, $to)) throw new DsError('Renommage impossible');
        out(['path' => ds_relof($to)]);
    }

    case 'delete': {
        need_post();
        $paths = (array)in('paths', []);
        foreach ($paths as $p) {
            $abs = ds_existing((string)$p);
            if ($abs === DS_WWW) throw new DsError('Interdit');
            ds_rrmdir($abs);
        }
        out(['deleted' => count($paths)]);
    }

    case 'upload': {
        need_post();
        if (empty($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
            $code = $_FILES['file']['error'] ?? -1;
            throw new DsError($code === UPLOAD_ERR_INI_SIZE || $code === UPLOAD_ERR_FORM_SIZE ? 'Fichier trop gros' : "Échec de l'envoi (code $code)");
        }
        $dir = ds_rel((string)in('dir', ''));
        $relPath = ds_rel((string)in('relpath', '') ?: $_FILES['file']['name']);
        $target = ltrim("$dir/$relPath", '/');
        $parentRel = dirname($target) === '.' ? '' : dirname($target);
        $parentAbs = ds_abs($parentRel);
        if (!is_dir($parentAbs)) {
            // vérifie le premier ancêtre existant
            $probe = $parentAbs;
            while (!file_exists($probe) && $probe !== DS_WWW) $probe = dirname($probe);
            if (!ds_inside($probe)) throw new DsError('Accès refusé');
            if (!@mkdir($parentAbs, 0775, true) && !is_dir($parentAbs)) throw new DsError('Impossible de créer ' . $parentRel);
        }
        $abs = ds_new($target);
        if (!move_uploaded_file($_FILES['file']['tmp_name'], $abs)) throw new DsError('Déplacement impossible');
        @chmod($abs, 0664);
        out(['path' => ds_relof($abs)]);
    }

    case 'download': {
        $abs = ds_existing((string)in('path', ''));
        if (is_dir($abs)) {
            $tmp = tempnam(sys_get_temp_dir(), 'dsz');
            $zip = new ZipArchive();
            $zip->open($tmp, ZipArchive::OVERWRITE);
            $base = basename($abs);
            $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($abs, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::SELF_FIRST);
            foreach ($it as $f) {
                $local = $base . '/' . substr($f->getPathname(), strlen($abs) + 1);
                if (strpos($local, '/node_modules/') !== false) continue;
                if ($f->isDir()) $zip->addEmptyDir($local); else $zip->addFile($f->getPathname(), $local);
            }
            $zip->close();
            header('Content-Type: application/zip');
            header('Content-Disposition: attachment; filename="' . rawurlencode($base) . '.zip"');
            header('Content-Length: ' . filesize($tmp));
            readfile($tmp);
            @unlink($tmp);
            exit;
        }
        header('Content-Type: application/octet-stream');
        header("Content-Disposition: attachment; filename*=UTF-8''" . rawurlencode(basename($abs)));
        header('Content-Length: ' . filesize($abs));
        readfile($abs);
        exit;
    }

    case 'extract': {
        need_post();
        $abs = ds_existing((string)in('path', ''));
        $zip = new ZipArchive();
        if ($zip->open($abs) !== true) throw new DsError('Archive ZIP illisible');
        $dest = dirname($abs) . '/' . preg_replace('/\.zip$/i', '', basename($abs));
        $n = 1; $baseDest = $dest;
        while (file_exists($dest)) $dest = $baseDest . '-' . (++$n);
        mkdir($dest, 0775, true);
        $zip->extractTo($dest);
        $zip->close();
        out(['path' => ds_relof($dest)]);
    }

    /* ================= PROJETS ================= */
    case 'projects': {
        $list = [];
        foreach (scandir(DS_WWW) ?: [] as $f) {
            if ($f[0] === '.' || $f === DS_SELF) continue;
            $p = DS_WWW . "/$f";
            if (!is_dir($p)) continue;
            $type = 'html';
            $pkg = "$p/package.json";
            if (is_file($pkg)) {
                $j = json_decode((string)file_get_contents($pkg), true) ?: [];
                $deps = array_merge($j['dependencies'] ?? [], $j['devDependencies'] ?? []);
                $type = isset($deps['react']) ? 'react' : 'node';
            } elseif (glob("$p/*.php")) {
                $type = 'php';
            } elseif (!glob("$p/*.htm*")) {
                $type = 'folder';
            }
            $main = null;
            foreach (['index.php', 'index.html', 'src/App.jsx', 'src/App.tsx', 'README.md'] as $m) {
                if (is_file("$p/$m")) { $main = "$f/$m"; break; }
            }
            $list[] = [
                'name' => $f, 'type' => $type, 'mtime' => filemtime($p), 'main' => $main,
                'dist' => is_file("$p/dist/index.html"),
                'node_modules' => is_dir("$p/node_modules"),
            ];
        }
        usort($list, fn($a, $b) => $b['mtime'] <=> $a['mtime']);
        out(['projects' => $list]);
    }

    case 'project_create': {
        need_post();
        $name = (string)in('name', '');
        if (!preg_match('/^[A-Za-z0-9][A-Za-z0-9_\-]{0,63}$/', $name)) throw new DsError('Nom : lettres, chiffres, - et _ (sans espace)');
        $abs = ds_new($name);
        if (file_exists($abs)) throw new DsError('Un projet porte déjà ce nom');
        $tpl = (string)in('template', 'html');
        mkdir($abs, 0775, true);
        require __DIR__ . '/inc/templates.php';
        try { $res = ds_template($tpl, $name, $abs); }
        catch (Throwable $e) { ds_rrmdir($abs); throw $e; }
        out(['path' => $name] + $res);
    }

    /* ================= PROCESSUS / TERMINAL ================= */
    case 'run': {
        need_post();
        $job = ds_run_job((string)in('cwd', ''), (string)in('cmd', ''));
        out(['job' => ds_job_state($job)]);
    }

    case 'job_poll': {
        $meta = ds_job_state(ds_job_meta((string)in('id', '')));
        $offset = max(0, (int)in('offset', 0));
        $log = ds_jobs_dir() . '/' . $meta['id'] . '.log';
        $chunk = '';
        if ($meta['size'] > $offset) {
            $fh = fopen($log, 'rb');
            fseek($fh, $offset);
            $chunk = (string)fread($fh, min(512 * 1024, $meta['size'] - $offset));
            fclose($fh);
        }
        out(['job' => $meta, 'chunk' => $chunk, 'offset' => $offset + strlen($chunk)]);
    }

    case 'job_kill': {
        need_post();
        $meta = ds_job_meta((string)in('id', ''));
        $pid = (int)$meta['pid'];
        if ($pid > 1 && file_exists("/proc/$pid")) {
            @posix_kill(-$pid, SIGTERM);
            usleep(600000);
            if (file_exists("/proc/$pid")) @posix_kill(-$pid, SIGKILL);
            file_put_contents(ds_jobs_dir() . '/' . $meta['id'] . '.log', "\n[Arrêté par l'utilisateur]\n__DS_EXIT__:143\n", FILE_APPEND);
        }
        out();
    }

    case 'jobs': {
        $jobs = [];
        foreach (glob(ds_jobs_dir() . '/*.json') ?: [] as $f) {
            $m = json_decode((string)file_get_contents($f), true);
            if ($m) $jobs[] = ds_job_state($m);
        }
        usort($jobs, fn($a, $b) => strcmp($b['id'], $a['id']));
        out(['jobs' => array_slice($jobs, 0, 40)]);
    }

    case 'jobs_clear': {
        need_post();
        foreach (glob(ds_jobs_dir() . '/*.json') ?: [] as $f) {
            $m = json_decode((string)file_get_contents($f), true);
            if ($m && !ds_job_state($m)['running']) {
                @unlink($f);
                @unlink(substr($f, 0, -5) . '.log');
            }
        }
        out();
    }

    /* ================= BASE DE DONNÉES ================= */
    case 'db_list': {
        $pdo = ds_pdo();
        $sizes = [];
        foreach ($pdo->query('SELECT table_schema s, COUNT(*) n, COALESCE(SUM(data_length+index_length),0) b FROM information_schema.tables GROUP BY table_schema') as $r) {
            $sizes[$r['s']] = ['tables' => (int)$r['n'], 'bytes' => (int)$r['b']];
        }
        $dbs = [];
        foreach ($pdo->query('SHOW DATABASES')->fetchAll(PDO::FETCH_COLUMN) as $d) {
            $dbs[] = ['name' => $d, 'system' => in_array($d, DS_SYSTEM_DBS, true)] + ($sizes[$d] ?? ['tables' => 0, 'bytes' => 0]);
        }
        out(['dbs' => $dbs, 'version' => $pdo->query('SELECT VERSION()')->fetchColumn()]);
    }

    case 'db_create': {
        need_post();
        $n = ds_dbname((string)in('name', ''));
        $pdo = ds_pdo();
        $pdo->exec('CREATE DATABASE ' . ds_qi($n) . ' CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
        $app = ds_config()['app_db']['user'] ?? 'dev_user';
        if (in('grant', true)) $pdo->exec('GRANT ALL PRIVILEGES ON ' . ds_qi($n) . ".* TO " . $pdo->quote($app) . "@'localhost'");
        out();
    }

    case 'db_drop': {
        need_post();
        $n = ds_dbname((string)in('name', ''));
        if (in_array($n, DS_SYSTEM_DBS, true)) throw new DsError('Base système protégée');
        ds_pdo()->exec('DROP DATABASE ' . ds_qi($n));
        out();
    }

    case 'db_tables': {
        $db = ds_dbname((string)in('db', ''));
        $rows = ds_pdo($db)->query('SHOW TABLE STATUS')->fetchAll();
        $t = array_map(fn($r) => [
            'name' => $r['Name'], 'rows' => (int)$r['Rows'], 'engine' => $r['Engine'],
            'bytes' => (int)$r['Data_length'] + (int)$r['Index_length'], 'collation' => $r['Collation'],
            'view' => $r['Comment'] === 'VIEW',
        ], $rows);
        out(['tables' => $t]);
    }

    case 'db_browse': {
        $db = ds_dbname((string)in('db', ''));
        $t  = (string)in('table', '');
        $pdo = ds_pdo($db);
        $cols = $pdo->query('SHOW COLUMNS FROM ' . ds_qi($t))->fetchAll();
        $colNames = array_column($cols, 'Field');
        $pk = array_values(array_map(fn($c) => $c['Field'], array_filter($cols, fn($c) => $c['Key'] === 'PRI')));
        $per = min(500, max(10, (int)in('per', 50)));
        $page = max(1, (int)in('page', 1));
        $order = (string)in('order', '');
        $dir = strtoupper((string)in('dir', 'ASC')) === 'DESC' ? 'DESC' : 'ASC';
        $total = (int)$pdo->query('SELECT COUNT(*) FROM ' . ds_qi($t))->fetchColumn();
        $sql = 'SELECT * FROM ' . ds_qi($t);
        if ($order !== '' && in_array($order, $colNames, true)) $sql .= ' ORDER BY ' . ds_qi($order) . " $dir";
        $sql .= ' LIMIT ' . $per . ' OFFSET ' . (($page - 1) * $per);
        $rows = $pdo->query($sql)->fetchAll(PDO::FETCH_NUM);
        foreach ($rows as &$r) foreach ($r as &$v) if (is_string($v) && strlen($v) > 2000) $v = substr($v, 0, 2000) . '…';
        unset($r, $v);
        out(['columns' => $cols, 'pk' => $pk, 'rows' => $rows, 'total' => $total, 'page' => $page, 'per' => $per]);
    }

    case 'db_structure': {
        $db = ds_dbname((string)in('db', ''));
        $t  = (string)in('table', '');
        $pdo = ds_pdo($db);
        $cols = $pdo->query('SHOW FULL COLUMNS FROM ' . ds_qi($t))->fetchAll();
        $idx = $pdo->query('SHOW INDEX FROM ' . ds_qi($t))->fetchAll();
        $create = $pdo->query('SHOW CREATE TABLE ' . ds_qi($t))->fetch(PDO::FETCH_NUM)[1] ?? '';
        out(['columns' => $cols, 'indexes' => $idx, 'create' => $create]);
    }

    case 'db_row_save': {
        need_post();
        $db = ds_dbname((string)in('db', ''));
        $t  = (string)in('table', '');
        $values = (array)in('values', []);
        $where  = (array)in('where', []);
        $pdo = ds_pdo($db);
        $cols = array_column($pdo->query('SHOW COLUMNS FROM ' . ds_qi($t))->fetchAll(), 'Field');
        $set = []; $params = [];
        foreach ($values as $k => $v) {
            if (!in_array($k, $cols, true)) continue;
            $set[] = ds_qi($k) . ' = ?';
            $params[] = $v; // null => NULL
        }
        if (!$set) throw new DsError('Aucune valeur');
        if ($where) {
            $w = [];
            foreach ($where as $k => $v) { if (!in_array($k, $cols, true)) throw new DsError('Colonne inconnue'); $w[] = ds_qi($k) . ($v === null ? ' IS NULL' : ' = ?'); if ($v !== null) $params[] = $v; }
            $st = $pdo->prepare('UPDATE ' . ds_qi($t) . ' SET ' . implode(', ', $set) . ' WHERE ' . implode(' AND ', $w) . ' LIMIT 1');
        } else {
            $st = $pdo->prepare('INSERT INTO ' . ds_qi($t) . ' SET ' . implode(', ', $set));
        }
        $st->execute($params);
        out(['affected' => $st->rowCount(), 'id' => $pdo->lastInsertId()]);
    }

    case 'db_row_delete': {
        need_post();
        $db = ds_dbname((string)in('db', ''));
        $t  = (string)in('table', '');
        $where = (array)in('where', []);
        if (!$where) throw new DsError('Clé primaire requise');
        $pdo = ds_pdo($db);
        $cols = array_column($pdo->query('SHOW COLUMNS FROM ' . ds_qi($t))->fetchAll(), 'Field');
        $w = []; $params = [];
        foreach ($where as $k => $v) { if (!in_array($k, $cols, true)) throw new DsError('Colonne inconnue'); $w[] = ds_qi($k) . ' = ?'; $params[] = $v; }
        $st = $pdo->prepare('DELETE FROM ' . ds_qi($t) . ' WHERE ' . implode(' AND ', $w) . ' LIMIT 1');
        $st->execute($params);
        out(['affected' => $st->rowCount()]);
    }

    case 'db_table_op': {
        need_post();
        $db = ds_dbname((string)in('db', ''));
        $t  = (string)in('table', '');
        $op = (string)in('op', '');
        $pdo = ds_pdo($db);
        if ($op === 'truncate') $pdo->exec('TRUNCATE TABLE ' . ds_qi($t));
        elseif ($op === 'drop') $pdo->exec('DROP TABLE ' . ds_qi($t));
        elseif ($op === 'rename') $pdo->exec('RENAME TABLE ' . ds_qi($t) . ' TO ' . ds_qi((string)in('to', '')));
        else throw new DsError('Opération inconnue');
        out();
    }

    case 'db_query': {
        need_post();
        $db = (string)in('db', '');
        if ($db !== '') ds_dbname($db);
        $pdo = ds_pdo($db ?: null);
        $results = [];
        foreach (ds_split_sql((string)in('sql', '')) as $stmt) {
            $t0 = microtime(true);
            try {
                $st = $pdo->query($stmt);
                $r = ['sql' => $stmt];
                if ($st->columnCount() > 0) {
                    $cols = [];
                    for ($i = 0; $i < $st->columnCount(); $i++) $cols[] = $st->getColumnMeta($i)['name'] ?? "col$i";
                    $rows = []; $n = 0; $trunc = false;
                    while (($row = $st->fetch(PDO::FETCH_NUM)) !== false) {
                        if (++$n > 1000) { $trunc = true; continue; }
                        $rows[] = $row;
                    }
                    $r += ['columns' => $cols, 'rows' => $rows, 'count' => $n, 'truncated' => $trunc];
                } else {
                    $r['affected'] = $st->rowCount();
                }
                if (preg_match('/^\s*USE\s+`?([A-Za-z0-9_\-]+)`?/i', $stmt, $m)) $db = $m[1];
                $r['ms'] = round((microtime(true) - $t0) * 1000, 1);
                $results[] = $r;
            } catch (PDOException $e) {
                $results[] = ['sql' => $stmt, 'error' => $e->getMessage()];
                break;
            }
        }
        out(['results' => $results, 'db' => $db]);
    }

    case 'db_export': {
        $db = ds_dbname((string)in('db', ''));
        $cfg = ds_config();
        header('Content-Type: application/sql; charset=utf-8');
        header('Content-Disposition: attachment; filename="' . $db . '-' . date('Ymd-His') . '.sql"');
        $cmd = 'MYSQL_PWD=' . escapeshellarg($cfg['db']['pass'] ?? '') . ' mysqldump --single-transaction --routines --triggers -u '
             . escapeshellarg($cfg['db']['user'] ?? 'devstudio') . ' ' . escapeshellarg($db) . ' 2>&1';
        passthru($cmd);
        exit;
    }

    case 'db_import': {
        need_post();
        $db = ds_dbname((string)in('db', ''));
        if (empty($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) throw new DsError('Fichier manquant');
        $cfg = ds_config();
        $cmd = 'MYSQL_PWD=' . escapeshellarg($cfg['db']['pass'] ?? '') . ' mysql -u ' . escapeshellarg($cfg['db']['user'] ?? 'devstudio')
             . ' ' . escapeshellarg($db) . ' < ' . escapeshellarg($_FILES['file']['tmp_name']) . ' 2>&1';
        exec($cmd, $o, $code);
        if ($code !== 0) throw new DsError("Erreur d'import : " . implode("\n", $o));
        out();
    }

    /* ================= PARAMÈTRES ================= */
    case 'info': {
        $cfg = ds_config();
        $df = @disk_free_space('/'); $dt = @disk_total_space('/');
        $mem = [];
        foreach (@file('/proc/meminfo') ?: [] as $l) if (preg_match('/^(MemTotal|MemAvailable):\s+(\d+)/', $l, $m)) $mem[$m[1]] = (int)$m[2] * 1024;
        $node = trim((string)@shell_exec('node -v 2>/dev/null'));
        $npm  = trim((string)@shell_exec('HOME=' . escapeshellarg(DS_DATA . '/home') . ' npm -v 2>/dev/null'));
        $mysql = null;
        try { $mysql = ds_pdo()->query('SELECT VERSION()')->fetchColumn(); } catch (Throwable $e) { $mysql = null; }
        out([
            'user' => $_SESSION['user'] ?? '', 'php' => PHP_VERSION, 'node' => $node, 'npm' => $npm, 'mysql' => $mysql,
            'disk_free' => $df, 'disk_total' => $dt, 'mem' => $mem,
            'app_db' => ['host' => 'localhost', 'user' => $cfg['app_db']['user'] ?? 'dev_user', 'pass' => $cfg['app_db']['pass'] ?? '', 'db' => $cfg['app_db']['db'] ?? 'dev_db'],
            'hostname' => gethostname(), 'version' => DS_VERSION,
        ]);
    }

    case 'settings_password': {
        need_post();
        $cfg = ds_config();
        if (!password_verify((string)in('current', ''), (string)($cfg['password_hash'] ?? ''))) { sleep(1); throw new DsError('Mot de passe actuel incorrect'); }
        $new = (string)in('new', '');
        if (strlen($new) < 8) throw new DsError('8 caractères minimum');
        if ($new !== (string)in('confirm', '')) throw new DsError('La confirmation ne correspond pas');
        $cfg['password_hash'] = password_hash($new, PASSWORD_DEFAULT);
        ds_save_config($cfg);
        out();
    }

    case 'settings_username': {
        need_post();
        $cfg = ds_config();
        if (!password_verify((string)in('current', ''), (string)($cfg['password_hash'] ?? ''))) { sleep(1); throw new DsError('Mot de passe actuel incorrect'); }
        $u = (string)in('username', '');
        if (!preg_match('/^[A-Za-z0-9_.\-]{3,32}$/', $u)) throw new DsError('3 à 32 caractères : lettres, chiffres, . _ -');
        $cfg['username'] = $u;
        ds_save_config($cfg);
        $_SESSION['user'] = $u;
        out(['user' => $u]);
    }

    default:
        throw new DsError('Action inconnue');
    }
} catch (DsError $e) {
    http_response_code(400);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => $e->getMessage()], JSON_UNESCAPED_UNICODE);
} catch (PDOException $e) {
    http_response_code(400);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => 'SQL : ' . $e->getMessage()], JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
} catch (Throwable $e) {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => 'Erreur serveur : ' . $e->getMessage()], JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
}

/* ---------- Découpe SQL multi-requêtes ---------- */
function ds_split_sql(string $sql): array {
    $out = []; $buf = ''; $len = strlen($sql); $q = null;
    for ($i = 0; $i < $len; $i++) {
        $c = $sql[$i]; $n = $i + 1 < $len ? $sql[$i + 1] : '';
        if ($q !== null) {
            $buf .= $c;
            if ($c === '\\' && $q !== '`') { $buf .= $n; $i++; continue; }
            if ($c === $q) { if ($n === $q) { $buf .= $n; $i++; } else $q = null; }
            continue;
        }
        if ($c === "'" || $c === '"' || $c === '`') { $q = $c; $buf .= $c; continue; }
        if (($c === '-' && $n === '-') || $c === '#') {
            $j = strpos($sql, "\n", $i);
            if ($j === false) break;
            $i = $j; $buf .= "\n"; continue;
        }
        if ($c === '/' && $n === '*') {
            $j = strpos($sql, '*/', $i + 2);
            if ($j === false) break;
            $i = $j + 1; $buf .= ' '; continue;
        }
        if ($c === ';') { if (trim($buf) !== '') $out[] = trim($buf); $buf = ''; continue; }
        $buf .= $c;
    }
    if (trim($buf) !== '') $out[] = trim($buf);
    return $out;
}
DSEOF_1_API_PHP
cat > "$DASH/inc/common.php" <<'DSEOF_2_INC_COMMON_PHP'
<?php
declare(strict_types=1);

define('DS_VERSION', '1.0.0');
define('DS_DATA', getenv('DS_DATA') ?: '/var/lib/devstudio');
define('DS_WWW', rtrim(getenv('DS_WWW') ?: '/var/www', '/'));
define('DS_SELF', 'dashboard');
define('DS_CONFIG', DS_DATA . '/config.json');

class DsError extends Exception {}

/* ---------- Configuration ---------- */
$GLOBALS['ds_cfg'] = null;

function ds_config(): array {
    if ($GLOBALS['ds_cfg'] === null) {
        $raw = @file_get_contents(DS_CONFIG);
        $GLOBALS['ds_cfg'] = $raw ? (json_decode($raw, true) ?: []) : [];
    }
    return $GLOBALS['ds_cfg'];
}

function ds_save_config(array $cfg): void {
    $tmp = DS_CONFIG . '.tmp';
    if (file_put_contents($tmp, json_encode($cfg, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)) === false) {
        throw new DsError("Impossible d'écrire la configuration");
    }
    @chmod($tmp, 0600);
    rename($tmp, DS_CONFIG);
    $GLOBALS['ds_cfg'] = $cfg;
}

/* ---------- Session / auth ---------- */
function ds_session(): void {
    if (session_status() === PHP_SESSION_ACTIVE) return;
    $dir = DS_DATA . '/sessions';
    if (is_dir($dir)) session_save_path($dir);
    ini_set('session.gc_maxlifetime', '604800');
    ini_set('session.gc_probability', '1');
    ini_set('session.gc_divisor', '100');
    ini_set('session.use_strict_mode', '1');
    session_name('DSSESSID');
    session_set_cookie_params([
        'lifetime' => 604800,
        'path'     => '/' . DS_SELF . '/',
        'httponly' => true,
        'samesite' => 'Strict',
    ]);
    session_start();
}

function ds_logged(): bool { return !empty($_SESSION['user']); }

function ds_csrf(): string {
    if (empty($_SESSION['csrf'])) $_SESSION['csrf'] = bin2hex(random_bytes(16));
    return $_SESSION['csrf'];
}

/* ---------- Chemins sécurisés (tout reste dans /var/www) ---------- */
function ds_rel(string $rel): string {
    $rel = str_replace('\\', '/', $rel);
    $parts = [];
    foreach (explode('/', $rel) as $p) {
        if ($p === '' || $p === '.') continue;
        if ($p === '..' || strpos($p, "\0") !== false) throw new DsError('Chemin invalide');
        $parts[] = $p;
    }
    if ($parts && $parts[0] === DS_SELF) throw new DsError('Le dossier du dashboard est protégé');
    return implode('/', $parts);
}

function ds_abs(string $rel): string {
    $r = ds_rel($rel);
    return $r === '' ? DS_WWW : DS_WWW . '/' . $r;
}

function ds_inside(string $abs): bool {
    $real = realpath($abs);
    if ($real === false) return false;
    $self = DS_WWW . '/' . DS_SELF;
    if ($real === $self || strpos($real, $self . '/') === 0) return false;
    return $real === DS_WWW || strpos($real, DS_WWW . '/') === 0;
}

/** Chemin existant, vérifié */
function ds_existing(string $rel): string {
    $abs = ds_abs($rel);
    if (!file_exists($abs) && !is_link($abs)) throw new DsError('Introuvable : ' . ds_rel($rel));
    if (!ds_inside(is_link($abs) ? dirname($abs) : $abs)) throw new DsError('Accès refusé');
    return $abs;
}

/** Nouveau chemin (le parent doit exister et être autorisé) */
function ds_new(string $rel): string {
    $r = ds_rel($rel);
    if ($r === '') throw new DsError('Nom requis');
    $abs = DS_WWW . '/' . $r;
    if (!ds_inside(dirname($abs))) throw new DsError('Dossier parent invalide');
    $name = basename($abs);
    if ($name === '' || strlen($name) > 255) throw new DsError('Nom invalide');
    return $abs;
}

function ds_relof(string $abs): string {
    return ltrim(substr($abs, strlen(DS_WWW)), '/');
}

function ds_rrmdir(string $path): void {
    if (is_link($path) || is_file($path)) { @unlink($path); return; }
    if (!is_dir($path)) return;
    $it = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($path, FilesystemIterator::SKIP_DOTS),
        RecursiveIteratorIterator::CHILD_FIRST
    );
    foreach ($it as $f) {
        if ($f->isDir() && !$f->isLink()) @rmdir($f->getPathname());
        else @unlink($f->getPathname());
    }
    @rmdir($path);
}

/* ---------- Base de données ---------- */
function ds_pdo(?string $db = null): PDO {
    $cfg = ds_config();
    $u = $cfg['db']['user'] ?? 'devstudio';
    $p = $cfg['db']['pass'] ?? '';
    $dsn = 'mysql:host=localhost;charset=utf8mb4' . ($db !== null && $db !== '' ? ';dbname=' . $db : '');
    try {
        return new PDO($dsn, $u, $p, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => true,
        ]);
    } catch (PDOException $e) {
        throw new DsError('Connexion MariaDB impossible : ' . $e->getMessage());
    }
}

function ds_qi(string $name): string {
    return '`' . str_replace('`', '``', $name) . '`';
}

function ds_dbname(string $n): string {
    if (!preg_match('/^[A-Za-z0-9_\-]{1,64}$/', $n)) throw new DsError('Nom invalide (lettres, chiffres, _ et - uniquement)');
    return $n;
}

const DS_SYSTEM_DBS = ['information_schema', 'performance_schema', 'mysql', 'sys'];

/* ---------- Processus en arrière-plan (npm, commandes) ---------- */
function ds_jobs_dir(): string { return DS_DATA . '/jobs'; }

function ds_run_job(string $cwdRel, string $cmd, string $label = ''): array {
    $cwd = ds_abs($cwdRel);
    if (!is_dir($cwd) || !(ds_inside($cwd))) throw new DsError('Dossier de travail invalide');
    $cmd = trim($cmd);
    if ($cmd === '') throw new DsError('Commande vide');

    $id  = date('Ymd-His') . '-' . bin2hex(random_bytes(3));
    $log = ds_jobs_dir() . "/$id.log";
    touch($log);

    $script = 'cd ' . escapeshellarg($cwd) . " || exit 1\n(\n" . $cmd . "\n)\ncode=\$?\necho\necho \"__DS_EXIT__:\$code\"\n";
    $env = [
        'HOME=' . DS_DATA . '/home',
        'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
        'LANG=C.UTF-8', 'TERM=dumb', 'NO_COLOR=1', 'FORCE_COLOR=0',
        'npm_config_color=false', 'npm_config_fund=false',
        'npm_config_update_notifier=false', 'npm_config_audit=false',
        'npm_config_yes=true',
    ];
    $full = 'env -i ' . implode(' ', array_map('escapeshellarg', $env))
          . ' setsid bash -c ' . escapeshellarg($script)
          . ' > ' . escapeshellarg($log) . ' 2>&1 < /dev/null & echo $!';
    $pid = (int)trim((string)shell_exec($full));

    $meta = [
        'id' => $id, 'pid' => $pid, 'cmd' => $cmd, 'label' => $label ?: $cmd,
        'cwd' => ds_relof($cwd), 'started' => time(),
    ];
    file_put_contents(ds_jobs_dir() . "/$id.json", json_encode($meta));
    return $meta;
}

function ds_job_meta(string $id): array {
    if (!preg_match('/^[0-9]{8}-[0-9]{6}-[0-9a-f]{6}$/', $id)) throw new DsError('Job invalide');
    $f = ds_jobs_dir() . "/$id.json";
    if (!is_file($f)) throw new DsError('Job introuvable');
    return json_decode((string)file_get_contents($f), true) ?: [];
}

function ds_job_state(array $meta): array {
    $log = ds_jobs_dir() . '/' . $meta['id'] . '.log';
    $size = is_file($log) ? filesize($log) : 0;
    $exit = null;
    if ($size > 0) {
        $fh = fopen($log, 'rb');
        fseek($fh, max(0, $size - 64));
        $tail = (string)fread($fh, 64);
        fclose($fh);
        if (preg_match('/__DS_EXIT__:(\d+)\s*$/', $tail, $m)) $exit = (int)$m[1];
    }
    $alive = $exit === null && $meta['pid'] > 0 && file_exists('/proc/' . $meta['pid']);
    $meta['running'] = $alive;
    $meta['exit'] = $exit;
    if (!$alive && $exit === null) $meta['exit'] = -1; // tué / interrompu
    $meta['size'] = $size;
    return $meta;
}
DSEOF_2_INC_COMMON_PHP
cat > "$DASH/inc/templates.php" <<'DSEOF_3_INC_TEMPLATES_PHP'
<?php
declare(strict_types=1);

function ds_write_files(string $base, array $files): void {
    foreach ($files as $rel => $content) {
        $p = "$base/$rel";
        if (!is_dir(dirname($p))) mkdir(dirname($p), 0775, true);
        file_put_contents($p, $content);
    }
}

function ds_template(string $tpl, string $name, string $abs): array {
    $title = htmlspecialchars($name, ENT_QUOTES);

    if ($tpl === 'empty') return ['open' => null];

    if ($tpl === 'html') {
        ds_write_files($abs, [
            'index.html' => <<<HTML
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main>
    <h1>$title</h1>
    <p>Ton site est en ligne. Modifie <code>index.html</code>, <code>style.css</code> et <code>script.js</code>.</p>
    <button id="btn">Clique-moi</button>
    <p id="out"></p>
  </main>
  <script src="script.js"></script>
</body>
</html>

HTML,
            'style.css' => <<<'CSS'
* { box-sizing: border-box; }
body { margin: 0; font-family: system-ui, sans-serif; background: #f5f5f4; color: #1c1917; display: grid; place-items: center; min-height: 100vh; }
main { max-width: 560px; padding: 2rem; }
h1 { font-size: 2.4rem; margin: 0 0 .5rem; }
button { padding: .7rem 1.2rem; border: 0; border-radius: 8px; background: #1c1917; color: #fff; font-size: 1rem; cursor: pointer; }

CSS,
            'script.js' => <<<'JS'
let n = 0;
document.getElementById('btn').addEventListener('click', () => {
  n++;
  document.getElementById('out').textContent = `Cliqué ${n} fois`;
});

JS,
        ]);
        return ['open' => "$name/index.html"];
    }

    if ($tpl === 'php') {
        $cfg = ds_config();
        $u = $cfg['app_db']['user'] ?? 'dev_user';
        $p = $cfg['app_db']['pass'] ?? '';
        $dbname = strtolower(preg_replace('/[^A-Za-z0-9_]/', '_', $name));
        $pdo = ds_pdo();
        $pdo->exec('CREATE DATABASE IF NOT EXISTS ' . ds_qi($dbname) . ' CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
        $pdo->exec('GRANT ALL PRIVILEGES ON ' . ds_qi($dbname) . '.* TO ' . $pdo->quote($u) . "@'localhost'");
        $pdo->exec('CREATE TABLE IF NOT EXISTS ' . ds_qi($dbname) . '.`notes` (id INT AUTO_INCREMENT PRIMARY KEY, texte VARCHAR(255) NOT NULL, cree_le DATETIME DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB');
        $pe = var_export($p, true);
        $ue = var_export($u, true);
        $de = var_export($dbname, true);
        ds_write_files($abs, [
            'config.php' => <<<PHP
<?php
// Connexion à la base de données du projet (créée automatiquement)
\$pdo = new PDO(
    'mysql:host=localhost;dbname=' . $de . ';charset=utf8mb4',
    $ue,
    $pe,
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]
);

PHP,
            'index.php' => <<<'PHP'
<?php
require __DIR__ . '/config.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && trim($_POST['texte'] ?? '') !== '') {
    $st = $pdo->prepare('INSERT INTO notes (texte) VALUES (?)');
    $st->execute([trim($_POST['texte'])]);
    header('Location: ./');
    exit;
}
if (isset($_GET['suppr'])) {
    $pdo->prepare('DELETE FROM notes WHERE id = ?')->execute([(int)$_GET['suppr']]);
    header('Location: ./');
    exit;
}

$notes = $pdo->query('SELECT * FROM notes ORDER BY id DESC')->fetchAll();
$h = fn($s) => htmlspecialchars((string)$s, ENT_QUOTES);
?>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Notes — PHP + MySQL</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main>
    <h1>Notes</h1>
    <p class="sub">Exemple PHP + MariaDB : les notes sont dans la table <code>notes</code>.</p>
    <form method="post">
      <input name="texte" placeholder="Écris une note…" required autofocus>
      <button>Ajouter</button>
    </form>
    <ul>
      <?php foreach ($notes as $n): ?>
        <li>
          <span><?= $h($n['texte']) ?></span>
          <small><?= $h($n['cree_le']) ?></small>
          <a href="?suppr=<?= (int)$n['id'] ?>" title="Supprimer">✕</a>
        </li>
      <?php endforeach; ?>
      <?php if (!$notes): ?><li class="empty">Aucune note pour l'instant.</li><?php endif; ?>
    </ul>
  </main>
</body>
</html>

PHP,
            'style.css' => <<<'CSS'
* { box-sizing: border-box; }
body { margin: 0; font-family: system-ui, sans-serif; background: #fafaf9; color: #1c1917; }
main { max-width: 620px; margin: 4rem auto; padding: 0 1.25rem; }
h1 { margin: 0; font-size: 2.2rem; }
.sub { color: #78716c; }
form { display: flex; gap: .5rem; margin: 1.5rem 0; }
input { flex: 1; padding: .7rem .9rem; border: 1px solid #d6d3d1; border-radius: 8px; font-size: 1rem; }
button { padding: .7rem 1.2rem; border: 0; border-radius: 8px; background: #1c1917; color: #fff; cursor: pointer; }
ul { list-style: none; padding: 0; margin: 0; }
li { display: flex; align-items: center; gap: .75rem; padding: .8rem 1rem; background: #fff; border: 1px solid #e7e5e4; border-radius: 8px; margin-bottom: .5rem; }
li span { flex: 1; }
li small { color: #a8a29e; }
li a { color: #dc2626; text-decoration: none; }
li.empty { color: #a8a29e; justify-content: center; }

CSS,
        ]);
        return ['open' => "$name/index.php", 'db' => $dbname];
    }

    if ($tpl === 'react') {
        $pkgName = strtolower(preg_replace('/[^a-z0-9\-_]/i', '-', $name));
        ds_write_files($abs, [
            'package.json' => json_encode([
                'name' => $pkgName, 'private' => true, 'version' => '0.1.0', 'type' => 'module',
                'scripts' => [
                    'dev' => 'vite --host 0.0.0.0',
                    'build' => 'vite build',
                    'preview' => 'vite preview --host 0.0.0.0',
                ],
                'dependencies' => ['react' => '^19.1.0', 'react-dom' => '^19.1.0'],
                'devDependencies' => ['@vitejs/plugin-react' => '^4.4.1', 'vite' => '^6.3.5'],
            ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n",
            'vite.config.js' => <<<'JS'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// base './' : le build (dist/) fonctionne servi depuis http://IP/nom-du-projet/dist/
export default defineConfig({
  plugins: [react()],
  base: './',
  server: { host: true, port: 5173, allowedHosts: true },
  preview: { host: true, port: 4173, allowedHosts: true },
})

JS,
            'index.html' => <<<HTML
<!DOCTYPE html>
<html lang="fr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$title</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>

HTML,
            'src/main.jsx' => <<<'JS'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'
import './App.css'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>
)

JS,
            'src/App.jsx' => <<<JS
import { useState } from 'react'

export default function App() {
  const [count, setCount] = useState(0)

  return (
    <main>
      <h1>$title</h1>
      <p>Projet React + Vite. Modifie <code>src/App.jsx</code> puis lance un build.</p>
      <button onClick={() => setCount(c => c + 1)}>Compteur : {count}</button>
    </main>
  )
}

JS,
            'src/App.css' => <<<'CSS'
* { box-sizing: border-box; }
body { margin: 0; font-family: system-ui, sans-serif; background: #0f0f12; color: #f4f4f5; min-height: 100vh; display: grid; place-items: center; }
main { text-align: center; padding: 2rem; }
h1 { font-size: 2.6rem; margin: 0 0 .5rem; }
p { color: #a1a1aa; }
code { background: #27272a; padding: .1rem .4rem; border-radius: 4px; }
button { margin-top: 1rem; padding: .8rem 1.4rem; font-size: 1rem; border: 1px solid #3f3f46; border-radius: 10px; background: #18181b; color: #fff; cursor: pointer; }
button:hover { border-color: #61dafb; }

CSS,
            '.gitignore' => "node_modules\ndist\n",
        ]);
        $job = ds_run_job($name, 'npm install && npm run build', "Installation React ($name)");
        return ['open' => "$name/src/App.jsx", 'job' => ds_job_state($job)];
    }

    throw new DsError('Modèle inconnu');
}
DSEOF_3_INC_TEMPLATES_PHP
cat > "$DASH/assets/app.css" <<'DSEOF_4_ASSETS_APP_CSS'
:root {
  --bg: #0b0d11;
  --bg-2: #11141a;
  --bg-3: #171b23;
  --bg-4: #1e232d;
  --line: #222834;
  --line-2: #2d3442;
  --text: #e6e8ed;
  --text-2: #b9bfcc;
  --muted: #7d8596;
  --accent: #c4f25e;
  --accent-ink: #13180a;
  --accent-soft: rgba(196, 242, 94, .12);
  --blue: #7cc4ff;
  --violet: #b59cff;
  --orange: #ffb86b;
  --ok: #4ade80;
  --warn: #f5c451;
  --danger: #ff6b6b;
  --danger-soft: rgba(255, 107, 107, .12);
  --radius: 8px;
  --mono: 'JetBrains Mono', 'Cascadia Code', 'Fira Code', ui-monospace, Consolas, monospace;
  --sans: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
  color-scheme: dark;
}

* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { height: 100%; }
body { background: var(--bg); color: var(--text); font: 14px/1.45 var(--sans); overflow: hidden; }
code, kbd, pre { font-family: var(--mono); font-size: .92em; }
code { background: var(--bg-4); padding: 1px 5px; border-radius: 4px; color: var(--text-2); }
kbd { font-size: 10px; padding: 1px 4px; border: 1px solid rgba(0,0,0,.25); border-radius: 3px; opacity: .7; margin-left: 4px; }
a { color: var(--blue); }
.muted { color: var(--muted); }
.small { font-size: 12px; }
.hidden { display: none !important; }
.grow { flex: 1; }
::-webkit-scrollbar { width: 10px; height: 10px; }
::-webkit-scrollbar-thumb { background: var(--line-2); border-radius: 10px; border: 2px solid transparent; background-clip: padding-box; }
::-webkit-scrollbar-track { background: transparent; }
svg.i { width: 16px; height: 16px; stroke: currentColor; fill: none; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; flex-shrink: 0; }

/* ---------- Boutons & champs ---------- */
.btn { display: inline-flex; align-items: center; gap: 7px; border: 1px solid var(--line-2); background: var(--bg-3); color: var(--text); padding: 8px 14px; border-radius: var(--radius); font: 500 13px var(--sans); cursor: pointer; white-space: nowrap; text-decoration: none; transition: background .12s, border-color .12s; }
.btn:hover { background: var(--bg-4); border-color: #3a4253; }
.btn:disabled { opacity: .45; cursor: not-allowed; }
.btn-primary { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); font-weight: 600; }
.btn-primary:hover { background: #d4fa7d; border-color: #d4fa7d; }
.btn-danger { background: var(--danger-soft); border-color: rgba(255,107,107,.35); color: var(--danger); }
.btn-danger:hover { background: rgba(255,107,107,.2); border-color: var(--danger); }
.btn-ghost { background: transparent; border-color: transparent; color: var(--text-2); }
.btn-ghost:hover { background: var(--bg-3); border-color: var(--line); color: var(--text); }
.btn-sm { padding: 5px 9px; font-size: 12px; }
.btn-sm svg.i { width: 14px; height: 14px; }
.btn-block { width: 100%; justify-content: center; }
.icon-btn { display: inline-grid; place-items: center; width: 28px; height: 28px; border: 0; background: transparent; color: var(--muted); border-radius: 6px; cursor: pointer; }
.icon-btn:hover { background: var(--bg-4); color: var(--text); }
.icon-btn.danger:hover { color: var(--danger); background: var(--danger-soft); }

input, select, textarea { font: 13px var(--sans); color: var(--text); background: var(--bg); border: 1px solid var(--line-2); border-radius: 6px; padding: 8px 10px; outline: none; width: 100%; }
input:focus, select:focus, textarea:focus { border-color: var(--accent); box-shadow: 0 0 0 3px var(--accent-soft); }
input[type=checkbox] { width: auto; accent-color: var(--accent); }
label { display: flex; flex-direction: column; gap: 6px; font-size: 12px; color: var(--text-2); font-weight: 500; }

/* ---------- Connexion ---------- */
.login-body { display: grid; place-items: center; background:
  radial-gradient(800px 400px at 20% 0%, rgba(196,242,94,.08), transparent 60%),
  radial-gradient(700px 500px at 100% 100%, rgba(124,196,255,.06), transparent 60%), var(--bg); }
.login-card { width: min(380px, 92vw); background: var(--bg-2); border: 1px solid var(--line); border-radius: 14px; padding: 32px; display: flex; flex-direction: column; gap: 16px; box-shadow: 0 30px 80px rgba(0,0,0,.45); }
.login-logo { font: 700 22px var(--sans); display: flex; align-items: center; gap: 10px; }
.logo-mark { font-family: var(--mono); background: var(--accent); color: var(--accent-ink); padding: 4px 8px; border-radius: 7px; font-size: 15px; }
.login-sub { color: var(--muted); margin-top: -10px; font-size: 13px; }
.login-error { background: var(--danger-soft); color: var(--danger); border: 1px solid rgba(255,107,107,.3); padding: 9px 12px; border-radius: 6px; font-size: 13px; }
.login-card input { padding: 10px 12px; font-size: 14px; }

/* ---------- Layout ---------- */
.app { display: flex; height: 100vh; }
.rail { width: 72px; background: var(--bg-2); border-right: 1px solid var(--line); display: flex; flex-direction: column; align-items: center; padding: 12px 0; gap: 4px; flex-shrink: 0; }
.rail-logo { font: 700 13px var(--mono); background: var(--accent); color: var(--accent-ink); padding: 6px 7px; border-radius: 8px; margin-bottom: 14px; }
.rail-btn { width: 58px; display: flex; flex-direction: column; align-items: center; gap: 4px; padding: 8px 0; background: none; border: 0; color: var(--muted); border-radius: 8px; cursor: pointer; font: 500 10px var(--sans); text-decoration: none; position: relative; }
.rail-btn svg.i { width: 20px; height: 20px; }
.rail-btn:hover { color: var(--text); background: var(--bg-3); }
.rail-btn.active { color: var(--accent); background: var(--accent-soft); }
.rail-btn.active::before { content: ''; position: absolute; left: -7px; top: 10px; bottom: 10px; width: 3px; border-radius: 3px; background: var(--accent); }
.rail-btn .dot { position: absolute; top: 6px; right: 12px; width: 7px; height: 7px; border-radius: 50%; background: var(--accent); box-shadow: 0 0 0 2px var(--bg-2); }
.rail-spacer { flex: 1; }
.main { flex: 1; min-width: 0; position: relative; }
.view { display: none; height: 100%; }
.view.active { display: flex; }

/* ---------- Pages ---------- */
#view-projects, #view-settings { flex-direction: column; overflow-y: auto; padding: 32px 40px; gap: 24px; }
.page-head { display: flex; justify-content: space-between; align-items: flex-end; gap: 20px; flex-wrap: wrap; }
.page-head h1 { font-size: 26px; letter-spacing: -.02em; margin-bottom: 4px; }
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 12px; }
.stat { background: var(--bg-2); border: 1px solid var(--line); border-radius: 10px; padding: 14px 16px; }
.stat-label { font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: .06em; font-weight: 600; }
.stat-value { font: 600 17px var(--mono); margin-top: 4px; display: flex; align-items: center; gap: 8px; }
.stat-value .led { width: 8px; height: 8px; border-radius: 50%; background: var(--ok); box-shadow: 0 0 10px var(--ok); }
.stat-value .led.off { background: var(--danger); box-shadow: 0 0 10px var(--danger); }
.meter { height: 4px; background: var(--bg-4); border-radius: 4px; margin-top: 8px; overflow: hidden; }
.meter > div { height: 100%; background: var(--accent); }

.project-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(290px, 1fr)); gap: 14px; }
.project { background: var(--bg-2); border: 1px solid var(--line); border-radius: 12px; padding: 18px; display: flex; flex-direction: column; gap: 14px; transition: border-color .15s, transform .15s; }
.project:hover { border-color: var(--line-2); transform: translateY(-1px); }
.project-top { display: flex; align-items: center; gap: 12px; }
.project-icon { width: 40px; height: 40px; border-radius: 10px; display: grid; place-items: center; font: 700 12px var(--mono); flex-shrink: 0; }
.t-react .project-icon { background: rgba(124,196,255,.12); color: var(--blue); }
.t-php .project-icon { background: rgba(181,156,255,.12); color: var(--violet); }
.t-html .project-icon { background: rgba(255,184,107,.12); color: var(--orange); }
.t-node .project-icon { background: rgba(74,222,128,.12); color: var(--ok); }
.t-folder .project-icon { background: var(--bg-4); color: var(--muted); }
.project-name { font-weight: 600; font-size: 15px; word-break: break-all; }
.project-meta { font-size: 12px; color: var(--muted); }
.badge { display: inline-block; font: 600 10px var(--mono); padding: 2px 6px; border-radius: 4px; background: var(--bg-4); color: var(--text-2); text-transform: uppercase; letter-spacing: .04em; }
.badge.ok { background: rgba(74,222,128,.12); color: var(--ok); }
.badge.warn { background: rgba(245,196,81,.12); color: var(--warn); }
.project-actions { display: flex; gap: 6px; flex-wrap: wrap; }
.project-actions .grow { min-width: 0; }
.empty-state { grid-column: 1 / -1; border: 1px dashed var(--line-2); border-radius: 12px; padding: 48px; text-align: center; color: var(--muted); }

.tpl-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.tpl { border: 1px solid var(--line-2); border-radius: 10px; padding: 14px; cursor: pointer; background: var(--bg); display: flex; flex-direction: column; gap: 4px; text-align: left; color: var(--text); font: inherit; }
.tpl:hover { border-color: #3a4253; }
.tpl.sel { border-color: var(--accent); background: var(--accent-soft); }
.tpl b { font-size: 14px; }
.tpl span { font-size: 12px; color: var(--muted); }

/* ---------- Éditeur ---------- */
.explorer { width: 300px; background: var(--bg-2); border-right: 1px solid var(--line); display: flex; flex-direction: column; position: relative; flex-shrink: 0; }
.explorer-head { padding: 10px 10px 8px; border-bottom: 1px solid var(--line); display: flex; flex-direction: column; gap: 8px; }
.crumbs { display: flex; flex-wrap: wrap; align-items: center; gap: 2px; font: 12px var(--mono); min-height: 22px; }
.crumbs button { background: none; border: 0; color: var(--text-2); cursor: pointer; padding: 2px 4px; border-radius: 4px; font: inherit; }
.crumbs button:hover { background: var(--bg-4); color: var(--text); }
.crumbs button:last-child { color: var(--accent); }
.crumbs .sep { color: var(--line-2); }
.explorer-tools { display: flex; gap: 2px; }
.file-list { flex: 1; overflow-y: auto; padding: 6px; }
.frow { display: flex; align-items: center; gap: 8px; padding: 5px 6px 5px 8px; border-radius: 6px; cursor: pointer; user-select: none; min-height: 32px; }
.frow:hover { background: var(--bg-3); }
.frow.active { background: var(--accent-soft); }
.frow.drop-in { outline: 1px dashed var(--accent); background: var(--accent-soft); }
.frow .fname { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 13px; }
.frow .fsize { font: 11px var(--mono); color: var(--muted); }
.frow .facts { display: none; gap: 1px; }
.frow:hover .facts { display: flex; }
.frow:hover .fsize { display: none; }
.frow .facts .icon-btn { width: 24px; height: 24px; }
.frow .open-btn { font: 600 11px var(--sans); padding: 3px 8px; border-radius: 5px; border: 1px solid var(--line-2); background: var(--bg-4); color: var(--text-2); cursor: pointer; }
.frow .open-btn:hover { border-color: var(--accent); color: var(--accent); }
.ficon { width: 18px; text-align: center; font: 700 9px var(--mono); flex-shrink: 0; }
.ficon svg.i { width: 16px; height: 16px; }
.ficon.dir { color: #e8c468; }
.drop-hint { margin: 8px; padding: 12px; border: 1px dashed var(--line-2); border-radius: 8px; text-align: center; color: var(--muted); font-size: 12px; display: flex; align-items: center; justify-content: center; gap: 8px; }
.drop-overlay { position: absolute; inset: 0; background: rgba(196,242,94,.04); border: 2px dashed var(--accent); border-radius: 4px; display: none; align-items: flex-end; justify-content: center; padding-bottom: 18px; z-index: 5; pointer-events: none; }
.drop-overlay > div { background: var(--bg-3); border: 1px solid var(--line-2); padding: 10px 16px; border-radius: 10px; box-shadow: 0 10px 30px rgba(0,0,0,.5); }
.drop-overlay > div { display: flex; flex-direction: column; align-items: center; gap: 8px; color: var(--accent); }
.drop-overlay svg.i { width: 22px; height: 22px; }
.drop-overlay span { color: var(--text-2); font: 12px var(--mono); }
.explorer.dragging .drop-overlay { display: flex; }
.upload-bar { margin: 0 8px 8px; height: 24px; background: var(--bg-4); border-radius: 6px; position: relative; overflow: hidden; font-size: 11px; display: flex; align-items: center; justify-content: center; }
.upload-fill { position: absolute; left: 0; top: 0; bottom: 0; background: var(--accent-soft); border-right: 2px solid var(--accent); transition: width .15s; }
.upload-bar span { position: relative; }

.editor-area { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.tabs-bar { display: flex; align-items: stretch; background: var(--bg-2); border-bottom: 1px solid var(--line); min-height: 40px; }
.tabs { flex: 1; display: flex; overflow-x: auto; min-width: 0; }
.tabs::-webkit-scrollbar { height: 3px; }
.tab { display: flex; align-items: center; gap: 8px; padding: 0 8px 0 14px; border-right: 1px solid var(--line); cursor: pointer; color: var(--muted); font-size: 13px; white-space: nowrap; position: relative; max-width: 220px; }
.tab:hover { color: var(--text-2); background: var(--bg-3); }
.tab.active { color: var(--text); background: var(--bg); }
.tab.active::after { content: ''; position: absolute; left: 0; right: 0; top: 0; height: 2px; background: var(--accent); }
.tab .tname { overflow: hidden; text-overflow: ellipsis; }
.tab .tclose { width: 18px; height: 18px; display: grid; place-items: center; border-radius: 4px; color: var(--muted); }
.tab .tclose svg.i { width: 12px; height: 12px; }
.tab .tclose:hover { background: var(--bg-4); color: var(--text); }
.tab.dirty .tclose::before { content: '●'; font-size: 11px; color: var(--accent); }
.tab.dirty .tclose svg { display: none; }
.tab.dirty .tclose:hover::before { content: none; }
.tab.dirty .tclose:hover svg { display: block; }
.editor-tools { display: flex; align-items: center; gap: 2px; padding: 0 8px; border-left: 1px solid var(--line); }
.editor-split { flex: 1; display: flex; min-height: 0; }
.editor-host { flex: 1; min-width: 0; position: relative; background: var(--bg); }
.editor-host .CodeMirror, .editor-host textarea.fallback { position: absolute; inset: 0; height: 100%; }
.editor-host textarea.fallback { border: 0; border-radius: 0; resize: none; font: 13px/1.6 var(--mono); padding: 14px 18px; background: var(--bg); }
.empty-editor { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px; color: var(--text-2); }
.empty-mark { font: 700 44px var(--mono); color: var(--bg-4); margin-bottom: 8px; }
.binary-view { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 14px; padding: 20px; }
.binary-view img { max-width: 90%; max-height: 70%; border-radius: 6px; background: repeating-conic-gradient(#1b1f27 0 25%, #14171d 0 50%) 0 0 / 16px 16px; }
.preview-pane { width: 46%; min-width: 280px; border-left: 1px solid var(--line); display: flex; flex-direction: column; background: var(--bg-2); }
.preview-bar { display: flex; align-items: center; gap: 4px; padding: 6px; border-bottom: 1px solid var(--line); }
.preview-url { font: 12px var(--mono); padding: 5px 8px; background: var(--bg); }
.preview-pane iframe { flex: 1; border: 0; background: #fff; width: 100%; }
.status-bar { display: flex; gap: 18px; padding: 4px 14px; background: var(--bg-2); border-top: 1px solid var(--line); font: 11px var(--mono); color: var(--muted); }
.status-bar #st-file { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

/* CodeMirror : thème maison */
.CodeMirror { background: var(--bg); color: #dfe3ea; font: 13.5px/1.6 var(--mono); }
.CodeMirror-gutters { background: var(--bg); border-right: 1px solid var(--line); }
.CodeMirror-linenumber { color: #464e5e; padding: 0 12px 0 8px; }
.CodeMirror-activeline-background { background: rgba(255,255,255,.035); }
.CodeMirror-activeline .CodeMirror-linenumber { color: var(--text-2); }
.CodeMirror-cursor { border-left: 2px solid var(--accent); }
.CodeMirror-selected, .CodeMirror-focused .CodeMirror-selected { background: rgba(124,196,255,.18) !important; }
.CodeMirror-matchingbracket { color: var(--accent) !important; text-decoration: underline; }
.CodeMirror-matchingtag { background: rgba(196,242,94,.12); }
.CodeMirror-lines { padding: 10px 0; }
.cm-s-default .cm-keyword { color: #ff8fb1; }
.cm-s-default .cm-def { color: #7cc4ff; }
.cm-s-default .cm-variable { color: #dfe3ea; }
.cm-s-default .cm-variable-2 { color: #9fd3ff; }
.cm-s-default .cm-variable-3, .cm-s-default .cm-type { color: #6ee7d8; }
.cm-s-default .cm-property { color: #b59cff; }
.cm-s-default .cm-operator { color: #ff8fb1; }
.cm-s-default .cm-string, .cm-s-default .cm-string-2 { color: #c4f25e; }
.cm-s-default .cm-number { color: #ffb86b; }
.cm-s-default .cm-atom { color: #ffb86b; }
.cm-s-default .cm-comment { color: #5d6678; font-style: italic; }
.cm-s-default .cm-tag { color: #ff8fb1; }
.cm-s-default .cm-attribute { color: #b59cff; }
.cm-s-default .cm-bracket { color: #8a92a3; }
.cm-s-default .cm-meta { color: #7cc4ff; }
.cm-s-default .cm-builtin { color: #6ee7d8; }
.cm-s-default .cm-qualifier { color: #ffb86b; }
.cm-s-default .cm-header { color: #7cc4ff; }
.cm-s-default .cm-link { color: #7cc4ff; }
.cm-s-default .cm-error { color: var(--danger); }
.CodeMirror-dialog { background: var(--bg-3); color: var(--text); border-color: var(--line) !important; padding: 6px 10px; font-family: var(--sans); }
.CodeMirror-dialog input { width: 18em; display: inline; padding: 3px 6px; color: var(--text); font-family: var(--mono); }
.cm-searching { background: rgba(245,196,81,.25); }

/* ---------- Base de données ---------- */
.db-side, .jobs-side { width: 260px; background: var(--bg-2); border-right: 1px solid var(--line); display: flex; flex-direction: column; flex-shrink: 0; }
.jobs-side { border-right: 0; border-left: 1px solid var(--line); width: 300px; }
.side-head { display: flex; align-items: center; justify-content: space-between; padding: 12px 12px 10px 16px; border-bottom: 1px solid var(--line); font-size: 13px; }
.db-tree { flex: 1; overflow-y: auto; padding: 6px; }
.db-item { display: flex; align-items: center; gap: 8px; padding: 6px 8px; border-radius: 6px; cursor: pointer; font-size: 13px; }
.db-item:hover { background: var(--bg-3); }
.db-item.active { background: var(--accent-soft); color: var(--accent); }
.db-item .n { font: 11px var(--mono); color: var(--muted); margin-left: auto; }
.db-item.sys { opacity: .55; }
.db-item svg.i { color: var(--muted); }
.db-item.active svg.i { color: var(--accent); }
.db-tables { padding-left: 16px; margin: 2px 0 6px; border-left: 1px solid var(--line); margin-left: 15px; }
.db-tables .db-item { padding: 4px 8px; font-size: 12.5px; }
.db-sys-toggle { margin: 8px; font-size: 12px; color: var(--muted); background: none; border: 0; cursor: pointer; text-align: left; padding: 4px 8px; }
.db-main { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.db-head { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 0 16px; border-bottom: 1px solid var(--line); background: var(--bg-2); min-height: 48px; }
.db-title { font: 600 14px var(--mono); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.db-title .sep { color: var(--muted); margin: 0 4px; }
.db-tabs { display: flex; gap: 2px; align-self: stretch; }
.db-tabs button { background: none; border: 0; color: var(--muted); padding: 0 14px; cursor: pointer; font: 500 13px var(--sans); border-bottom: 2px solid transparent; }
.db-tabs button:hover { color: var(--text); }
.db-tabs button.active { color: var(--accent); border-bottom-color: var(--accent); }
.db-tabs button:disabled { opacity: .35; cursor: default; }
.db-body { flex: 1; min-height: 0; position: relative; }
.db-pane { display: none; position: absolute; inset: 0; overflow: auto; padding: 16px; flex-direction: column; gap: 12px; }
.db-pane.active { display: flex; }
.toolbar { display: flex; gap: 6px; align-items: center; flex-wrap: wrap; }
.grid-wrap { overflow: auto; border: 1px solid var(--line); border-radius: 8px; flex-shrink: 0; max-width: 100%; }
#db-pane-data .grid-wrap { flex: 1; flex-shrink: 1; min-height: 120px; }
table.grid { border-collapse: separate; border-spacing: 0; font: 12.5px var(--mono); width: max-content; min-width: 100%; }
table.grid th, table.grid td { padding: 7px 12px; border-bottom: 1px solid var(--line); border-right: 1px solid var(--line); text-align: left; max-width: 360px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
table.grid th { position: sticky; top: 0; background: var(--bg-3); color: var(--text-2); font-weight: 600; z-index: 1; font-family: var(--sans); font-size: 12px; }
table.grid th.sortable { cursor: pointer; }
table.grid th.sortable:hover { color: var(--text); }
table.grid th .pk { color: var(--warn); margin-left: 4px; }
table.grid tr:hover td { background: rgba(255,255,255,.025); }
table.grid td.null { color: var(--muted); font-style: italic; }
table.grid td.num { color: var(--orange); text-align: right; }
table.grid td.acts { padding: 2px 4px; position: sticky; left: 0; background: var(--bg-2); width: 64px; }
table.grid th.acts { left: 0; z-index: 2; }
table.grid tr td:last-child, table.grid tr th:last-child { border-right: 0; }
table.grid tr:last-child td { border-bottom: 0; }
.pager { display: flex; align-items: center; gap: 8px; font-size: 12px; color: var(--muted); }
.sql-toolbar { display: flex; gap: 6px; align-items: center; flex-wrap: wrap; }
.sql-editor { height: 220px; min-height: 140px; border: 1px solid var(--line); border-radius: 8px; overflow: hidden; position: relative; resize: vertical; flex-shrink: 0; }
.sql-editor .CodeMirror, .sql-editor textarea { position: absolute; inset: 0; height: 100%; }
.sql-editor textarea { border: 0; resize: none; font: 13px var(--mono); }
.sql-results { display: flex; flex-direction: column; gap: 12px; }
.result { border: 1px solid var(--line); border-radius: 8px; overflow: hidden; }
.result-head { display: flex; gap: 10px; align-items: center; padding: 7px 12px; background: var(--bg-2); font: 12px var(--mono); color: var(--muted); border-bottom: 1px solid var(--line); }
.result-head .q { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--text-2); }
.result.err .result-head { background: var(--danger-soft); color: var(--danger); }
.result-msg { padding: 10px 12px; font: 12.5px var(--mono); }
.result.err .result-msg { color: var(--danger); white-space: pre-wrap; }
.result .grid-wrap { border: 0; border-radius: 0; max-height: 420px; }
.code-block { background: var(--bg); border: 1px solid var(--line); border-radius: 8px; padding: 14px; font: 12.5px/1.6 var(--mono); white-space: pre; overflow: auto; color: var(--text-2); }
.section-title { font-size: 12px; color: var(--muted); text-transform: uppercase; letter-spacing: .06em; font-weight: 600; margin-top: 6px; }
.placeholder { margin: auto; text-align: center; color: var(--muted); display: flex; flex-direction: column; gap: 10px; align-items: center; }
.placeholder svg.i { width: 34px; height: 34px; color: var(--line-2); }

/* Constructeur de table */
.cols-builder { display: flex; flex-direction: column; gap: 6px; }
.col-row { display: grid; grid-template-columns: 1.4fr 1.1fr .7fr 1fr auto auto auto auto; gap: 6px; align-items: center; }
.col-row.head { font-size: 11px; color: var(--muted); font-weight: 600; text-transform: uppercase; letter-spacing: .04em; }
.col-row input, .col-row select { padding: 6px 8px; font-size: 12.5px; }
.col-row .chk { display: flex; flex-direction: row; align-items: center; justify-content: center; gap: 4px; font-size: 11px; }

/* ---------- Terminal ---------- */
.term-main { flex: 1; min-width: 0; display: flex; flex-direction: column; background: #07080b; }
.term-head { display: flex; align-items: flex-end; gap: 14px; padding: 12px 16px; background: var(--bg-2); border-bottom: 1px solid var(--line); flex-wrap: wrap; }
.term-cwd { min-width: 220px; }
.term-cwd select { font-family: var(--mono); }
.term-quick { display: flex; gap: 4px; flex-wrap: wrap; }
.term-quick .btn { font-family: var(--mono); }
.term-out { flex: 1; overflow-y: auto; padding: 14px 18px; font: 12.5px/1.55 var(--mono); white-space: pre-wrap; word-break: break-word; color: #d5dae3; }
.term-out .cmdline { color: var(--accent); margin-top: 6px; }
.term-out .cmdline .cwd { color: var(--blue); }
.term-out .done-ok { color: var(--ok); }
.term-out .done-err { color: var(--danger); }
.term-out .hl-url { color: var(--blue); text-decoration: underline; cursor: pointer; }
.term-input { display: flex; align-items: center; gap: 10px; padding: 10px 14px; border-top: 1px solid var(--line); background: var(--bg-2); }
.term-input .prompt { font: 600 13px var(--mono); color: var(--accent); white-space: nowrap; }
.term-input input { font-family: var(--mono); background: transparent; border-color: transparent; padding: 6px 4px; }
.term-input input:focus { box-shadow: none; border-color: transparent; }
.jobs-list { flex: 1; overflow-y: auto; padding: 6px; display: flex; flex-direction: column; gap: 4px; }
.job { padding: 8px 10px; border-radius: 7px; cursor: pointer; border: 1px solid transparent; display: flex; gap: 8px; align-items: flex-start; }
.job:hover { background: var(--bg-3); }
.job.active { border-color: var(--line-2); background: var(--bg-3); }
.job .jdot { width: 8px; height: 8px; border-radius: 50%; margin-top: 5px; flex-shrink: 0; background: var(--muted); }
.job.run .jdot { background: var(--accent); box-shadow: 0 0 8px var(--accent); animation: pulse 1.4s infinite; }
.job.ok .jdot { background: var(--ok); }
.job.err .jdot { background: var(--danger); }
.job .jbody { flex: 1; min-width: 0; }
.job .jcmd { font: 12px var(--mono); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.job .jmeta { font-size: 11px; color: var(--muted); }
@keyframes pulse { 50% { opacity: .4; } }

/* ---------- Paramètres ---------- */
.settings-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); gap: 16px; align-items: start; }
.card { background: var(--bg-2); border: 1px solid var(--line); border-radius: 12px; padding: 20px; display: flex; flex-direction: column; gap: 14px; }
.card h2 { font-size: 15px; display: flex; align-items: center; gap: 8px; }
.card h2 svg.i { color: var(--accent); }
.card form, .card > form { display: contents; }
.kv { display: grid; grid-template-columns: 110px 1fr auto; gap: 8px 12px; align-items: center; font-size: 13px; }
.kv dt { color: var(--muted); }
.kv dd { font-family: var(--mono); word-break: break-all; }
.pw-meter { height: 4px; background: var(--bg-4); border-radius: 4px; overflow: hidden; }
.pw-meter div { height: 100%; width: 0; transition: width .2s, background .2s; }

/* ---------- Modale & toasts ---------- */
.modal-back { position: fixed; inset: 0; background: rgba(5,6,9,.7); backdrop-filter: blur(3px); display: grid; place-items: center; z-index: 50; animation: fade .12s; }
.modal { width: min(520px, 94vw); max-height: 90vh; display: flex; flex-direction: column; background: var(--bg-2); border: 1px solid var(--line-2); border-radius: 14px; box-shadow: 0 40px 100px rgba(0,0,0,.6); animation: pop .15s; }
.modal.wide { width: min(880px, 96vw); }
.modal-head { display: flex; align-items: center; justify-content: space-between; padding: 16px 20px; border-bottom: 1px solid var(--line); }
.modal-head h3 { font-size: 15px; }
.modal-body { padding: 18px 20px; overflow-y: auto; display: flex; flex-direction: column; gap: 14px; }
.modal-body p { color: var(--text-2); }
.modal-foot { display: flex; justify-content: flex-end; gap: 8px; padding: 14px 20px; border-top: 1px solid var(--line); }
@keyframes fade { from { opacity: 0; } }
@keyframes pop { from { opacity: 0; transform: translateY(8px) scale(.98); } }
#toasts { position: fixed; bottom: 18px; right: 18px; display: flex; flex-direction: column; gap: 8px; z-index: 60; }
.toast { background: var(--bg-3); border: 1px solid var(--line-2); border-left: 3px solid var(--accent); padding: 10px 14px; border-radius: 8px; font-size: 13px; box-shadow: 0 10px 30px rgba(0,0,0,.4); max-width: 380px; animation: pop .15s; white-space: pre-wrap; }
.toast.err { border-left-color: var(--danger); }

@media (max-width: 900px) {
  .explorer { width: 230px; }
  .preview-pane { position: absolute; inset: 40px 0 0 0; width: auto; z-index: 4; }
  .db-side { width: 200px; }
  .jobs-side { display: none; }
  #view-projects, #view-settings { padding: 20px; }
}
DSEOF_4_ASSETS_APP_CSS
cat > "$DASH/assets/app.js" <<'DSEOF_5_ASSETS_APP_JS'
/* Dev Studio — interface */
(() => {
'use strict';

/* =============== Utilitaires =============== */
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const qi = n => '`' + String(n).replace(/`/g, '``') + '`';
const sqlStr = s => "'" + String(s).replace(/\\/g, '\\\\').replace(/'/g, "''") + "'";
const sleep = ms => new Promise(r => setTimeout(r, ms));
const store = {
  get(k, d) { try { const v = localStorage.getItem('ds.' + k); return v === null ? d : JSON.parse(v); } catch { return d; } },
  set(k, v) { try { localStorage.setItem('ds.' + k, JSON.stringify(v)); } catch {} },
};

const ICONS = {
  grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/>',
  code: '<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>',
  database: '<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14a9 3 0 0 0 18 0V5"/><path d="M3 12a9 3 0 0 0 18 0"/>',
  terminal: '<polyline points="4 17 10 11 4 5"/><line x1="12" x2="20" y1="19" y2="19"/>',
  sliders: '<line x1="4" x2="4" y1="21" y2="14"/><line x1="4" x2="4" y1="10" y2="3"/><line x1="12" x2="12" y1="21" y2="12"/><line x1="12" x2="12" y1="8" y2="3"/><line x1="20" x2="20" y1="21" y2="16"/><line x1="20" x2="20" y1="12" y2="3"/><line x1="2" x2="6" y1="14" y2="14"/><line x1="10" x2="14" y1="8" y2="8"/><line x1="18" x2="22" y1="16" y2="16"/>',
  logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" x2="9" y1="12" y2="12"/>',
  plus: '<path d="M5 12h14"/><path d="M12 5v14"/>',
  folder: '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>',
  file: '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/>',
  filePlus: '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M9 15h6"/><path d="M12 18v-6"/>',
  folderPlus: '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/><line x1="12" x2="12" y1="10" y2="16"/><line x1="9" x2="15" y1="13" y2="13"/>',
  folderUp: '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/><path d="M12 10v6"/><path d="m9 13 3-3 3 3"/>',
  upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" x2="12" y1="3" y2="15"/>',
  download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/>',
  refresh: '<path d="M21 12a9 9 0 1 1-3-6.7L21 8"/><path d="M21 3v5h-5"/>',
  trash: '<path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
  pencil: '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/>',
  eye: '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
  external: '<path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>',
  save: '<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/>',
  play: '<polygon points="6 3 20 12 6 21 6 3"/>',
  stop: '<rect x="5" y="5" width="14" height="14" rx="2"/>',
  x: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
  arrowUp: '<path d="m5 12 7-7 7 7"/><path d="M12 19V5"/>',
  columns: '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M12 3v18"/>',
  table: '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/><path d="M3 15h18"/><path d="M12 3v18"/>',
  lock: '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
  user: '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  server: '<rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><line x1="6" x2="6.01" y1="6" y2="6"/><line x1="6" x2="6.01" y1="18" y2="18"/>',
  archive: '<rect x="2" y="3" width="20" height="5" rx="1"/><path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8"/><path d="M10 12h4"/>',
  copy: '<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>',
  key: '<circle cx="7.5" cy="15.5" r="5.5"/><path d="m21 2-9.6 9.6"/><path d="m15.5 7.5 3 3L22 7l-3-3"/>',
  chevron: '<path d="m9 18 6-6-6-6"/>',
  hammer: '<path d="m15 12-8.5 8.5a2.12 2.12 0 1 1-3-3L12 9"/><path d="M17.64 15 22 10.64"/><path d="m20.91 11.7-1.25-1.25a2.4 2.4 0 0 1-.71-1.7V7.86L16.5 5.42A6 6 0 0 0 12.27 3.7H9l.92.82A6.18 6.18 0 0 1 12 9.1V11l2 2h2.17a2.4 2.4 0 0 1 1.7.71l1.25 1.25"/>',
};
const icon = (n, cls = '') => `<svg class="i ${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[n] || ''}</svg>`;
const hydrateIcons = (root = document) => $$('i[data-icon]', root).forEach(el => { el.outerHTML = icon(el.dataset.icon); });

function fmtSize(b) {
  if (b == null) return '';
  if (b < 1024) return b + ' o';
  const u = ['Ko', 'Mo', 'Go', 'To']; let i = -1;
  do { b /= 1024; i++; } while (b >= 1024 && i < u.length - 1);
  return (b < 10 ? b.toFixed(1) : Math.round(b)) + ' ' + u[i];
}
function fmtAgo(ts) {
  const s = Math.floor(Date.now() / 1000 - ts);
  if (s < 60) return "à l'instant";
  if (s < 3600) return `il y a ${Math.floor(s / 60)} min`;
  if (s < 86400) return `il y a ${Math.floor(s / 3600)} h`;
  if (s < 86400 * 30) return `il y a ${Math.floor(s / 86400)} j`;
  return new Date(ts * 1000).toLocaleDateString('fr-FR');
}
const urlFor = p => '/' + String(p).split('/').filter(Boolean).map(encodeURIComponent).join('/') + (p && !/\.[^/]+$/.test(p) ? '/' : '');
const extOf = p => { const m = /\.([^./]+)$/.exec(p); return m ? m[1].toLowerCase() : ''; };
const baseName = p => String(p).split('/').pop();
const dirName = p => String(p).split('/').slice(0, -1).join('/');
const IMG_EXT = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'ico', 'avif', 'bmp'];

async function copyText(t) {
  try { await navigator.clipboard.writeText(t); }
  catch {
    const ta = document.createElement('textarea'); ta.value = t; ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.append(ta); ta.select(); document.execCommand('copy'); ta.remove();
  }
  toast('Copié');
}

/* =============== API =============== */
async function api(action, { params = {}, body, form } = {}) {
  const qs = new URLSearchParams({ action, ...params });
  const opt = { method: body || form ? 'POST' : 'GET', headers: { 'X-CSRF-Token': DS.csrf }, credentials: 'same-origin' };
  if (form) opt.body = form;
  else if (body) { opt.headers['Content-Type'] = 'application/json'; opt.body = JSON.stringify(body); }
  let res;
  try { res = await fetch('api.php?' + qs, opt); } catch { throw new Error('Serveur injoignable'); }
  if (res.status === 413) throw new Error('Fichier trop gros pour le serveur');
  let data;
  try { data = await res.json(); } catch { throw new Error(`Réponse invalide du serveur (HTTP ${res.status})`); }
  if (res.status === 401) { setTimeout(() => location.reload(), 800); throw new Error(data.error || 'Session expirée'); }
  if (!res.ok || data.error) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}
const apiUrl = (action, params = {}) => 'api.php?' + new URLSearchParams({ action, ...params });

/* =============== Toasts & modales =============== */
function toast(msg, err = false) {
  const t = document.createElement('div');
  t.className = 'toast' + (err ? ' err' : '');
  t.textContent = msg;
  $('#toasts').append(t);
  setTimeout(() => { t.style.opacity = '0'; t.style.transition = 'opacity .3s'; }, err ? 5000 : 2400);
  setTimeout(() => t.remove(), err ? 5400 : 2800);
}
const fail = e => toast(e.message || String(e), true);

function modal({ title, body = '', actions = [], wide = false, onOpen }) {
  return new Promise(resolve => {
    const back = document.createElement('div');
    back.className = 'modal-back';
    back.innerHTML = `<div class="modal ${wide ? 'wide' : ''}" role="dialog"><div class="modal-head"><h3>${esc(title)}</h3><button class="icon-btn" data-x>${icon('x')}</button></div><div class="modal-body"></div><div class="modal-foot"></div></div>`;
    const bodyEl = $('.modal-body', back);
    if (typeof body === 'string') bodyEl.innerHTML = body; else bodyEl.append(body);
    hydrateIcons(bodyEl);
    const foot = $('.modal-foot', back);
    let done = false;
    const close = v => { if (done) return; done = true; back.remove(); document.removeEventListener('keydown', onKey, true); resolve(v); };
    actions.forEach(a => {
      const b = document.createElement('button');
      b.className = 'btn ' + (a.cls || '');
      b.innerHTML = a.label;
      b.onclick = async () => {
        if (!a.handler) return close(a.value);
        b.disabled = true;
        try {
          const r = await a.handler(bodyEl);
          if (r === false) { b.disabled = false; return; }
          close(r === undefined ? a.value : r);
        } catch (e) { fail(e); b.disabled = false; }
      };
      foot.append(b);
    });
    if (!actions.length) foot.remove();
    const onKey = e => {
      if (e.key === 'Escape') { e.stopPropagation(); close(null); }
      else if (e.key === 'Enter' && e.target.tagName === 'INPUT' && back.contains(e.target)) {
        const p = foot.querySelector('.btn-primary, .btn-danger');
        if (p) { e.preventDefault(); p.click(); }
      }
    };
    document.addEventListener('keydown', onKey, true);
    $('[data-x]', back).onclick = () => close(null);
    back.addEventListener('mousedown', e => { if (e.target === back) close(null); });
    $('#modal-root').append(back);
    setTimeout(() => {
      const f = bodyEl.querySelector('input:not([type=checkbox]),select,textarea');
      if (f) f.focus();
      onOpen?.(bodyEl);
    }, 30);
  });
}
const askText = (title, label, value = '', okLabel = 'Valider', selectBase = false) => modal({
  title,
  body: `<label>${esc(label)}<input data-v value="${esc(value)}" spellcheck="false"></label>`,
  actions: [{ label: 'Annuler', value: null }, { label: okLabel, cls: 'btn-primary', handler: b => b.querySelector('[data-v]').value.trim() || false }],
  onOpen: b => {
    const i = b.querySelector('[data-v]');
    const dot = value.lastIndexOf('.');
    if (selectBase && dot > 0) i.setSelectionRange(0, dot); else i.select();
  },
});
const confirmBox = (title, html, okLabel = 'Supprimer', danger = true) => modal({
  title, body: `<p>${html}</p>`,
  actions: [{ label: 'Annuler', value: false }, { label: okLabel, cls: danger ? 'btn-danger' : 'btn-primary', value: true }],
});

/* =============== État & navigation =============== */
const state = {
  view: 'projects',
  projects: [],
  info: null,
  dir: store.get('dir', ''),
  items: [],
  tabs: [],
  active: null,
  previewOpen: false,
  db: { name: null, table: null, tab: 'tables', page: 1, per: 50, order: '', dir: 'ASC', dbs: [], tables: [], showSys: false, browse: null },
  term: { cwd: store.get('cwd', ''), job: null, offset: 0, timer: null, history: store.get('history', []), hIdx: -1 },
  jobs: [],
};

function show(view) {
  if (!$('#view-' + view)) view = 'projects';
  state.view = view;
  $$('.rail-btn[data-view]').forEach(b => b.classList.toggle('active', b.dataset.view === view));
  $$('.view').forEach(v => v.classList.toggle('active', v.id === 'view-' + view));
  if (location.hash !== '#' + view) history.replaceState(null, '', '#' + view);
  if (view === 'projects') loadProjects();
  if (view === 'editor') { loadDir(state.dir); setTimeout(() => editor.refresh(), 0); }
  if (view === 'db') { if (!state.info) loadInfo(); if (!state.db.dbs.length) loadDbs(); }
  if (view === 'terminal') { fillCwd(); loadJobs(); setTimeout(() => $('#term-cmd').focus(), 0); }
  if (view === 'settings') loadSettings();
}

/* =============== Projets =============== */
const TYPE = {
  react: { label: 'React', mark: 'JSX' },
  php: { label: 'PHP', mark: 'PHP' },
  html: { label: 'HTML', mark: '</>' },
  node: { label: 'Node', mark: 'JS' },
  folder: { label: 'Dossier', mark: '···' },
};

async function loadInfo() {
  try { state.info = await api('info'); } catch (e) { state.info = null; }
  renderStats();
  return state.info;
}

function renderStats() {
  const i = state.info;
  const el = $('#stats');
  if (!i) { el.innerHTML = ''; return; }
  const diskUsed = i.disk_total ? 1 - i.disk_free / i.disk_total : 0;
  const memUsed = i.mem?.MemTotal ? 1 - i.mem.MemAvailable / i.mem.MemTotal : 0;
  const s = (label, value, extra = '') => `<div class="stat"><div class="stat-label">${label}</div><div class="stat-value">${value}</div>${extra}</div>`;
  el.innerHTML =
    s('PHP', `<span class="led"></span>${esc(i.php)}`) +
    s('Node.js', `<span class="led ${i.node ? '' : 'off'}"></span>${esc(i.node || 'absent')}`) +
    s('MariaDB', `<span class="led ${i.mysql ? '' : 'off'}"></span>${esc(i.mysql ? i.mysql.split('-')[0] : 'arrêté')}`) +
    s('Disque', `${fmtSize(i.disk_total - i.disk_free)} / ${fmtSize(i.disk_total)}`, `<div class="meter"><div style="width:${(diskUsed * 100).toFixed(0)}%"></div></div>`) +
    s('Mémoire', `${fmtSize(i.mem.MemTotal - i.mem.MemAvailable)} / ${fmtSize(i.mem.MemTotal)}`, `<div class="meter"><div style="width:${(memUsed * 100).toFixed(0)}%"></div></div>`);
}

async function loadProjects() {
  $('#host-hint').textContent = `http://${location.host}/nom-du-projet/`;
  if (!state.info) loadInfo();
  try {
    const d = await api('projects');
    state.projects = d.projects;
  } catch (e) { fail(e); }
  renderProjects();
}

function renderProjects() {
  const g = $('#project-grid');
  if (!state.projects.length) {
    g.innerHTML = `<div class="empty-state">Aucun projet pour l'instant.<br><br><button class="btn btn-primary" data-act="new">${icon('plus')}Créer mon premier projet</button></div>`;
    return;
  }
  g.innerHTML = state.projects.map(p => {
    const t = TYPE[p.type] || TYPE.folder;
    let badges = `<span class="badge">${t.label}</span>`;
    if (p.type === 'react') {
      badges += p.node_modules ? '' : ' <span class="badge warn">npm install requis</span>';
      badges += p.dist ? ' <span class="badge ok">build ok</span>' : ' <span class="badge warn">pas de build</span>';
    }
    return `<div class="project t-${p.type}" data-name="${esc(p.name)}">
      <div class="project-top">
        <div class="project-icon">${esc(t.mark)}</div>
        <div><div class="project-name">${esc(p.name)}</div><div class="project-meta">modifié ${fmtAgo(p.mtime)}</div></div>
      </div>
      <div>${badges}</div>
      <div class="project-actions">
        <button class="btn btn-sm" data-act="open">${icon('code')}Ouvrir</button>
        <button class="btn btn-sm" data-act="preview">${icon('eye')}Aperçu</button>
        ${p.type === 'react' || p.type === 'node' ? `<button class="btn btn-sm" data-act="build">${icon('hammer')}Build</button>` : ''}
        <button class="btn btn-sm btn-ghost" data-act="term" title="Terminal">${icon('terminal')}</button>
        <span class="grow"></span>
        <button class="icon-btn danger" data-act="delete" title="Supprimer">${icon('trash')}</button>
      </div>
    </div>`;
  }).join('');
}

$('#project-grid').addEventListener('click', async e => {
  const b = e.target.closest('[data-act]');
  if (!b) return;
  if (b.dataset.act === 'new') return newProject();
  const name = b.closest('[data-name]')?.dataset.name;
  const p = state.projects.find(x => x.name === name);
  if (!p) return;
  switch (b.dataset.act) {
    case 'open':
      state.dir = p.name;
      show('editor');
      if (p.main) openFile(p.main);
      break;
    case 'preview':
      previewProject(p);
      break;
    case 'build':
      runInTerminal(p.name, p.node_modules ? 'npm run build' : 'npm install && npm run build');
      break;
    case 'term':
      state.term.cwd = p.name; store.set('cwd', p.name);
      show('terminal');
      break;
    case 'delete': {
      const ok = await confirmBox('Supprimer le projet', `Supprimer définitivement <b>${esc(p.name)}</b> et tous ses fichiers ?<br><span class="muted small">Les bases de données ne sont pas supprimées.</span>`);
      if (!ok) return;
      try {
        await api('delete', { body: { paths: [p.name] } });
        state.tabs.filter(t => t.path.startsWith(p.name + '/')).forEach(t => closeTab(t, true));
        if (state.dir === p.name || state.dir.startsWith(p.name + '/')) state.dir = '';
        toast('Projet supprimé'); loadProjects();
      } catch (e) { fail(e); }
    }
  }
});

async function previewProject(p) {
  if (p.type === 'react' || p.type === 'node') {
    if (p.dist) return window.open(urlFor(p.name + '/dist'), '_blank');
    const go = await confirmBox('Pas encore de build', `Le projet <b>${esc(p.name)}</b> n'a pas de dossier <code>dist/</code>. Lancer <code>npm run build</code> maintenant ?<br><span class="muted small">Astuce : <code>npm run dev</code> dans le Terminal lance un serveur avec rechargement automatique sur le port 5173.</span>`, 'Lancer le build', false);
    if (go) runInTerminal(p.name, p.node_modules ? 'npm run build' : 'npm install && npm run build');
    return;
  }
  window.open(urlFor(p.name), '_blank');
}

function newProject() {
  const tpls = [
    ['html', 'HTML / CSS / JS', 'Site statique : index.html, style.css, script.js'],
    ['php', 'PHP + MySQL', 'Crée aussi une base de données reliée + exemple CRUD'],
    ['react', 'React (Vite)', 'npm install + build automatiques (≈ 1 min)'],
    ['empty', 'Dossier vide', 'Pour importer ton propre code'],
  ];
  let sel = 'html';
  const body = document.createElement('div');
  body.style.cssText = 'display:flex;flex-direction:column;gap:14px';
  body.innerHTML = `<label>Nom du projet<input data-name placeholder="mon-site" spellcheck="false" pattern="[A-Za-z0-9][A-Za-z0-9_\\-]*"></label>
    <div class="tpl-grid">${tpls.map(([k, t, d]) => `<button type="button" class="tpl ${k === sel ? 'sel' : ''}" data-tpl="${k}"><b>${t}</b><span>${d}</span></button>`).join('')}</div>`;
  body.addEventListener('click', e => {
    const t = e.target.closest('[data-tpl]'); if (!t) return;
    sel = t.dataset.tpl; $$('.tpl', body).forEach(x => x.classList.toggle('sel', x === t));
  });
  modal({
    title: 'Nouveau projet', body,
    actions: [{ label: 'Annuler' }, {
      label: 'Créer le projet', cls: 'btn-primary', handler: async b => {
        const name = $('[data-name]', b).value.trim();
        if (!name) { toast('Donne un nom au projet', true); return false; }
        const r = await api('project_create', { body: { name, template: sel } });
        toast(`Projet « ${name} » créé` + (r.db ? ` (base « ${r.db} »)` : ''));
        state.projects = [];
        if (r.job) {
          state.term.cwd = name; store.set('cwd', name);
          show('terminal');
          attachJob(r.job);
        } else {
          state.dir = name;
          show('editor');
          if (r.open) openFile(r.open);
        }
        if (r.db) state.db.dbs = [];
        return true;
      },
    }],
  });
}
$('#btn-new-project').onclick = newProject;

/* =============== Explorateur =============== */
const FILE_COLORS = {
  js: ['JS', '#f5c451'], mjs: ['JS', '#f5c451'], jsx: ['JSX', '#7cc4ff'], ts: ['TS', '#7cc4ff'], tsx: ['TSX', '#7cc4ff'],
  php: ['PHP', '#b59cff'], html: ['<>', '#ffb86b'], htm: ['<>', '#ffb86b'], css: ['#', '#7cc4ff'], scss: ['#', '#ff8fb1'],
  json: ['{}', '#f5c451'], sql: ['SQL', '#6ee7d8'], md: ['MD', '#b9bfcc'], txt: ['TXT', '#7d8596'], svg: ['SVG', '#ffb86b'],
  png: ['IMG', '#4ade80'], jpg: ['IMG', '#4ade80'], jpeg: ['IMG', '#4ade80'], gif: ['IMG', '#4ade80'], webp: ['IMG', '#4ade80'], ico: ['IMG', '#4ade80'],
  zip: ['ZIP', '#ff6b6b'], env: ['ENV', '#c4f25e'], sh: ['SH', '#c4f25e'], xml: ['XML', '#ffb86b'], yml: ['YML', '#ff8fb1'], yaml: ['YML', '#ff8fb1'],
};
function fileIcon(item) {
  if (item.dir) return `<span class="ficon dir">${icon('folder')}</span>`;
  const c = FILE_COLORS[extOf(item.name)];
  return c ? `<span class="ficon" style="color:${c[1]}">${esc(c[0])}</span>` : `<span class="ficon" style="color:var(--muted)">${icon('file')}</span>`;
}

async function loadDir(path = state.dir) {
  try {
    const d = await api('list', { params: { path } });
    state.dir = d.path; state.items = d.items;
    store.set('dir', state.dir);
  } catch (e) { fail(e); state.dir = ''; state.items = []; }
  renderExplorer();
}

function renderExplorer() {
  const parts = state.dir ? state.dir.split('/') : [];
  let acc = '';
  $('#crumbs').innerHTML = `<button data-crumb="">www</button>` + parts.map(p => {
    acc = acc ? acc + '/' + p : p;
    return `<span class="sep">/</span><button data-crumb="${esc(acc)}">${esc(p)}</button>`;
  }).join('');
  const activePath = state.active?.path;
  $('#file-list').innerHTML = state.items.length ? state.items.map((it, i) => `
    <div class="frow ${it.path === activePath ? 'active' : ''}" data-i="${i}">
      ${fileIcon(it)}
      <span class="fname" title="${esc(it.name)}">${esc(it.name)}</span>
      <span class="fsize">${it.dir ? '' : fmtSize(it.size)}</span>
      <span class="facts">
        ${!it.dir ? `<button class="icon-btn" data-a="view" title="Voir dans le navigateur">${icon('eye')}</button>` : ''}
        ${extOf(it.name) === 'zip' ? `<button class="icon-btn" data-a="extract" title="Extraire">${icon('archive')}</button>` : ''}
        <button class="icon-btn" data-a="rename" title="Renommer">${icon('pencil')}</button>
        <button class="icon-btn" data-a="download" title="Télécharger${it.dir ? ' (zip)' : ''}">${icon('download')}</button>
        <button class="icon-btn danger" data-a="delete" title="Supprimer">${icon('trash')}</button>
      </span>
      <button class="open-btn" data-a="open">Ouvrir</button>
    </div>`).join('') : `<div class="placeholder" style="padding:30px 10px">${icon('folder')}<span>Dossier vide</span></div>`;
}

$('#crumbs').addEventListener('click', e => { const b = e.target.closest('[data-crumb]'); if (b) loadDir(b.dataset.crumb); });
$('#ex-up').onclick = () => loadDir(dirName(state.dir));
$('#ex-refresh').onclick = () => loadDir();
$('#ex-upload').onclick = () => $('#file-input').click();
$('#ex-upload-dir').onclick = () => $('#dir-input').click();
$('#file-input').onchange = e => { uploadFiles([...e.target.files].map(f => ({ file: f, rel: f.name })), state.dir); e.target.value = ''; };
$('#dir-input').onchange = e => {
  const list = [...e.target.files].filter(f => !/(^|\/)(node_modules|\.git)\//.test(f.webkitRelativePath)).map(f => ({ file: f, rel: f.webkitRelativePath || f.name }));
  uploadFiles(list, state.dir); e.target.value = '';
};
$('#ex-newfile').onclick = async () => {
  const n = await askText('Nouveau fichier', `Nom du fichier dans /${state.dir}`, '', 'Créer');
  if (!n) return;
  const path = (state.dir ? state.dir + '/' : '') + n;
  try {
    if (n.includes('/')) await api('mkdir', { body: { path: dirName(path) } }).catch(() => {});
    await api('create_file', { body: { path } });
    await loadDir(); openFile(path);
  } catch (e) { fail(e); }
};
$('#ex-newfolder').onclick = async () => {
  const n = await askText('Nouveau dossier', `Nom du dossier dans /${state.dir}`, '', 'Créer');
  if (!n) return;
  try { await api('mkdir', { body: { path: (state.dir ? state.dir + '/' : '') + n } }); loadDir(); } catch (e) { fail(e); }
};

$('#file-list').addEventListener('click', async e => {
  const row = e.target.closest('.frow'); if (!row) return;
  const it = state.items[+row.dataset.i]; if (!it) return;
  const a = e.target.closest('[data-a]')?.dataset.a || 'open';
  switch (a) {
    case 'open': return it.dir ? loadDir(it.path) : openFile(it.path);
    case 'view': return window.open(urlFor(it.path), '_blank');
    case 'download': return void (location.href = apiUrl('download', { path: it.path }));
    case 'extract':
      try { const r = await api('extract', { body: { path: it.path } }); toast('Extrait dans ' + baseName(r.path)); loadDir(); } catch (err) { fail(err); }
      return;
    case 'rename': {
      const n = await askText('Renommer', 'Nouveau nom', it.name, 'Renommer', !it.dir);
      if (!n || n === it.name) return;
      const to = (dirName(it.path) ? dirName(it.path) + '/' : '') + n;
      try {
        await api('rename', { body: { from: it.path, to } });
        state.tabs.forEach(t => {
          if (t.path === it.path) t.path = to;
          else if (t.path.startsWith(it.path + '/')) t.path = to + t.path.slice(it.path.length);
          t.name = baseName(t.path);
        });
        renderTabs(); loadDir();
      } catch (err) { fail(err); }
      return;
    }
    case 'delete': {
      const ok = await confirmBox('Supprimer', `Supprimer <b>${esc(it.name)}</b>${it.dir ? ' et tout son contenu' : ''} ?`);
      if (!ok) return;
      try {
        await api('delete', { body: { paths: [it.path] } });
        state.tabs.filter(t => t.path === it.path || t.path.startsWith(it.path + '/')).forEach(t => closeTab(t, true));
        loadDir();
      } catch (err) { fail(err); }
    }
  }
});

/* ----- Glisser-déposer depuis le PC ----- */
const explorer = $('#explorer');
let dragDepth = 0, dropRow = null;
const hasFiles = e => [...(e.dataTransfer?.types || [])].includes('Files');
const dropTargetFor = e => {
  const row = e.target.closest?.('.frow');
  const it = row && state.items[+row.dataset.i];
  return it && it.dir ? { path: it.path, row } : { path: state.dir, row: null };
};
const clearDropRow = () => { dropRow?.classList.remove('drop-in'); dropRow = null; };
explorer.addEventListener('dragenter', e => { if (!hasFiles(e)) return; e.preventDefault(); dragDepth++; explorer.classList.add('dragging'); });
explorer.addEventListener('dragleave', e => { if (!hasFiles(e)) return; if (--dragDepth <= 0) { dragDepth = 0; explorer.classList.remove('dragging'); clearDropRow(); } });
explorer.addEventListener('dragover', e => {
  if (!hasFiles(e)) return;
  e.preventDefault(); e.dataTransfer.dropEffect = 'copy';
  const t = dropTargetFor(e);
  if (t.row !== dropRow) { clearDropRow(); dropRow = t.row; dropRow?.classList.add('drop-in'); }
  $('#drop-target').textContent = '/var/www/' + t.path;
});
explorer.addEventListener('drop', async e => {
  if (!hasFiles(e)) return;
  e.preventDefault();
  const target = dropTargetFor(e).path;
  dragDepth = 0; explorer.classList.remove('dragging'); clearDropRow();
  const list = await collectDropped(e.dataTransfer);
  uploadFiles(list, target);
});
// Empêche le navigateur d'ouvrir un fichier lâché à côté
window.addEventListener('dragover', e => { if (hasFiles(e)) e.preventDefault(); });
window.addEventListener('drop', e => { if (hasFiles(e) && !explorer.contains(e.target)) { e.preventDefault(); toast("Dépose les fichiers dans l'explorateur (onglet Éditeur)", true); } });

async function collectDropped(dt) {
  const out = [];
  const entries = [...(dt.items || [])].filter(i => i.kind === 'file').map(i => i.webkitGetAsEntry?.()).filter(Boolean);
  if (!entries.length) { for (const f of dt.files) out.push({ file: f, rel: f.name }); return out; }
  const readAll = reader => new Promise((res, rej) => {
    const all = [];
    const next = () => reader.readEntries(b => { if (!b.length) return res(all); all.push(...b); next(); }, rej);
    next();
  });
  async function walk(entry, prefix) {
    if (entry.isFile) {
      const f = await new Promise((res, rej) => entry.file(res, rej));
      out.push({ file: f, rel: prefix + f.name });
    } else if (entry.isDirectory) {
      const kids = await readAll(entry.createReader());
      if (!kids.length) out.push({ dir: true, rel: prefix + entry.name });
      for (const k of kids) {
        if (k.isDirectory && (k.name === 'node_modules' || k.name === '.git')) continue;
        await walk(k, prefix + entry.name + '/');
      }
    }
  }
  for (const en of entries) await walk(en, '');
  return out;
}

async function uploadFiles(list, dir) {
  if (!list.length) return;
  const bar = $('#upload-bar'), fill = $('#upload-fill'), text = $('#upload-text');
  const files = list.filter(x => x.file), dirs = list.filter(x => x.dir);
  let done = 0, errors = 0, idx = 0;
  const total = files.length;
  bar.classList.remove('hidden');
  const upd = () => { fill.style.width = (total ? done / total * 100 : 100) + '%'; text.textContent = `Envoi ${done} / ${total}`; };
  upd();
  for (const d of dirs) await api('mkdir', { body: { path: (dir ? dir + '/' : '') + d.rel } }).catch(() => {});
  const worker = async () => {
    while (idx < files.length) {
      const it = files[idx++];
      const fd = new FormData();
      fd.append('file', it.file);
      fd.append('dir', dir);
      fd.append('relpath', it.rel);
      try { await api('upload', { form: fd }); }
      catch (e) { errors++; toast(`${it.rel} : ${e.message}`, true); }
      done++; upd();
    }
  };
  await Promise.all([worker(), worker(), worker()]);
  setTimeout(() => bar.classList.add('hidden'), 900);
  toast(errors ? `${total - errors} fichier(s) envoyé(s), ${errors} erreur(s)` : `${total} fichier(s) envoyé(s) dans /${dir}`, !!errors);
  if (state.view === 'editor') loadDir();
  state.projects = [];
}

/* =============== Éditeur =============== */
const MODES = {
  html: 'htmlmixed', htm: 'htmlmixed', vue: 'htmlmixed',
  js: 'javascript', mjs: 'javascript', cjs: 'javascript',
  jsx: 'jsx', tsx: { name: 'jsx', base: { name: 'javascript', typescript: true } },
  ts: { name: 'javascript', typescript: true }, json: { name: 'javascript', json: true },
  css: 'css', scss: 'text/x-scss', less: 'text/x-less',
  php: 'application/x-httpd-php', sql: 'text/x-mariadb', md: 'markdown',
  xml: 'xml', svg: 'xml', sh: 'shell', bash: 'shell', env: 'shell', yml: 'yaml', yaml: 'yaml',
};
const modeFor = p => MODES[extOf(p)] || (baseName(p).startsWith('.env') ? 'shell' : null);

const editor = (() => {
  const host = $('#editor-host');
  const hasCM = typeof window.CodeMirror === 'function';
  let cm = null, ta = null, current = null;
  const binView = document.createElement('div');
  binView.className = 'binary-view hidden';
  host.append(binView);

  if (hasCM) {
    cm = CodeMirror(host, {
      lineNumbers: true, tabSize: 2, indentUnit: 2, indentWithTabs: false,
      autoCloseBrackets: true, autoCloseTags: true, matchBrackets: true,
      matchTags: { bothTags: true }, styleActiveLine: true, lineWrapping: false,
      extraKeys: {
        'Ctrl-S': () => saveActive(), 'Cmd-S': () => saveActive(),
        'Ctrl-/': 'toggleComment', 'Cmd-/': 'toggleComment',
        Tab: c => c.somethingSelected() ? c.indentSelection('add') : c.replaceSelection(' '.repeat(c.getOption('indentUnit')), 'end'),
        'Shift-Tab': 'indentLess',
      },
    });
    cm.getWrapperElement().style.display = 'none';
    cm.on('changes', () => { if (current) markDirty(current); });
    cm.on('cursorActivity', () => { const c = cm.getCursor(); $('#st-pos').textContent = `Ln ${c.line + 1}, Col ${c.ch + 1}`; });
  } else {
    ta = document.createElement('textarea');
    ta.className = 'fallback hidden'; ta.spellcheck = false;
    host.append(ta);
    ta.addEventListener('input', () => { if (current) { current.doc.text = ta.value; markDirty(current); } });
    ta.addEventListener('keydown', e => {
      if (e.key === 'Tab') { e.preventDefault(); const s = ta.selectionStart; ta.setRangeText('  ', s, ta.selectionEnd, 'end'); ta.dispatchEvent(new Event('input')); }
    });
    setTimeout(() => toast("CodeMirror (CDN) indisponible : éditeur simple activé.", true), 500);
  }

  return {
    makeDoc(content, path) {
      if (hasCM) { const d = CodeMirror.Doc(content, modeFor(path)); return { d, gen: d.changeGeneration(true) }; }
      return { text: content, saved: content };
    },
    isDirty(doc) { return hasCM ? !doc.d.isClean(doc.gen) : doc.text !== doc.saved; },
    value(doc) { return hasCM ? doc.d.getValue() : doc.text; },
    snapshot(doc) { return hasCM ? doc.d.changeGeneration(true) : doc.text; },
    markSaved(doc, snap) { if (hasCM) doc.gen = snap; else doc.saved = snap; },
    show(tab) {
      current = tab;
      $('#empty-editor').classList.toggle('hidden', !!tab);
      const editable = tab && !tab.binary;
      if (hasCM) cm.getWrapperElement().style.display = editable ? '' : 'none'; else ta.classList.toggle('hidden', !editable);
      binView.classList.toggle('hidden', !tab || !tab.binary);
      if (!tab) return;
      if (tab.binary) {
        const url = urlFor(tab.path);
        binView.innerHTML = tab.image
          ? `<img src="${esc(url)}?t=${Date.now()}" alt=""><div class="muted small">${esc(tab.path)}</div>`
          : `<div class="placeholder">${icon('file')}<span>Fichier binaire — pas éditable ici.</span></div>`;
        binView.insertAdjacentHTML('beforeend', `<a class="btn btn-sm" href="${esc(apiUrl('download', { path: tab.path }))}">${icon('download')}Télécharger</a>`);
        return;
      }
      if (hasCM) { cm.swapDoc(tab.doc.d); cm.refresh(); cm.focus(); }
      else { ta.value = tab.doc.text; ta.focus(); }
    },
    refresh() { cm?.refresh(); },
    hasCM,
  };
})();

function markDirty(tab) {
  const dirty = editor.isDirty(tab.doc);
  if (dirty !== tab.dirty) { tab.dirty = dirty; renderTabs(); }
}

async function openFile(path) {
  let tab = state.tabs.find(t => t.path === path);
  if (!tab) {
    const ext = extOf(path);
    if (IMG_EXT.includes(ext)) {
      tab = { path, name: baseName(path), binary: true, image: true };
    } else {
      try {
        const d = await api('read', { params: { path } });
        tab = d.binary
          ? { path, name: baseName(path), binary: true }
          : { path, name: baseName(path), doc: editor.makeDoc(d.content, path), dirty: false };
      } catch (e) { return fail(e); }
    }
    state.tabs.push(tab);
  }
  if (state.view !== 'editor') show('editor');
  activate(tab);
}

function activate(tab) {
  state.active = tab || null;
  editor.show(state.active);
  renderTabs();
  $$('#file-list .frow').forEach(r => r.classList.toggle('active', state.items[+r.dataset.i]?.path === tab?.path));
  $('#st-file').textContent = tab ? '/var/www/' + tab.path : '—';
  $('#st-mode').textContent = tab ? (extOf(tab.path) || 'texte').toUpperCase() : '';
  if (!tab) $('#st-pos').textContent = '';
  if (state.previewOpen) setPreview(previewUrlFor(tab?.path));
}

function renderTabs() {
  $('#tabs').innerHTML = state.tabs.map((t, i) => `
    <div class="tab ${t === state.active ? 'active' : ''} ${t.dirty ? 'dirty' : ''}" data-t="${i}" title="${esc(t.path)}">
      <span class="tname">${esc(t.name)}</span><span class="tclose" data-close>${icon('x')}</span>
    </div>`).join('');
}
$('#tabs').addEventListener('click', e => {
  const el = e.target.closest('.tab'); if (!el) return;
  const t = state.tabs[+el.dataset.t];
  if (e.target.closest('[data-close]')) closeTab(t); else activate(t);
});
$('#tabs').addEventListener('auxclick', e => { if (e.button === 1) { const el = e.target.closest('.tab'); if (el) closeTab(state.tabs[+el.dataset.t]); } });

async function closeTab(tab, force = false) {
  if (!tab) return;
  if (!force && tab.dirty && !(await confirmBox('Modifications non enregistrées', `Fermer <b>${esc(tab.name)}</b> sans enregistrer ?`, 'Fermer sans enregistrer'))) return;
  const i = state.tabs.indexOf(tab);
  state.tabs.splice(i, 1);
  if (state.active === tab) activate(state.tabs[i] || state.tabs[i - 1] || null); else renderTabs();
}

async function saveActive() {
  const tab = state.active;
  if (!tab || tab.binary) return;
  const snap = editor.snapshot(tab.doc);
  const content = editor.value(tab.doc);
  try {
    await api('save', { body: { path: tab.path, content } });
    editor.markSaved(tab.doc, editor.hasCM ? snap : content);
    markDirty(tab);
    toast('Enregistré · ' + tab.name);
    if (state.previewOpen) $('#pv-frame').src = $('#pv-frame').src;
  } catch (e) { fail(e); }
}
$('#ed-save').onclick = saveActive;

document.addEventListener('keydown', e => {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
    e.preventDefault();
    if (state.view === 'editor') saveActive();
  }
});
window.addEventListener('beforeunload', e => { if (state.tabs.some(t => t.dirty)) { e.preventDefault(); e.returnValue = ''; } });

/* ----- Aperçu ----- */
function previewUrlFor(path) {
  if (!path) return urlFor(state.dir);
  const top = path.split('/')[0];
  const proj = state.projects.find(p => p.name === top);
  if (proj && (proj.type === 'react' || proj.type === 'node')) return urlFor(top + (proj.dist ? '/dist' : ''));
  if (['html', 'htm', 'php'].includes(extOf(path))) return urlFor(path);
  if (IMG_EXT.includes(extOf(path)) || extOf(path) === 'svg') return urlFor(path);
  return urlFor(dirName(path));
}
function setPreview(url) { $('#pv-url').value = url; $('#pv-frame').src = url; }
$('#ed-preview').onclick = async () => {
  state.previewOpen = !state.previewOpen;
  $('#preview-pane').classList.toggle('hidden', !state.previewOpen);
  if (state.previewOpen) {
    if (!state.projects.length) await api('projects').then(d => { state.projects = d.projects; }).catch(() => {});
    setPreview(previewUrlFor(state.active?.path));
  } else $('#pv-frame').src = 'about:blank';
  editor.refresh();
};
$('#ed-open').onclick = async () => {
  if (!state.projects.length) await api('projects').then(d => { state.projects = d.projects; }).catch(() => {});
  window.open(previewUrlFor(state.active?.path), '_blank');
};
$('#pv-reload').onclick = () => { $('#pv-frame').src = $('#pv-url').value; };
$('#pv-ext').onclick = () => window.open($('#pv-url').value, '_blank');
$('#pv-close').onclick = () => $('#ed-preview').click();
$('#pv-url').addEventListener('keydown', e => { if (e.key === 'Enter') $('#pv-frame').src = e.target.value; });

/* =============== Base de données =============== */
const DB = state.db;
let sqlEd = null;

function initSqlEditor() {
  const host = $('#sql-editor');
  const run = () => runSql();
  if (window.CodeMirror) {
    sqlEd = CodeMirror(host, {
      mode: 'text/x-mariadb', lineNumbers: true, matchBrackets: true, autoCloseBrackets: true, indentUnit: 2,
      extraKeys: { 'Ctrl-Enter': run, 'Cmd-Enter': run, 'Ctrl-/': 'toggleComment' },
      value: store.get('sql', 'SELECT 1;'),
    });
    sqlEd.on('changes', () => store.set('sql', sqlEd.getValue()));
    new ResizeObserver(() => sqlEd.refresh()).observe(host);
  } else {
    const ta = document.createElement('textarea');
    ta.value = store.get('sql', 'SELECT 1;'); ta.spellcheck = false;
    ta.addEventListener('keydown', e => { if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); run(); } });
    ta.addEventListener('input', () => store.set('sql', ta.value));
    host.append(ta);
    sqlEd = { getValue: () => ta.value, setValue: v => { ta.value = v; }, refresh() {}, focus: () => ta.focus(), getSelection: () => ta.value.substring(ta.selectionStart, ta.selectionEnd) };
  }
}

async function loadDbs(keepSelection = true) {
  try {
    const d = await api('db_list');
    DB.dbs = d.dbs;
    if (!keepSelection || (DB.name && !DB.dbs.some(x => x.name === DB.name))) { DB.name = null; DB.table = null; }
    if (DB.name) await loadTables();
  } catch (e) {
    DB.dbs = [];
    $('#db-tree').innerHTML = `<div class="placeholder" style="padding:30px 12px">${icon('database')}<span>${esc(e.message)}</span><button class="btn btn-sm" id="db-retry">Réessayer</button></div>`;
    $('#db-retry').onclick = () => loadDbs();
    return;
  }
  renderDbTree();
  setDbTab(DB.tab);
}

async function loadTables() {
  if (!DB.name) { DB.tables = []; return; }
  try { DB.tables = (await api('db_tables', { params: { db: DB.name } })).tables; }
  catch (e) { DB.tables = []; fail(e); }
}

function renderDbTree() {
  const vis = DB.dbs.filter(d => DB.showSys || !d.system);
  $('#db-tree').innerHTML = vis.map(d => `
    <div class="db-item ${d.system ? 'sys' : ''} ${d.name === DB.name && !DB.table ? 'active' : ''}" data-db="${esc(d.name)}">
      ${icon('database')}<span>${esc(d.name)}</span><span class="n">${d.tables}</span>
    </div>
    ${d.name === DB.name ? `<div class="db-tables">${DB.tables.map(t => `
      <div class="db-item ${t.name === DB.table ? 'active' : ''}" data-table="${esc(t.name)}">${icon('table')}<span>${esc(t.name)}</span><span class="n">${t.rows}</span></div>`).join('') || '<div class="muted small" style="padding:4px 8px">aucune table</div>'}</div>` : ''}
  `).join('') + `<button class="db-sys-toggle" id="db-sys">${DB.showSys ? 'Masquer' : 'Afficher'} les bases système</button>`;
  $('#db-sys').onclick = () => { DB.showSys = !DB.showSys; renderDbTree(); };
}

$('#db-tree').addEventListener('click', async e => {
  const t = e.target.closest('[data-table]');
  const d = e.target.closest('[data-db]');
  if (t) { DB.table = t.dataset.table; DB.page = 1; DB.order = ''; setDbTab('data'); renderDbTree(); return; }
  if (d) {
    const same = DB.name === d.dataset.db;
    DB.name = d.dataset.db; DB.table = null;
    if (!same) await loadTables();
    setDbTab('tables'); renderDbTree();
  }
});
$('#db-new').onclick = async () => {
  const n = await askText('Nouvelle base de données', 'Nom (lettres, chiffres, _ et -)', '', 'Créer');
  if (!n) return;
  try {
    await api('db_create', { body: { name: n } });
    toast(`Base « ${n} » créée — accessible aussi par dev_user`);
    DB.name = n; DB.table = null; await loadDbs(); setDbTab('tables');
  } catch (e) { fail(e); }
};

function setDbTab(tab) {
  if ((tab === 'data' || tab === 'structure') && !DB.table) tab = 'tables';
  DB.tab = tab;
  $$('#db-tabs button').forEach(b => {
    b.classList.toggle('active', b.dataset.dbtab === tab);
    b.disabled = (b.dataset.dbtab === 'data' || b.dataset.dbtab === 'structure') && !DB.table;
  });
  $$('.db-pane').forEach(p => p.classList.toggle('active', p.id === 'db-pane-' + tab));
  $('#db-title').innerHTML = DB.name ? `${esc(DB.name)}${DB.table ? `<span class="sep">›</span>${esc(DB.table)}` : ''}` : 'Choisis une base';
  renderDbPane();
}
$('#db-tabs').addEventListener('click', e => { const b = e.target.closest('[data-dbtab]'); if (b && !b.disabled) setDbTab(b.dataset.dbtab); });

function renderDbPane() {
  if (DB.tab === 'tables') renderTablesPane();
  else if (DB.tab === 'data') renderDataPane();
  else if (DB.tab === 'structure') renderStructurePane();
  else if (DB.tab === 'sql') {
    if (!sqlEd) initSqlEditor();
    $('#sql-db-label').textContent = DB.name ? `sur la base « ${DB.name} »` : 'aucune base sélectionnée (utilise USE nom;)';
    setTimeout(() => { sqlEd.refresh(); sqlEd.focus(); }, 0);
  }
}

function gridHtml(cols, rows, { numeric = [], actions = null, sortable = false, pk = [] } = {}) {
  const head = (actions ? '<th class="acts"></th>' : '') + cols.map(c => {
    const s = sortable && DB.order === c ? (DB.dir === 'ASC' ? ' ↑' : ' ↓') : '';
    return `<th class="${sortable ? 'sortable' : ''}" data-col="${esc(c)}">${esc(c)}${pk.includes(c) ? '<span class="pk" title="Clé primaire">🔑</span>' : ''}${s}</th>`;
  }).join('');
  const body = rows.map((r, ri) => '<tr>' + (actions ? `<td class="acts">${actions(ri)}</td>` : '') + r.map((v, i) => {
    if (v === null) return '<td class="null">NULL</td>';
    const s = typeof v === 'object' ? JSON.stringify(v) : String(v);
    return `<td class="${numeric[i] ? 'num' : ''}" title="${esc(s.length > 60 ? s.slice(0, 500) : '')}">${esc(s.length > 200 ? s.slice(0, 200) + '…' : s)}</td>`;
  }).join('') + '</tr>').join('');
  return `<div class="grid-wrap"><table class="grid"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

function renderTablesPane() {
  const p = $('#db-pane-tables');
  if (!DB.name) {
    p.innerHTML = `<div class="placeholder">${icon('database')}<span>Sélectionne une base à gauche, ou crée-en une.</span><button class="btn btn-primary" id="tp-new">${icon('plus')}Nouvelle base</button></div>`;
    $('#tp-new').onclick = () => $('#db-new').click();
    return;
  }
  const app = state.info?.app_db;
  const isSys = DB.dbs.find(d => d.name === DB.name)?.system;
  p.innerHTML = `
    <div class="toolbar">
      <button class="btn btn-primary btn-sm" id="tp-create">${icon('plus')}Créer une table</button>
      <button class="btn btn-sm" id="tp-sql">${icon('terminal')}Requête SQL</button>
      <a class="btn btn-sm" href="${esc(apiUrl('db_export', { db: DB.name }))}">${icon('download')}Exporter .sql</a>
      <button class="btn btn-sm" id="tp-import">${icon('upload')}Importer .sql</button>
      <span class="grow"></span>
      ${isSys ? '' : `<button class="btn btn-danger btn-sm" id="tp-drop">${icon('trash')}Supprimer la base</button>`}
    </div>
    ${DB.tables.length ? gridHtml(['Table', 'Lignes', 'Taille', 'Moteur', 'Interclassement'],
      DB.tables.map(t => [t.name + (t.view ? ' (vue)' : ''), t.rows, fmtSize(t.bytes), t.engine || '—', t.collation || '—']),
      { numeric: [false, true, true], actions: i => `<button class="icon-btn" data-browse="${i}" title="Parcourir">${icon('eye')}</button><button class="icon-btn" data-struct="${i}" title="Structure">${icon('table')}</button>` })
      : `<div class="placeholder" style="margin:30px auto">${icon('table')}<span>Base vide. Crée ta première table.</span></div>`}
    ${app ? `<div class="section-title">Connexion depuis ton code PHP</div>
    <div class="code-block">$pdo = new PDO('mysql:host=localhost;dbname=${esc(DB.name)};charset=utf8mb4', '${esc(app.user)}', '${esc(app.pass)}');</div>` : ''}`;
  $('#tp-create').onclick = () => createTableModal();
  $('#tp-sql').onclick = () => setDbTab('sql');
  $('#tp-import').onclick = () => {
    const inp = document.createElement('input'); inp.type = 'file'; inp.accept = '.sql,text/plain';
    inp.onchange = async () => {
      const fd = new FormData(); fd.append('file', inp.files[0]); fd.append('db', DB.name);
      try { await api('db_import', { form: fd, params: { db: DB.name } }); toast('Import terminé'); await loadTables(); renderDbTree(); renderTablesPane(); } catch (e) { fail(e); }
    };
    inp.click();
  };
  $('#tp-drop')?.addEventListener('click', async () => {
    const n = await askText('Supprimer la base', `Tape « ${DB.name} » pour confirmer la suppression définitive`, '', 'Supprimer');
    if (n !== DB.name) { if (n) toast('Nom incorrect, rien supprimé', true); return; }
    try { await api('db_drop', { body: { name: DB.name } }); toast('Base supprimée'); DB.name = null; DB.table = null; await loadDbs(); setDbTab('tables'); } catch (e) { fail(e); }
  });
  p.onclick = e => {
    const b = e.target.closest('[data-browse],[data-struct]'); if (!b) return;
    const t = DB.tables[+(b.dataset.browse ?? b.dataset.struct)];
    DB.table = t.name; DB.page = 1; DB.order = '';
    setDbTab(b.dataset.browse !== undefined ? 'data' : 'structure'); renderDbTree();
  };
}

const NUMERIC_TYPE = /^(tinyint|smallint|mediumint|int|bigint|decimal|float|double|real|bit)/i;

async function renderDataPane() {
  const p = $('#db-pane-data');
  p.innerHTML = '<div class="muted">Chargement…</div>';
  let d;
  try {
    d = await api('db_browse', { params: { db: DB.name, table: DB.table, page: DB.page, per: DB.per, order: DB.order, dir: DB.dir } });
  } catch (e) { p.innerHTML = `<div class="placeholder">${esc(e.message)}</div>`; return; }
  DB.browse = d;
  const cols = d.columns.map(c => c.Field);
  const numeric = d.columns.map(c => NUMERIC_TYPE.test(c.Type));
  const from = d.total ? (d.page - 1) * d.per + 1 : 0, to = Math.min(d.total, d.page * d.per);
  const pages = Math.max(1, Math.ceil(d.total / d.per));
  p.innerHTML = `
    <div class="toolbar">
      <button class="btn btn-primary btn-sm" id="dp-insert">${icon('plus')}Insérer une ligne</button>
      <button class="btn btn-sm" id="dp-refresh">${icon('refresh')}Actualiser</button>
      <span class="grow"></span>
      <div class="pager">
        <span>${from}–${to} sur ${d.total}</span>
        <button class="icon-btn" id="dp-prev" ${d.page <= 1 ? 'disabled' : ''} title="Page précédente" style="transform:rotate(180deg)">${icon('chevron')}</button>
        <span>page ${d.page}/${pages}</span>
        <button class="icon-btn" id="dp-next" ${d.page >= pages ? 'disabled' : ''} title="Page suivante">${icon('chevron')}</button>
        <select id="dp-per" style="width:auto;padding:4px 6px">${[25, 50, 100, 250].map(n => `<option ${n === d.per ? 'selected' : ''}>${n}</option>`).join('')}</select>
      </div>
    </div>
    ${!d.pk.length ? '<div class="muted small">Pas de clé primaire : modification et suppression ligne par ligne indisponibles (utilise l\'onglet SQL).</div>' : ''}
    ${gridHtml(cols, d.rows, {
      numeric, sortable: true, pk: d.pk,
      actions: d.pk.length ? i => `<button class="icon-btn" data-edit="${i}" title="Modifier">${icon('pencil')}</button><button class="icon-btn danger" data-del="${i}" title="Supprimer">${icon('trash')}</button>` : null,
    })}
    ${d.rows.length ? '' : '<div class="placeholder" style="margin:20px auto"><span>Table vide.</span></div>'}`;
  $('#dp-insert').onclick = () => rowModal(null);
  $('#dp-refresh').onclick = renderDataPane;
  $('#dp-prev').onclick = () => { DB.page--; renderDataPane(); };
  $('#dp-next').onclick = () => { DB.page++; renderDataPane(); };
  $('#dp-per').onchange = e => { DB.per = +e.target.value; DB.page = 1; renderDataPane(); };
  p.onclick = async e => {
    const th = e.target.closest('th[data-col]');
    if (th) { const c = th.dataset.col; DB.dir = DB.order === c && DB.dir === 'ASC' ? 'DESC' : 'ASC'; DB.order = c; renderDataPane(); return; }
    const ed = e.target.closest('[data-edit]'), del = e.target.closest('[data-del]');
    if (ed) rowModal(+ed.dataset.edit);
    if (del) {
      const where = pkWhere(+del.dataset.del);
      if (!(await confirmBox('Supprimer la ligne', `Supprimer la ligne où ${esc(Object.entries(where).map(([k, v]) => `${k} = ${v}`).join(', '))} ?`))) return;
      try { await api('db_row_delete', { body: { db: DB.name, table: DB.table, where } }); toast('Ligne supprimée'); renderDataPane(); refreshTableCounts(); } catch (err) { fail(err); }
    }
  };
}

function pkWhere(ri) {
  const d = DB.browse; const w = {};
  d.pk.forEach(k => { w[k] = d.rows[ri][d.columns.findIndex(c => c.Field === k)]; });
  return w;
}

async function refreshTableCounts() { await loadTables(); renderDbTree(); }

function rowModal(ri) {
  const d = DB.browse;
  const editing = ri !== null;
  const row = editing ? d.rows[ri] : null;
  const body = document.createElement('div');
  body.style.cssText = 'display:flex;flex-direction:column;gap:12px';
  body.innerHTML = d.columns.map((c, i) => {
    const v = row ? row[i] : null;
    const isNull = editing && v === null;
    const big = /text|blob|json/i.test(c.Type);
    const auto = /auto_increment/i.test(c.Extra);
    const ph = auto ? 'auto' : (c.Default !== null ? `défaut : ${c.Default}` : /date|time/i.test(c.Type) ? 'AAAA-MM-JJ HH:MM:SS' : '');
    const val = v === null ? '' : String(v);
    const field = big
      ? `<textarea data-f="${i}" rows="3" placeholder="${esc(ph)}">${esc(val)}</textarea>`
      : `<input data-f="${i}" value="${esc(val)}" placeholder="${esc(ph)}" spellcheck="false">`;
    return `<label>${esc(c.Field)} <span class="muted" style="font-weight:400;font-family:var(--mono)">${esc(c.Type)}${c.Key === 'PRI' ? ' · PK' : ''}</span>
      ${field}
      ${c.Null === 'YES' ? `<span style="display:flex;gap:6px;align-items:center;font-weight:400"><input type="checkbox" data-null="${i}" ${isNull ? 'checked' : ''}> NULL</span>` : ''}
    </label>`;
  }).join('');
  modal({
    title: editing ? 'Modifier la ligne' : `Insérer dans ${DB.table}`, body, wide: d.columns.length > 6,
    actions: [{ label: 'Annuler' }, {
      label: editing ? 'Enregistrer' : 'Insérer', cls: 'btn-primary', handler: async b => {
        const values = {};
        d.columns.forEach((c, i) => {
          const f = $(`[data-f="${i}"]`, b), n = $(`[data-null="${i}"]`, b);
          const nv = n?.checked ? null : f.value;
          if (editing) {
            const orig = row[i] === null ? null : String(row[i]);
            if (nv !== orig) values[c.Field] = nv;
          } else if (n?.checked || f.value !== '') values[c.Field] = nv;
        });
        if (!Object.keys(values).length) { if (editing) return true; toast('Remplis au moins un champ', true); return false; }
        await api('db_row_save', { body: { db: DB.name, table: DB.table, values, where: editing ? pkWhere(ri) : {} } });
        toast(editing ? 'Ligne modifiée' : 'Ligne insérée');
        renderDataPane(); if (!editing) refreshTableCounts();
        return true;
      },
    }],
  });
}

async function renderStructurePane() {
  const p = $('#db-pane-structure');
  p.innerHTML = '<div class="muted">Chargement…</div>';
  let d;
  try { d = await api('db_structure', { params: { db: DB.name, table: DB.table } }); }
  catch (e) { p.innerHTML = `<div class="placeholder">${esc(e.message)}</div>`; return; }
  p.innerHTML = `
    <div class="toolbar">
      <button class="btn btn-sm" id="sp-rename">${icon('pencil')}Renommer</button>
      <button class="btn btn-sm" id="sp-alter">${icon('plus')}Ajouter une colonne</button>
      <span class="grow"></span>
      <button class="btn btn-sm btn-danger" id="sp-truncate">Vider</button>
      <button class="btn btn-sm btn-danger" id="sp-drop">${icon('trash')}Supprimer la table</button>
    </div>
    <div class="section-title">Colonnes</div>
    ${gridHtml(['Champ', 'Type', 'Null', 'Clé', 'Défaut', 'Extra', 'Commentaire'], d.columns.map(c => [c.Field, c.Type, c.Null, c.Key, c.Default, c.Extra, c.Comment]))}
    <div class="section-title">Index</div>
    ${d.indexes.length ? gridHtml(['Nom', 'Colonne', 'Unique', 'Type'], d.indexes.map(i => [i.Key_name, i.Column_name, i.Non_unique == 0 ? 'oui' : 'non', i.Index_type])) : '<div class="muted small">Aucun index</div>'}
    <div class="section-title">SQL de création</div>
    <div class="code-block">${esc(d.create)}</div>`;
  const op = async (opName, extra = {}) => { await api('db_table_op', { body: { db: DB.name, table: DB.table, op: opName, ...extra } }); };
  $('#sp-rename').onclick = async () => {
    const n = await askText('Renommer la table', 'Nouveau nom', DB.table, 'Renommer'); if (!n || n === DB.table) return;
    try { await op('rename', { to: n }); DB.table = n; await refreshTableCounts(); setDbTab('structure'); } catch (e) { fail(e); }
  };
  $('#sp-alter').onclick = () => {
    if (!sqlEd) initSqlEditor();
    sqlEd.setValue(`ALTER TABLE ${qi(DB.table)}\n  ADD COLUMN \`nouvelle_colonne\` VARCHAR(255) NULL;`);
    setDbTab('sql');
  };
  $('#sp-truncate').onclick = async () => {
    if (!(await confirmBox('Vider la table', `Supprimer <b>toutes les lignes</b> de ${esc(DB.table)} ?`, 'Vider'))) return;
    try { await op('truncate'); toast('Table vidée'); refreshTableCounts(); } catch (e) { fail(e); }
  };
  $('#sp-drop').onclick = async () => {
    if (!(await confirmBox('Supprimer la table', `Supprimer définitivement la table <b>${esc(DB.table)}</b> ?`))) return;
    try { await op('drop'); toast('Table supprimée'); DB.table = null; await refreshTableCounts(); setDbTab('tables'); } catch (e) { fail(e); }
  };
}

/* ----- Constructeur de table ----- */
const COL_TYPES = ['INT', 'BIGINT', 'TINYINT', 'VARCHAR', 'CHAR', 'TEXT', 'LONGTEXT', 'DECIMAL', 'FLOAT', 'DOUBLE', 'BOOLEAN', 'DATE', 'DATETIME', 'TIMESTAMP', 'TIME', 'JSON', 'BLOB'];
function buildCreateSql(name, cols) {
  const lines = cols.filter(c => c.name).map(c => {
    let t = c.type;
    if (c.len && /^(VARCHAR|CHAR|DECIMAL|INT|BIGINT|TINYINT)$/.test(t)) t += `(${c.len})`;
    else if (t === 'VARCHAR') t = 'VARCHAR(255)';
    else if (t === 'CHAR') t = 'CHAR(1)';
    else if (t === 'DECIMAL') t = 'DECIMAL(10,2)';
    let s = `  ${qi(c.name)} ${t}${c.nullable ? ' NULL' : ' NOT NULL'}`;
    if (c.ai) s += ' AUTO_INCREMENT';
    if (c.def !== '') s += ' DEFAULT ' + (/^(CURRENT_TIMESTAMP(\(\))?|NULL|TRUE|FALSE|-?\d+(\.\d+)?)$/i.test(c.def) ? c.def : sqlStr(c.def));
    return s;
  });
  const pk = cols.filter(c => c.name && c.pk).map(c => qi(c.name));
  if (pk.length) lines.push(`  PRIMARY KEY (${pk.join(', ')})`);
  return `CREATE TABLE ${qi(name || 'ma_table')} (\n${lines.join(',\n')}\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`;
}
function createTableModal() {
  const cols = [
    { name: 'id', type: 'INT', len: '', def: '', nullable: false, ai: true, pk: true },
    { name: 'nom', type: 'VARCHAR', len: '255', def: '', nullable: false, ai: false, pk: false },
    { name: 'cree_le', type: 'DATETIME', len: '', def: 'CURRENT_TIMESTAMP', nullable: false, ai: false, pk: false },
  ];
  const body = document.createElement('div');
  body.style.cssText = 'display:flex;flex-direction:column;gap:14px';
  const render = () => {
    body.innerHTML = `<label>Nom de la table<input data-tname value="${esc(body.dataset.tname || '')}" placeholder="utilisateurs" spellcheck="false"></label>
      <div class="cols-builder">
        <div class="col-row head"><span>Colonne</span><span>Type</span><span>Taille</span><span>Défaut</span><span>NULL</span><span>A_I</span><span>PK</span><span></span></div>
        ${cols.map((c, i) => `<div class="col-row" data-c="${i}">
          <input data-k="name" value="${esc(c.name)}" spellcheck="false">
          <select data-k="type">${COL_TYPES.map(t => `<option ${t === c.type ? 'selected' : ''}>${t}</option>`).join('')}</select>
          <input data-k="len" value="${esc(c.len)}" placeholder="—">
          <input data-k="def" value="${esc(c.def)}" placeholder="—" spellcheck="false">
          <label class="chk"><input type="checkbox" data-k="nullable" ${c.nullable ? 'checked' : ''}></label>
          <label class="chk"><input type="checkbox" data-k="ai" ${c.ai ? 'checked' : ''}></label>
          <label class="chk"><input type="checkbox" data-k="pk" ${c.pk ? 'checked' : ''}></label>
          <button class="icon-btn danger" data-rm title="Retirer">${icon('x')}</button>
        </div>`).join('')}
      </div>
      <div><button class="btn btn-sm" data-add>${icon('plus')}Ajouter une colonne</button></div>
      <div class="section-title">SQL généré</div>
      <div class="code-block" data-preview></div>`;
    preview();
  };
  const preview = () => { $('[data-preview]', body).textContent = buildCreateSql(body.dataset.tname, cols); };
  body.addEventListener('input', e => {
    if (e.target.matches('[data-tname]')) { body.dataset.tname = e.target.value; return preview(); }
    const r = e.target.closest('[data-c]'); if (!r) return;
    const c = cols[+r.dataset.c], k = e.target.dataset.k;
    c[k] = e.target.type === 'checkbox' ? e.target.checked : e.target.value;
    if (k === 'ai' && c.ai) { c.pk = true; c.type = /INT/.test(c.type) ? c.type : 'INT'; render(); return; }
    preview();
  });
  body.addEventListener('change', e => { if (e.target.tagName === 'SELECT') body.dispatchEvent(new Event('input')); });
  body.addEventListener('click', e => {
    if (e.target.closest('[data-add]')) { cols.push({ name: '', type: 'VARCHAR', len: '255', def: '', nullable: true, ai: false, pk: false }); render(); $$('[data-k=name]', body).pop().focus(); }
    const rm = e.target.closest('[data-rm]'); if (rm) { cols.splice(+rm.closest('[data-c]').dataset.c, 1); render(); }
  });
  render();
  modal({
    title: `Nouvelle table dans ${DB.name}`, body, wide: true,
    actions: [{ label: 'Annuler' }, {
      label: 'Créer la table', cls: 'btn-primary', handler: async () => {
        const name = (body.dataset.tname || '').trim();
        if (!name) { toast('Donne un nom à la table', true); return false; }
        const r = await api('db_query', { body: { db: DB.name, sql: buildCreateSql(name, cols) } });
        const err = r.results.find(x => x.error); if (err) throw new Error(err.error);
        toast(`Table « ${name} » créée`);
        DB.table = name; await refreshTableCounts(); setDbTab('structure');
        return true;
      },
    }],
  });
}

/* ----- Éditeur SQL ----- */
const SNIPPETS = {
  select: t => `SELECT *\nFROM ${qi(t || 'ma_table')}\nWHERE 1\nLIMIT 100;`,
  insert: t => `INSERT INTO ${qi(t || 'ma_table')} (colonne1, colonne2)\nVALUES ('valeur1', 'valeur2');`,
  update: t => `UPDATE ${qi(t || 'ma_table')}\nSET colonne1 = 'valeur'\nWHERE id = 1;`,
  create: () => `CREATE TABLE produits (\n  id INT AUTO_INCREMENT PRIMARY KEY,\n  nom VARCHAR(255) NOT NULL,\n  prix DECIMAL(10,2) DEFAULT 0,\n  cree_le DATETIME DEFAULT CURRENT_TIMESTAMP\n);`,
};
$('#db-pane-sql').addEventListener('click', e => {
  const s = e.target.closest('[data-snippet]'); if (!s) return;
  sqlEd.setValue(SNIPPETS[s.dataset.snippet](DB.table)); sqlEd.focus();
});
$('#sql-run').onclick = () => runSql();

async function runSql() {
  const sel = sqlEd.getSelection?.() || '';
  const sql = (sel.trim() ? sel : sqlEd.getValue()).trim();
  if (!sql) return;
  const out = $('#sql-results');
  out.innerHTML = '<div class="muted">Exécution…</div>';
  try {
    const r = await api('db_query', { body: { db: DB.name || '', sql } });
    out.innerHTML = r.results.map(x => {
      if (x.error) return `<div class="result err"><div class="result-head"><span class="q">${esc(x.sql)}</span><span>Erreur</span></div><div class="result-msg">${esc(x.error)}</div></div>`;
      const info = x.columns ? `${x.count} ligne(s)${x.truncated ? ' (1000 affichées)' : ''}` : `${x.affected} ligne(s) affectée(s)`;
      return `<div class="result"><div class="result-head"><span class="q">${esc(x.sql)}</span><span>${info} · ${x.ms} ms</span></div>
        ${x.columns ? (x.rows.length ? gridHtml(x.columns, x.rows, { numeric: x.columns.map((_, i) => x.rows.length && typeof x.rows[0][i] === 'number') }) : '<div class="result-msg muted">Aucun résultat</div>') : '<div class="result-msg" style="color:var(--ok)">✓ OK</div>'}</div>`;
    }).join('') || '<div class="muted">Aucune requête</div>';
    const changed = r.results.some(x => !x.columns && !x.error);
    if (r.db && r.db !== DB.name) { DB.name = r.db; DB.table = null; await loadTables(); renderDbTree(); setDbTab('sql'); }
    if (changed) { const keep = DB.table; await loadDbs(); DB.table = keep && DB.tables.some(t => t.name === keep) ? keep : null; renderDbTree(); }
  } catch (e) { out.innerHTML = `<div class="result err"><div class="result-msg">${esc(e.message)}</div></div>`; }
}

/* =============== Terminal =============== */
const T = state.term;

function fillCwd() {
  const sel = $('#term-cwd');
  const fill = list => {
    sel.innerHTML = `<option value="">/var/www (racine)</option>` + list.map(p => `<option value="${esc(p.name)}">${esc(p.name)}${p.type === 'react' ? '  · React' : p.type === 'php' ? '  · PHP' : ''}</option>`).join('');
    if (T.cwd && !list.some(p => p.name === T.cwd)) sel.insertAdjacentHTML('beforeend', `<option value="${esc(T.cwd)}">${esc(T.cwd)}</option>`);
    sel.value = T.cwd; updPrompt();
  };
  if (state.projects.length) fill(state.projects);
  else api('projects').then(d => { state.projects = d.projects; fill(d.projects); }).catch(() => fill([]));
}
const updPrompt = () => { $('#term-prompt').textContent = `~/www${T.cwd ? '/' + T.cwd : ''} $`; };
$('#term-cwd').onchange = e => { T.cwd = e.target.value; store.set('cwd', T.cwd); updPrompt(); $('#term-cmd').focus(); };

function runInTerminal(cwd, cmd) {
  T.cwd = cwd; store.set('cwd', cwd);
  show('terminal');
  startCommand(cmd);
}

async function startCommand(cmd) {
  cmd = cmd.trim(); if (!cmd) return;
  T.history = [cmd, ...T.history.filter(h => h !== cmd)].slice(0, 50); store.set('history', T.history); T.hIdx = -1;
  try {
    const r = await api('run', { body: { cwd: T.cwd, cmd } });
    attachJob(r.job);
    loadJobs();
  } catch (e) { fail(e); }
}

$('#term-form').addEventListener('submit', e => { e.preventDefault(); const i = $('#term-cmd'); const c = i.value; i.value = ''; startCommand(c); });
$('#term-cmd').addEventListener('keydown', e => {
  if (e.key === 'ArrowUp' && T.hIdx < T.history.length - 1) { T.hIdx++; e.target.value = T.history[T.hIdx]; e.preventDefault(); }
  if (e.key === 'ArrowDown') { T.hIdx = Math.max(-1, T.hIdx - 1); e.target.value = T.hIdx < 0 ? '' : T.history[T.hIdx]; e.preventDefault(); }
});
$('#term-quick').addEventListener('click', e => { const b = e.target.closest('[data-cmd]'); if (b) startCommand(b.dataset.cmd); });

const ANSI = /\x1b\[[0-9;?]*[ -\/]*[@-~]|\x1b\][^\x07]*\x07/g;
function termAppend(text) {
  const out = $('#term-out');
  const atBottom = out.scrollHeight - out.scrollTop - out.clientHeight < 60;
  const clean = text.replace(ANSI, '').replace(/\r(?!\n)/g, '\n').replace(/\n?__DS_EXIT__:\d+\s*$/, '');
  const html = esc(clean).replace(/https?:\/\/[^\s<>"']+/g, u => `<span class="hl-url" data-url="${u}">${u}</span>`);
  out.insertAdjacentHTML('beforeend', html);
  if (atBottom) out.scrollTop = out.scrollHeight;
}
$('#term-out').addEventListener('click', e => {
  const u = e.target.closest('.hl-url'); if (!u) return;
  let url = u.dataset.url.replace(/&amp;/g, '&');
  try { const x = new URL(url); if (['localhost', '127.0.0.1', '0.0.0.0', '[::1]'].includes(x.hostname)) { x.hostname = location.hostname; url = x.href; } } catch {}
  window.open(url, '_blank');
});

function attachJob(job) {
  clearTimeout(T.timer);
  T.job = job.id; T.offset = 0;
  const out = $('#term-out');
  out.innerHTML = `<div class="cmdline"><span class="cwd">~/www${job.cwd ? '/' + esc(job.cwd) : ''}</span> $ ${esc(job.cmd)}</div>`;
  renderJobs();
  pollJob();
}

async function pollJob() {
  const id = T.job; if (!id) return;
  try {
    const r = await api('job_poll', { params: { id, offset: T.offset } });
    if (T.job !== id) return;
    if (r.chunk) termAppend(r.chunk);
    T.offset = r.offset;
    if (r.job.running) { T.timer = setTimeout(pollJob, 700); updateJobInList(r.job); return; }
    const ok = r.job.exit === 0;
    $('#term-out').insertAdjacentHTML('beforeend', `<div class="${ok ? 'done-ok' : 'done-err'}">${ok ? '✔ Terminé' : r.job.exit === 143 ? '■ Arrêté' : `✖ Terminé avec le code ${r.job.exit}`}</div>`);
    $('#term-out').scrollTop = $('#term-out').scrollHeight;
    updateJobInList(r.job);
    state.projects = [];
    if (state.view === 'terminal') fillCwd();
  } catch (e) { fail(e); }
}

async function loadJobs() {
  try { state.jobs = (await api('jobs')).jobs; } catch { return; }
  renderJobs();
  if (!T.job && state.view === 'terminal') { const j = state.jobs.find(x => x.running) || state.jobs[0]; if (j) attachJob(j); }
}
function updateJobInList(j) {
  const i = state.jobs.findIndex(x => x.id === j.id);
  if (i >= 0) state.jobs[i] = j; else state.jobs.unshift(j);
  renderJobs();
}
function renderJobs() {
  const running = state.jobs.some(j => j.running);
  const tb = $('.rail-btn[data-view=terminal]');
  tb.querySelector('.dot')?.remove();
  if (running) tb.insertAdjacentHTML('beforeend', '<span class="dot"></span>');
  $('#jobs-list').innerHTML = state.jobs.length ? state.jobs.map(j => `
    <div class="job ${j.running ? 'run' : j.exit === 0 ? 'ok' : 'err'} ${j.id === T.job ? 'active' : ''}" data-job="${esc(j.id)}">
      <span class="jdot"></span>
      <div class="jbody"><div class="jcmd" title="${esc(j.cmd)}">${esc(j.label || j.cmd)}</div><div class="jmeta">${esc(j.cwd || 'www')} · ${fmtAgo(j.started)}${j.running ? ' · en cours' : ''}</div></div>
      ${j.running ? `<button class="icon-btn danger" data-kill="${esc(j.id)}" title="Arrêter">${icon('stop')}</button>` : ''}
    </div>`).join('') : '<div class="muted small" style="padding:10px">Aucun processus</div>';
}
$('#jobs-list').addEventListener('click', async e => {
  const k = e.target.closest('[data-kill]');
  if (k) {
    try { await api('job_kill', { body: { id: k.dataset.kill } }); toast('Processus arrêté'); loadJobs(); } catch (err) { fail(err); }
    return;
  }
  const j = e.target.closest('[data-job]');
  if (j) { const job = state.jobs.find(x => x.id === j.dataset.job); if (job) attachJob(job); }
});
$('#jobs-clear').onclick = async () => { try { await api('jobs_clear', { body: {} }); loadJobs(); } catch (e) { fail(e); } };
setInterval(() => { if (!document.hidden && (state.view === 'terminal' || state.jobs.some(j => j.running))) loadJobs(); }, 5000);

/* =============== Paramètres =============== */
async function loadSettings() {
  const i = await loadInfo();
  if (!i) return;
  const a = i.app_db;
  $('#dbinfo').innerHTML = `
    <dl class="kv">
      <dt>Hôte</dt><dd>localhost</dd><span></span>
      <dt>Utilisateur</dt><dd>${esc(a.user)}</dd><button class="icon-btn" data-copy="${esc(a.user)}" title="Copier">${icon('copy')}</button>
      <dt>Mot de passe</dt><dd data-secret="${esc(a.pass)}">••••••••</dd><span style="display:flex"><button class="icon-btn" data-reveal title="Afficher">${icon('eye')}</button><button class="icon-btn" data-copy="${esc(a.pass)}" title="Copier">${icon('copy')}</button></span>
      <dt>Base par défaut</dt><dd>${esc(a.db)}</dd><span></span>
    </dl>
    <p class="muted small">Cet utilisateur a tous les droits sur chaque base créée depuis Dev Studio. Exemple :</p>
    <div class="code-block">$pdo = new PDO(
  'mysql:host=localhost;dbname=${esc(a.db)};charset=utf8mb4',
  '${esc(a.user)}', '${esc(a.pass)}'
);</div>`;
  const s = (k, v) => `<dt>${k}</dt><dd>${esc(v)}</dd><span></span>`;
  $('#serverinfo').innerHTML = `<dl class="kv">
    ${s('Machine', i.hostname)}${s('Connecté', i.user)}${s('PHP', i.php)}${s('Node.js', i.node || '—')}${s('npm', i.npm || '—')}
    ${s('MariaDB', i.mysql || 'arrêté')}${s('Disque libre', fmtSize(i.disk_free))}${s('Dev Studio', 'v' + i.version)}
  </dl>`;
  $('#form-username [name=username]').placeholder = i.user;
}
$('#view-settings').addEventListener('click', e => {
  const c = e.target.closest('[data-copy]'); if (c) copyText(c.dataset.copy);
  const r = e.target.closest('[data-reveal]');
  if (r) { const dd = $('[data-secret]', $('#dbinfo')); dd.textContent = dd.textContent.startsWith('•') ? dd.dataset.secret : '••••••••'; }
});
function pwScore(p) {
  let s = 0;
  if (p.length >= 8) s++; if (p.length >= 12) s++; if (p.length >= 16) s++;
  if (/[a-z]/.test(p) && /[A-Z]/.test(p)) s++; if (/\d/.test(p)) s++; if (/[^A-Za-z0-9]/.test(p)) s++;
  return Math.min(5, s);
}
$('#form-password [name=new]').addEventListener('input', e => {
  const s = pwScore(e.target.value);
  const f = $('#pw-meter-fill');
  f.style.width = (s / 5 * 100) + '%';
  f.style.background = ['var(--danger)', 'var(--danger)', 'var(--warn)', 'var(--warn)', 'var(--ok)', 'var(--accent)'][s];
});
$('#form-password').addEventListener('submit', async e => {
  e.preventDefault();
  const f = new FormData(e.target);
  if (f.get('new') !== f.get('confirm')) return toast('La confirmation ne correspond pas', true);
  try {
    await api('settings_password', { body: Object.fromEntries(f) });
    toast('Mot de passe changé ✔'); e.target.reset(); $('#pw-meter-fill').style.width = '0';
  } catch (err) { fail(err); }
});
$('#form-username').addEventListener('submit', async e => {
  e.preventDefault();
  try {
    const r = await api('settings_username', { body: Object.fromEntries(new FormData(e.target)) });
    DS.user = r.user; toast(`Identifiant changé : ${r.user}`); e.target.reset(); loadSettings();
  } catch (err) { fail(err); }
});

/* =============== Démarrage =============== */
hydrateIcons();
$$('.rail-btn[data-view]').forEach(b => b.addEventListener('click', () => show(b.dataset.view)));
window.addEventListener('hashchange', () => show(location.hash.slice(1)));
renderTabs();
show(location.hash.slice(1) || 'projects');
loadJobs();
})();
DSEOF_5_ASSETS_APP_JS
}

if [ "${1:-}" = "--files-only" ]; then write_files; echo "Fichiers écrits dans $DASH"; exit 0; fi
[ "$(id -u)" = 0 ] || { echo "Lance ce script en root."; exit 1; }

# ---------------------------------------------------------------------
c_step "1/7  Paquets (nginx, PHP, MariaDB, Node.js)"
apt-get update -qq
apt-get install -y -qq nginx php-fpm php-cli php-mysql php-curl php-gd php-mbstring php-xml php-zip \
  mariadb-server mariadb-client curl ca-certificates unzip locales >/dev/null
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null
  apt-get install -y -qq nodejs >/dev/null
fi
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen >/dev/null 2>&1 || true
update-locale LANG=en_US.UTF-8 >/dev/null 2>&1 || true
PHPV=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
c_ok "PHP $PHPV · Node $(node -v) · $(mariadb --version | awk '{print $5}' | tr -d ,)"

# ---------------------------------------------------------------------
c_step "2/7  Correctif systemd pour conteneur non privilégié"
# Sans 'nesting', le sandbox systemd de MariaDB échoue (status=226/NAMESPACE).
mkdir -p /etc/systemd/system/mariadb.service.d
cat > /etc/systemd/system/mariadb.service.d/override.conf <<'EOF'
[Service]
ProtectSystem=false
ProtectHome=false
PrivateDevices=false
PrivateTmp=false
ProtectKernelTunables=false
ProtectControlGroups=false
EOF
systemctl daemon-reload
systemctl enable --now mariadb >/dev/null 2>&1 || true
for i in $(seq 1 20); do [ -S /run/mysqld/mysqld.sock ] && break; sleep 1; done
if [ ! -S /run/mysqld/mysqld.sock ]; then
  c_warn "MariaDB ne démarre pas. Diagnostic : journalctl -u mariadb -n 30 --no-pager"
  exit 1
fi
c_ok "MariaDB démarré"

# ---------------------------------------------------------------------
c_step "3/7  Configuration Dev Studio (identifiants, secrets)"
mkdir -p "$DATA/sessions" "$DATA/jobs" "$DATA/home"
php <<'PHPEOF'
<?php
$f = '/var/lib/devstudio/config.json';
$c = is_file($f) ? (json_decode(file_get_contents($f), true) ?: []) : [];
$new = empty($c['password_hash']);
$c += [
  'username' => 'admin',
  'password_hash' => password_hash('admin', PASSWORD_DEFAULT),
];
$c['db'] = ($c['db'] ?? []) + ['user' => 'devstudio', 'pass' => bin2hex(random_bytes(16))];
$c['app_db'] = ($c['app_db'] ?? []) + ['user' => 'dev_user', 'pass' => 'devpassword', 'db' => 'dev_db'];
file_put_contents($f, json_encode($c, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
echo $new ? "Compte créé : admin / admin\n" : "Compte existant conservé (" . $c['username'] . ")\n";
PHPEOF
cfg() { php -r '$c=json_decode(file_get_contents("/var/lib/devstudio/config.json"),true); echo $c'"$1"';'; }
DBPASS=$(cfg '["db"]["pass"]')
APPUSER=$(cfg '["app_db"]["user"]')
APPPASS=$(cfg '["app_db"]["pass"]')
APPDB=$(cfg '["app_db"]["db"]')
APPPASS_SQL=${APPPASS//\'/\'\'}
mariadb <<SQL
CREATE USER IF NOT EXISTS 'devstudio'@'localhost' IDENTIFIED BY '${DBPASS}';
ALTER USER 'devstudio'@'localhost' IDENTIFIED BY '${DBPASS}';
GRANT ALL PRIVILEGES ON *.* TO 'devstudio'@'localhost' WITH GRANT OPTION;
CREATE DATABASE IF NOT EXISTS \`${APPDB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${APPUSER}'@'localhost' IDENTIFIED BY '${APPPASS_SQL}';
GRANT ALL PRIVILEGES ON \`${APPDB}\`.* TO '${APPUSER}'@'localhost';
FLUSH PRIVILEGES;
SQL
c_ok "Utilisateurs MySQL prêts (devstudio = admin du dashboard, ${APPUSER} = pour tes projets)"

# ---------------------------------------------------------------------
c_step "4/7  Fichiers du dashboard"
write_files
c_ok "Installé dans /var/www/dashboard"

# ---------------------------------------------------------------------
c_step "5/7  PHP (envois jusqu'à 256 Mo)"
cat > /etc/php/$PHPV/fpm/conf.d/99-devstudio.ini <<'EOF'
upload_max_filesize = 256M
post_max_size = 260M
max_file_uploads = 500
max_execution_time = 300
memory_limit = 256M
EOF
systemctl enable php$PHPV-fpm >/dev/null 2>&1 || true
systemctl restart php$PHPV-fpm
c_ok "php$PHPV-fpm redémarré"

# ---------------------------------------------------------------------
c_step "6/7  Nginx"
[ -f /etc/nginx/sites-available/default ] && [ ! -f /etc/nginx/sites-available/default.avant-devstudio ] && \
  cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.avant-devstudio
cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root /var/www;
    index index.php index.html index.htm;
    client_max_body_size 260M;
    autoindex on;
    autoindex_localtime on;

    location = / { return 302 /dashboard/; }
    location = /dashboard { return 301 /dashboard/; }
    location ^~ /dashboard/inc/ { deny all; }
    location ~ /\.(?!well-known) { deny all; }

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHPV}-fpm.sock;
        fastcgi_read_timeout 300;
    }
}
EOF
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
nginx -t >/dev/null 2>&1 || { nginx -t; exit 1; }
systemctl enable nginx >/dev/null 2>&1 || true
systemctl restart nginx
c_ok "Nginx configuré"

# ---------------------------------------------------------------------
c_step "7/7  Permissions"
chown -R www-data:www-data /var/www "$DATA"
chmod -R u+rwX,g+rwX /var/www
chmod 700 "$DATA"; chmod 600 "$DATA/config.json"
# Le dashboard appartient à root : tes projets PHP ne peuvent pas le modifier.
chown -R root:root "$DASH"; chmod -R a+rX,go-w "$DASH"
c_ok "OK"

# ---------------------------------------------------------------------
echo
FAIL=0
for s in nginx php$PHPV-fpm mariadb; do
  if systemctl is-active --quiet "$s"; then c_ok "$s actif"; else c_warn "$s INACTIF  →  journalctl -u $s -n 30 --no-pager"; FAIL=1; fi
done
CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/dashboard/ || true)
[ "$CODE" = "200" ] && c_ok "Dashboard répond (HTTP 200)" || { c_warn "Dashboard : HTTP $CODE"; FAIL=1; }

TS=$(tailscale ip -4 2>/dev/null | head -n1 || true)
LAN=$(hostname -I 2>/dev/null | awk '{print $1}')
echo
echo "================================================================"
[ -n "$TS" ]  && echo "  Dev Studio (Tailscale) : http://$TS/dashboard/"
[ -n "$LAN" ] && echo "  Dev Studio (réseau)    : http://$LAN/dashboard/"
echo "  Connexion              : admin / admin  (change-le dans Réglages)"
echo "  Projets                : http://<ip>/<nom-du-projet>/"
echo "================================================================"
[ $FAIL = 0 ] || exit 1
