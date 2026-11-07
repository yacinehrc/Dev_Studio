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
