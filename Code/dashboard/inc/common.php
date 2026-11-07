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
