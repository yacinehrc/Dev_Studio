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
