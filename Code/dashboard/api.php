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
