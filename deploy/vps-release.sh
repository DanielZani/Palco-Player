#!/usr/bin/env bash
# Linux VPS only. The Windows coordinator supplies a private upload directory.
set -euo pipefail
exec python3 - "$@" <<'PY'
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tarfile
import tempfile
import time

FILES = ("index.html", "docs/manual.html", "docs/arquitetura.html")
HOST = "player.zani.ia.br"
# https://github.com/nginx/docker-nginx-unprivileged (official non-root port 8080).
# Immutable linux/amd64 manifest; Docker verifies its digest on pull.
IMAGE = "nginx/nginx-unprivileged:1.30.6-alpine-slim@sha256:f597851ed3b6963fd5703225af4d31034bda960a5db20c5de51495ce0403e512"
NGINX_CONF_SHA256 = "a0f76580980d925efa968fe7933a28b9f73cc7d7b8ba8e6abd11ae64e57ff7b9"
OWNER = "br.ia.zani.player.release"
ROUTE = "palco-player-release.yml"
NETWORK = "proxy"
LIMIT = 16 * 1024 * 1024
SHA = re.compile(r"[a-f0-9]{40}")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def run(*args, timeout=60):
    p = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    require(p.returncode == 0, f"Falha em {args[0]} {args[1]} (codigo {p.returncode}).")
    return p.stdout


def digest(data):
    return hashlib.sha256(data).hexdigest()


def atomic(path, data, *, replace):
    # The file provider ignores .tmp. No partial configuration becomes visible.
    fd, tmp = tempfile.mkstemp(prefix=".palco-", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
        os.chmod(tmp, 0o644)
        if replace:
            os.replace(tmp, path)
        else:
            os.link(tmp, path)
        dfd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(dfd)
        finally:
            os.close(dfd)
    finally:
        Path(tmp).unlink(missing_ok=True)


def trusted_dir(path):
    s = path.lstat()
    require(stat.S_ISDIR(s.st_mode) and s.st_uid == os.geteuid() and
            not (s.st_mode & 0o022), "Diretorio substituido, compartilhado ou sem ownership.")


def regular(path, limit=LIMIT):
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= limit,
            "Arquivo inesperado, excessivo ou link: " + path.name)
    return path.read_bytes()


def get_payload(upload):
    trusted_dir(upload)
    manifest = regular(upload / "SHA256SUMS", 4096).decode("ascii").splitlines()
    checks = {}
    for line in manifest:
        match = re.fullmatch(r"([0-9a-f]{64}) [ *](?:\./)?(.+)", line)
        require(match and match[2] in FILES and match[2] not in checks, "Manifesto invalido.")
        checks[match[2]] = match[1]
    require(set(checks) == set(FILES), "Manifesto incompleto.")
    archive = upload / "site.tar.gz"
    require(archive.is_file() and not archive.is_symlink() and archive.stat().st_size <= LIMIT,
            "Pacote de site invalido.")
    contents = {}
    with tarfile.open(archive, "r|gz") as tar:
        for i, entry in enumerate(tar):
            require(i < 12, "Entradas em excesso no pacote.")
            name = entry.name.removeprefix("./")
            if entry.isdir() and name in (".", "", "docs"):
                continue
            require(entry.isfile() and name in FILES and name not in contents and 0 < entry.size <= LIMIT,
                    "Entrada imprevista no pacote de site.")
            data = tar.extractfile(entry).read()
            require(digest(data) == checks[name], "SHA256 divergente: " + name)
            contents[name] = data
    require(set(contents) == set(FILES), "Pacote incompleto.")
    return contents


def docker_ids(*args):
    return run("docker", "ps", "-aq", *args).decode().split()


def details(ids):
    if not ids:
        return []
    return json.loads(run("docker", "inspect", *ids))


def container_name(sha):
    return "palco-player-" + sha


def container(sha):
    found = details(docker_ids("--filter", "name=^/" + container_name(sha) + "$"))
    if not found:
        return None
    item = found[0]
    require(len(found) == 1 and item["Config"]["Labels"].get(OWNER) == sha
            and item["Config"]["Image"] == IMAGE and item["Name"] == "/" + container_name(sha),
            "Conflito de ownership no container da release.")
    return item


def ingress():
    all_containers = details(docker_ids())
    candidates = [c for c in all_containers if c["State"]["Running"] and
                  c["Config"]["Image"].split("@")[0].split("/")[-1].split(":")[0] == "traefik"
                  and NETWORK in c["NetworkSettings"]["Networks"]]
    require(len(candidates) == 1, "Traefik em execucao na rede proxy ausente ou ambiguo.")
    proxy = candidates[0]
    flags = {}
    for arg in (proxy["Config"].get("Cmd") or []):
        if arg.startswith("--") and "=" in arg:
            k, v = arg[2:].split("=", 1)
            flags[k.lower()] = v
    require(flags.get("providers.file.watch", "true").lower() == "true",
            "File provider sem atualizacao dinamica.")
    folder = flags.get("providers.file.directory", "").rstrip("/")
    require(folder.startswith("/"), "Diretorio do file provider nao identificado.")
    mounts = [(m["Destination"].rstrip("/"), m["Source"]) for m in proxy["Mounts"]
              if m["Type"] == "bind" and (folder == m["Destination"].rstrip("/") or
              folder.startswith(m["Destination"].rstrip("/") + "/"))]
    require(mounts, "Bind mount do file provider nao identificado.")
    destination, source = max(mounts, key=lambda kv: len(kv[0]))
    live = Path(source) / folder[len(destination):].lstrip("/")
    require(live.is_dir() and live.resolve() == live, "Diretorio de rotas ausente ou indireto.")
    entries = [k.split(".")[1] for k,v in flags.items()
               if re.fullmatch(r"entrypoints\.[a-z0-9_-]+\.address", k)
               and re.search(r":443(?:/tcp)?$", v)]
    resolvers = {k.split(".")[1] for k in flags
                 if re.match(r"certificatesresolvers\.[a-z0-9_-]+\.acme\.", k)}
    require(len(entries) == 1 and len(resolvers) == 1,
            "Entrypoint HTTPS ou resolver ACME ausente/ambiguo. Verificar configuracao real.")
    # No takeover of another explicitly assigned host, including stopped containers.
    for c in all_containers:
        for key, value in (c["Config"].get("Labels") or {}).items():
            if key.lower().startswith("traefik.http.routers.") and key.lower().endswith(".rule"):
                require(HOST not in str(value).lower(), "Hostname ja vinculado via provider Docker.")
    for path in live.rglob("*"):
        if path.suffix.lower() in (".yml", ".yaml", ".toml") and path != live / ROUTE:
            raw = regular(path).lower()
            require(HOST.encode() not in raw and b"palco-player-release" not in raw,
                    "Conflito de hostname ou identificador no file provider.")
    return live / ROUTE, entries[0], next(iter(resolvers))


def route_bytes(sha, entry, resolver):
    tag = "palco-player-release"
    return (json.dumps({"http": {
        "routers": {tag: {"entryPoints":[entry], "rule":"Host(`" + HOST + "`)",
                          "service":tag, "tls":{"certResolver":resolver}}},
        "services": {tag: {"loadBalancer":{"servers":[{"url":"http://" + container_name(sha) + ":8080"}]}}}
    }}, indent=2) + "\n").encode()


def read_route(path, root):
    if not os.path.lexists(path):
        return None
    data = regular(path)
    try:
        obj = json.loads(data)
        server = obj["http"]["services"]["palco-player-release"]["loadBalancer"]["servers"][0]["url"]
        match = re.fullmatch(r"http://palco-player-([a-f0-9]{40}):8080", server)
        require(match, "URL de backend sem ownership.")
        sha = match[1]
        require(regular(root / sha / "route.json") == data,
                "Rota em producao diverge da revisao sob gerenciamento.")
        return sha
    except (KeyError, IndexError, TypeError, json.JSONDecodeError):
        raise ValueError("Rota preexistente sem ownership verificavel.")


def manifest_bytes(contents):
    return (json.dumps({p: digest(contents[p]) for p in FILES}, sort_keys=True) + "\n").encode()


def verified_assets(release):
    require(digest(regular(release / "default.conf", 16384)) == NGINX_CONF_SHA256,
            "Configuracao NGINX da release alterada desde o staging.")
    expected = json.loads(regular(release / "manifest.json", 1024))
    require(isinstance(expected, dict) and set(expected) == set(FILES) and
            all(isinstance(v, str) and re.fullmatch(r"[0-9a-f]{64}", v) for v in expected.values()),
            "Manifesto persistido incompleto/invalido.")
    for path in FILES:
        require(digest(regular(release / "site" / path)) == expected[path],
                "Alteracao no arquivo publicado desde o staging: " + path)
    return expected


def check_http(sha, site):
    expected = verified_assets(site.parent)
    name = container_name(sha)
    for delay in range(12):
        try:
            require(run("docker", "exec", name, "wget", "-qO-", "http://127.0.0.1:8080/healthz")
                    == b"ok\n", "Healthcheck interno divergente.")
            for path in FILES:
                got = run("docker", "exec", name, "wget", "-qO-", "http://127.0.0.1:8080/" + path)
                require(digest(got) == expected[path], "Resposta interna diverge: " + path)
            require(digest(run("docker", "exec", name, "wget", "-qO-", "http://127.0.0.1:8080/")) ==
                    expected["index.html"], "Resposta da raiz interna diverge.")
            return
        except ValueError:
            if delay == 11:
                raise
            time.sleep(1)


def stage(root, rel, sha, upload, desired):
    contents = get_payload(upload)
    config = regular(upload / "default.conf", 16384)
    require(digest(config) == NGINX_CONF_SHA256, "Configuracao NGINX diverge da revisao esperada.")
    if not rel.exists():
        with tempfile.TemporaryDirectory(dir=root) as tmp:
            candidate = Path(tmp) / sha
            site = candidate / "site"
            (site / "docs").mkdir(parents=True)
            for path, data in contents.items():
                (site / path).write_bytes(data)
                (site / path).chmod(0o644)
            site.chmod(0o755)
            (site / "docs").chmod(0o755)
            (candidate / "manifest.json").write_bytes(manifest_bytes(contents))
            (candidate / "default.conf").write_bytes(config)
            (candidate / "default.conf").chmod(0o644)
            (candidate / "route.json").write_bytes(desired)
            candidate.rename(rel)
    trusted_dir(rel)
    require(regular(rel / "default.conf") == config, "Configuracao NGINX alterada.")
    require(regular(rel / "route.json") == desired, "Configuracao da release mudou.")
    require(regular(rel / "manifest.json", 1024) == manifest_bytes(contents),
            "Manifesto de integridade alterado no mesmo SHA.")
    for path, data in contents.items():
        require(regular(rel / "site" / path) == data, "Artefato mudou no mesmo SHA.")
    item = container(sha)
    if not item:
        architecture = run("docker", "version", "--format", "{{.Server.Os}}/{{.Server.Arch}}").decode().strip()
        require(architecture == "linux/amd64", "O manifesto NGINX fixado requer Docker linux/amd64.")
        run("docker", "pull", IMAGE, timeout=240)
        run("docker", "run", "-d", "--name", container_name(sha), "--network", NETWORK,
            "--restart", "unless-stopped", "--user", "101:101", "--read-only",
            "--tmpfs", "/tmp:rw,noexec,nosuid,nodev,size=16m,mode=1777",
            "--cap-drop=ALL", "--security-opt=no-new-privileges", "--memory=64m",
            "--pids-limit=64", "--cpus=0.50",
            "--health-cmd", "wget -qO- http://127.0.0.1:8080/healthz | grep -qx ok",
            "--health-interval=30s", "--health-timeout=3s", "--health-retries=3", "--label", OWNER + "=" + sha, "--label", "traefik.enable=false",
            "--mount", f"type=bind,src={rel / 'site'},dst=/usr/share/nginx/html,readonly",
            "--mount", f"type=bind,src={rel / 'default.conf'},dst=/etc/nginx/conf.d/default.conf,readonly",
            IMAGE, "nginx", "-g", "daemon off;")
    else:
        require(item["State"]["Running"], "Container existente parado. Reconciliar antes de iniciar.")
    check_http(sha, rel / "site")


def execute():
    require(len(sys.argv) == 5, "Uso: stage|activate|rollback|status DIR SHA player.zani.ia.br")
    action, folder, sha, host = sys.argv[1:]
    require(action in ("stage", "activate", "rollback", "status") and SHA.fullmatch(sha)
            and host == HOST, "Acao, SHA ou hostname invalido.")
    root = Path.home() / ".local/share/palco-player-publication-v1"
    root.parent.mkdir(parents=True, exist_ok=True)
    try:
        root.mkdir(mode=0o700)
    except FileExistsError:
        pass
    trusted_dir(root)
    require(root.resolve() == root, "Armazenamento de release indireto.")
    lockfd = os.open(root / "release.lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(lockfd, "r+") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        # Only this account and its release history may operate on the managed route.
        route, entry, resolver = ingress()
        if action != "status":
            require(os.access(route.parent, os.W_OK | os.X_OK),
                    "A identidade SSH atual precisa de escrita/travessia no diretorio de rotas existente.")
        rel = root / sha
        current = read_route(route, root)
        desired = route_bytes(sha, entry, resolver)
        prevfile = rel / "previous"
        previous = None
        if prevfile.exists():
            saved = regular(prevfile, 64).decode()
            require(saved == "-" or SHA.fullmatch(saved), "Checkpoint anterior invalido.")
            previous = None if saved == "-" else saved
        if action == "stage":
            require(not (rel / "reverted").exists(), "Release revertida. Reconciliar a decisao.")
            stage(root, rel, sha, Path(folder), desired)
        elif action == "activate":
            require(container(sha) and not (rel / "reverted").exists(), "Canario indisponivel/revertido.")
            require(regular(rel / "route.json") == desired, "Preflight Traefik divergente.")
            require(regular(rel / "manifest.json", 1024) == manifest_bytes(get_payload(Path(folder))),
                    "Manifesto da release difere do pacote original da coordenacao.")
            check_http(sha, rel / "site")
            if current != sha:
                if not prevfile.exists():
                    previous = current
                    atomic(prevfile, (current or "-").encode(), replace=False)
                require(current == previous, "Rota mudou desde o checkpoint. Reconciliar.")
                require(read_route(route, root) == current, "Alteracao concorrente na rota.")
                atomic(route, desired, replace=current is not None)
            require(read_route(route, root) == sha, "Falha ao conferir a rota ativada.")
        elif action == "rollback":
            require(prevfile.exists(), "Sem checkpoint de ativacao. Nenhuma rota alterada.")
            if current == sha:
                if previous:
                    require(container(previous), "Backend anterior indisponivel.")
                    check_http(previous, root / previous / "site")
                    require(read_route(route, root) == sha, "Rota alterada durante rollback.")
                    atomic(route, regular(root / previous / "route.json"), replace=True)
                else:
                    require(read_route(route, root) == sha, "Rota alterada durante rollback.")
                    route.unlink()
            require(read_route(route, root) == previous, "Rota posterior nao pertence a esta operacao.")
            if not (rel / "reverted").exists():
                atomic(rel / "reverted", b"rollback\n", replace=False)
            candidate = container(sha)
            if candidate and candidate["State"]["Running"]:
                run("docker", "stop", container_name(sha))
        active = read_route(route, root)
        item = container(sha)
        print(json.dumps({"action":action, "release":sha, "active":active == sha,
                          "activeRelease":active, "staged":bool(item and item["State"]["Running"]),
                          "previous":previous}))


try:
    execute()
except (ValueError, OSError, RuntimeError, subprocess.TimeoutExpired, tarfile.TarError) as e:
    print("Publicacao interrompida: " + str(e), file=sys.stderr)
    sys.exit(1)
PY
