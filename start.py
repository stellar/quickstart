#!/usr/bin/env python3
"""Stellar Quickstart container entrypoint.

A 1:1 port of the original `start` bash script. It parses container
arguments, derives the network configuration, lays down and templates the
default service configuration, initializes Postgres/core/horizon/rpc/galexie/
friendbot as enabled, then launches supervisord and a set of background
watchers (network protocol/soroban upgrades, service status reporting and
optional log tailing).

Only the Python standard library is used so the container needs nothing more
than `python3`.
"""

import functools
import hashlib
import json
import os
import re
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from contextlib import contextmanager
from pathlib import Path

CLEAR = "\033[0m"
GREEN = "\033[32m"
BLUE = "\033[34m"
PURPLE = "\033[35m"
CYAN = "\033[36m"


def env_default(name, default):
    """Return the environment value for name, falling back to default when
    unset or empty (mirrors bash `: "${NAME:=default}"`)."""
    value = os.environ.get(name)
    return value if value else default


class Quickstart:
    def __init__(self):
        self.STELLAR_HOME = "/opt/stellar"
        self.PGHOME = f"{self.STELLAR_HOME}/postgresql"
        self.SUPHOME = f"{self.STELLAR_HOME}/supervisor"
        self.COREHOME = f"{self.STELLAR_HOME}/core"
        self.HZHOME = f"{self.STELLAR_HOME}/horizon"
        self.FBHOME = f"{self.STELLAR_HOME}/friendbot"
        self.LABHOME = f"{self.STELLAR_HOME}/lab"
        self.NXHOME = f"{self.STELLAR_HOME}/nginx"
        self.STELLAR_RPC_HOME = f"{self.STELLAR_HOME}/stellar-rpc"
        self.GALEXIEHOME = f"{self.STELLAR_HOME}/galexie"
        self.LEDGERMETASTOREHOME = f"{self.STELLAR_HOME}/ledger-meta-store"
        self.HISTORYARCHIVEHOME = f"{self.STELLAR_HOME}/history-archive"

        self.CORELOG = "/var/log/stellar-core"

        self.PGBIN = "/usr/lib/postgresql/14/bin/"
        self.PGDATA = f"{self.PGHOME}/data"
        self.PGUSER = "stellar"
        self.PGPORT = 5432

        with open("/image.json") as f:
            self.image = json.load(f)

        self.REVISION = os.environ.get("REVISION", "")
        self.PROTOCOL_VERSION_DEFAULT = str(self.image["config"]["protocol_version_default"])

        self.PROTOCOL_VERSION = env_default("PROTOCOL_VERSION", self.PROTOCOL_VERSION_DEFAULT)
        self.ENABLE = env_default("ENABLE", "core,horizon,rpc")
        self.ENABLE_LOGS = env_default("ENABLE_LOGS", "false")
        self.ENABLE_CORE = env_default("ENABLE_CORE", "false")
        self.ENABLE_HORIZON = env_default("ENABLE_HORIZON", "false")
        self.ENABLE_LAB = env_default("ENABLE_LAB", "false")
        self.ENABLE_GALEXIE = env_default("ENABLE_GALEXIE", "false")
        # TODO: Remove once the Soroban RPC name is fully deprecated
        self.ENABLE_SOROBAN_RPC = env_default("ENABLE_SOROBAN_RPC", "false")
        self.ENABLE_RPC = env_default("ENABLE_RPC", self.ENABLE_SOROBAN_RPC)
        self.ENABLE_SOROBAN_DIAGNOSTIC_EVENTS = env_default("ENABLE_SOROBAN_DIAGNOSTIC_EVENTS", "false")
        self.DISABLE_SOROBAN_DIAGNOSTIC_EVENTS = env_default("DISABLE_SOROBAN_DIAGNOSTIC_EVENTS", "false")
        # TODO: Remove once the Soroban RPC name is fully deprecated
        self.ENABLE_SOROBAN_RPC_ADMIN_ENDPOINT = env_default("ENABLE_SOROBAN_RPC_ADMIN_ENDPOINT", "false")
        self.ENABLE_RPC_ADMIN_ENDPOINT = env_default("ENABLE_RPC_ADMIN_ENDPOINT", self.ENABLE_SOROBAN_RPC_ADMIN_ENDPOINT)
        self.ENABLE_CORE_MANUAL_CLOSE = env_default("ENABLE_CORE_MANUAL_CLOSE", "false")
        self.CORE_LOG_LEVEL = env_default("CORE_LOG_LEVEL", "")
        self.CORE_USE_POSTGRES = env_default("CORE_USE_POSTGRES", "")
        self.LIMITS = env_default("LIMITS", "testnet")

        self.NETWORK = os.environ.get("NETWORK", "")
        self.NETWORK_PASSPHRASE = os.environ.get("NETWORK_PASSPHRASE", "")
        self.RANDOMIZE_NETWORK_PASSPHRASE = os.environ.get("RANDOMIZE_NETWORK_PASSPHRASE", "")
        self.ENABLE_ASSET_STATS = os.environ.get("ENABLE_ASSET_STATS", "")
        self.STELLAR_MODE = os.environ.get("STELLAR_MODE", "")
        self.POSTGRES_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "")

        self.NETWORK_ID = ""
        self.NETWORK_ROOT_SECRET_KEY = ""
        self.NETWORK_ROOT_ACCOUNT_ID = ""
        self.HISTORY_ARCHIVE_URLS = ""

        self.PGPASS = os.environ.get("PGPASS", "")
        self.CURRENT_POSTGRES_PID = None
        self._postgres_proc = None

        # When --logs is set, all of our own output and supervisord's output is
        # wrapped with a cyan "quickstart   | " prefix (matching the bash sed
        # process substitution).
        self.outer_prefix = ""

    # ------------------------------------------------------------------
    # output helpers
    # ------------------------------------------------------------------
    def log(self, msg=""):
        for line in str(msg).split("\n"):
            sys.stdout.write(f"{self.outer_prefix}{line}\n")
        sys.stdout.flush()

    def elog(self, msg=""):
        for line in str(msg).split("\n"):
            sys.stderr.write(f"{line}\n")
        sys.stderr.flush()

    # ------------------------------------------------------------------
    # subprocess helpers
    # ------------------------------------------------------------------
    def run(self, args, **kwargs):
        """Run a command, raising CalledProcessError on failure (set -e)."""
        kwargs.setdefault("check", True)
        return subprocess.run(args, **kwargs)

    def capture(self, args, ignore_error=False, input=None):
        """Run a command and return its stdout as text."""
        result = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=(subprocess.DEVNULL if ignore_error else None),
            input=input,
            text=True,
        )
        if result.returncode != 0 and not ignore_error:
            raise subprocess.CalledProcessError(result.returncode, args, result.stdout)
        return result.stdout

    def run_silent(self, label, args):
        """Run a command with abbreviated output provided it succeeds."""
        result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if result.returncode == 0:
            self.log(f"{label}: ok")
        else:
            self.log(f"{label}: failed!")
            self.log("")
            self.log(result.stdout)
            sys.exit(1)

    @contextmanager
    def chdir(self, path):
        prev = os.getcwd()
        os.chdir(path)
        try:
            yield
        finally:
            os.chdir(prev)

    def copy_tree(self, src, dst):
        """Equivalent to `rsync -a src dst`, preserving permissions/owners."""
        self.run(["rsync", "-a", src, dst])

    # ------------------------------------------------------------------
    # config templating
    # ------------------------------------------------------------------
    def template(self, path, replacements):
        text = Path(path).read_text()
        for placeholder, value in replacements.items():
            text = text.replace(placeholder, value)
        Path(path).write_text(text)

    def template_logged(self, label, path, replacements):
        try:
            self.template(path, replacements)
        except Exception as exc:  # pragma: no cover - mirrors run_silent failure
            self.log(f"{label}: failed!")
            self.log("")
            self.log(str(exc))
            sys.exit(1)
        self.log(f"{label}: ok")

    # ------------------------------------------------------------------
    # HTTP helpers
    # ------------------------------------------------------------------
    def http(self, url, data=None, headers=None, method=None, tolerate=False):
        req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
        try:
            with urllib.request.urlopen(req) as resp:
                return resp.read().decode()
        except (urllib.error.URLError, ConnectionError, OSError):
            if tolerate:
                return ""
            raise

    # ------------------------------------------------------------------
    # top level flow
    # ------------------------------------------------------------------
    def main(self, argv):
        self.process_args(argv)
        self.validate_before_start()
        self.start()

    def validate_before_start(self):
        if self.ENABLE_RPC != "true" and self.ENABLE_RPC_ADMIN_ENDPOINT == "true":
            self.elog("--enable-stellar-rpc-admin-endpoint usage only supported with --enable-stellar-rpc")
            sys.exit(1)
        if self.NETWORK != "local" and self.RANDOMIZE_NETWORK_PASSPHRASE == "true":
            self.elog("--randomize-network-passphrase is only supported in the local network")
            sys.exit(1)
        if self.NETWORK != "local" and self.ENABLE_GALEXIE == "true":
            self.elog("--enable galexie is only supported in the local network")
            sys.exit(1)
        if self.NETWORK == "local" and self.DISABLE_SOROBAN_DIAGNOSTIC_EVENTS == "false":
            self.ENABLE_SOROBAN_DIAGNOSTIC_EVENTS = "true"

    def validate_after_copy_defaults(self):
        if self.NETWORK == "local" and self.LIMITS != "default":
            config_dir = f"{self.COREHOME}/etc/config-settings/p{self.PROTOCOL_VERSION}"
            config_path = f"{config_dir}/{self.LIMITS}.json"
            if not os.path.isfile(config_path):
                options = " ".join(p.stem for p in sorted(Path(config_dir).glob("*")))
                self.log(f"--limits '{self.LIMITS}' unknown: must be one of: default {options}")
                sys.exit(1)

    def start(self):
        self.log("Starting Stellar Quickstart")

        self.log("versions:")
        self.log(f"  quickstart: {self.REVISION}")
        self.log("  xdr:")
        self.log(self._indent(self.capture(["stellar-xdr", "version"]), 4))
        self.log("  core:")
        self.log(self._indent(self.capture(["stellar-core", "version"], ignore_error=True), 4))
        self.log("  rpc:")
        self.log(self._indent(self.capture(["stellar-rpc", "version"]), 4))
        self.log("  horizon:")
        self.log(self._indent(self.capture(["stellar-horizon", "version"]), 4))
        self.log("  friendbot:")
        self.log(f"    {self._dep_ref('friendbot')}")
        self.log("  lab:")
        self.log(f"    {self._dep_ref('lab')}")
        self.log("  galexie:")
        self.log(f"    {self._dep_ref('galexie')}")

        self.log(f"mode: {self.STELLAR_MODE}")
        self.log(f"network: {self.NETWORK}")
        self.log(f"network passphrase: {self.NETWORK_PASSPHRASE}")
        self.log(f"network id: {self.NETWORK_ID}")
        self.log(f"network root secret key: {self.NETWORK_ROOT_SECRET_KEY}")
        self.log(f"network root account id: {self.NETWORK_ROOT_ACCOUNT_ID}")
        self.log(f"protocol version default: {self.PROTOCOL_VERSION_DEFAULT}")
        self.log(f"protocol version set: {self.PROTOCOL_VERSION}")

        self.copy_defaults()
        self.validate_after_copy_defaults()
        self.init_db()
        self.init_stellar_core()
        self.init_friendbot()
        self.init_horizon()
        self.copy_pgpass()
        self.init_stellar_rpc()
        self.init_galexie()

        self.stop_postgres()  # this gets started in init_db

        # launch services
        if self.ENABLE_LOGS == "true":
            self.outer_prefix = f"{CYAN}quickstart   | {CLEAR}"
            threading.Thread(target=self.print_service_logs, daemon=True).start()
            self.exec_supervisor()
        else:
            self.exec_supervisor()

    def _indent(self, text, spaces):
        prefix = " " * spaces
        return "\n".join(prefix + line for line in text.rstrip("\n").split("\n"))

    def _dep_ref(self, name):
        for dep in self.image.get("deps", []):
            if dep.get("name") == name:
                return f"{dep.get('ref')} ({dep.get('sha')})"
        return ""

    # ------------------------------------------------------------------
    # argument handling
    # ------------------------------------------------------------------
    def process_args(self, argv):
        args = list(argv)
        i = 0
        while i < len(args):
            arg = args[i]
            i += 1
            if arg == "--logs":
                self.ENABLE_LOGS = "true"
            elif arg == "--testnet":
                self.NETWORK = "testnet"
            elif arg == "--pubnet":
                self.NETWORK = "pubnet"
            elif arg == "--local":
                self.NETWORK = "local"
            elif arg == "--standalone":
                self.log("deprecated: option --standalone has been replaced by --local")
                self.NETWORK = "local"
            elif arg == "--futurenet":
                self.NETWORK = "futurenet"
            elif arg == "--protocol-version":
                self.PROTOCOL_VERSION = args[i]; i += 1
            elif arg == "--enable-asset-stats":
                self.ENABLE_ASSET_STATS = args[i]; i += 1
            elif arg == "--enable-lab":
                self.ENABLE_LAB = "true"
            elif arg == "--limits":
                self.LIMITS = args[i]; i += 1
            elif arg == "--enable":
                self.ENABLE = args[i]; i += 1
            # TODO: remove once the Soroban RPC name is fully deprecated
            elif arg == "--enable-soroban-rpc":
                self.ENABLE_RPC = "true"
            elif arg == "--enable-soroban-diagnostic-events":
                self.ENABLE_SOROBAN_DIAGNOSTIC_EVENTS = "true"
            elif arg == "--disable-soroban-diagnostic-events":
                self.DISABLE_SOROBAN_DIAGNOSTIC_EVENTS = "true"
            elif arg == "--enable-stellar-rpc-admin-endpoint":
                self.ENABLE_RPC_ADMIN_ENDPOINT = "true"
            # TODO: remove once the Soroban RPC name is fully deprecated
            elif arg == "--enable-soroban-rpc-admin-endpoint":
                self.ENABLE_RPC_ADMIN_ENDPOINT = "true"
            elif arg == "--enable-core-manual-close":
                self.ENABLE_CORE_MANUAL_CLOSE = "true"
            elif arg == "--randomize-network-passphrase":
                self.RANDOMIZE_NETWORK_PASSPHRASE = "true"
            elif arg == "--core-log-level":
                self.CORE_LOG_LEVEL = args[i]; i += 1
            else:
                self.elog(f"Unknown container arg {arg}")
                sys.exit(1)

        # TODO: ask for what network to use
        if not self.NETWORK:
            self.NETWORK = "testnet"

        enable_list = f",{self.ENABLE},"
        if ",core," in enable_list:
            self.ENABLE_CORE = "true"
        if ",horizon," in enable_list:
            self.ENABLE_HORIZON = "true"
        if ",rpc," in enable_list:
            self.ENABLE_RPC = "true"
        if ",lab," in enable_list:
            self.ENABLE_LAB = "true"
        if ",galexie," in enable_list:
            self.ENABLE_GALEXIE = "true"

        if self.NETWORK == "testnet":
            self.NETWORK_PASSPHRASE = "Test SDF Network ; September 2015"
            self.HISTORY_ARCHIVE_URLS = "https://history.stellar.org/prd/core-testnet/core_testnet_001"
        elif self.NETWORK == "pubnet":
            self.NETWORK_PASSPHRASE = "Public Global Stellar Network ; September 2015"
            self.HISTORY_ARCHIVE_URLS = "https://history.stellar.org/prd/core-live/core_live_001"
        elif self.NETWORK == "local":
            if not self.NETWORK_PASSPHRASE:
                self.NETWORK_PASSPHRASE = "Standalone Network ; February 2017"
            # h1570ry - we'll start a webserver connected to history directory later on
            self.HISTORY_ARCHIVE_URLS = "http://localhost:1570"
            self.ENABLE_CORE = "true"
        elif self.NETWORK == "futurenet":
            self.NETWORK_PASSPHRASE = "Test SDF Future Network ; October 2022"
            self.HISTORY_ARCHIVE_URLS = "http://history.stellar.org/dev/core-futurenet/core_futurenet_001"
        else:
            self.elog(f"Unknown network: '{self.NETWORK}'")
            sys.exit(1)

        if self.RANDOMIZE_NETWORK_PASSPHRASE == "true":
            self.NETWORK_PASSPHRASE = f"{self.NETWORK_PASSPHRASE} ; {secrets.token_hex(32)}"

        self.NETWORK_ID = hashlib.sha256(self.NETWORK_PASSPHRASE.encode()).hexdigest()
        network_id_keys = self._convert_id(self.NETWORK_ID)
        self.NETWORK_ROOT_SECRET_KEY = network_id_keys[0]
        self.NETWORK_ROOT_ACCOUNT_ID = network_id_keys[1]

        # Are we ephemeral or persistent?
        if not self.STELLAR_MODE:
            if os.path.isfile("/opt/stellar/.docker-ephemeral"):
                self.STELLAR_MODE = "ephemeral"
            else:
                self.STELLAR_MODE = "persistent"

    def _convert_id(self, network_id):
        out = self.capture(["stellar-core", "convert-id", network_id])
        keys = [line.split(": ", 1)[1] for line in out.splitlines() if "strKey: " in line]
        return keys[-2:]

    # ------------------------------------------------------------------
    # postgres password
    # ------------------------------------------------------------------
    def set_pg_password(self):
        if self.POSTGRES_PASSWORD:
            self.PGPASS = self.POSTGRES_PASSWORD
            self.log("using POSTGRES_PASSWORD")
            return

        # use a random password when ephemeral (or some other unknown mode)
        if self.STELLAR_MODE != "persistent":
            alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            self.PGPASS = "".join(secrets.choice(alphabet) for _ in range(16))
            self.log(f"postgres password: {self.PGPASS}")
            return

        if self.PGPASS:
            self.log(f"postgres password: {self.PGPASS}")
            return

        # ask for a password when persistent
        try:
            import getpass
            self.PGPASS = getpass.getpass("Enter New Postgresql Password: ")
            confirmation = getpass.getpass("Confirm: ")
        except (EOFError, KeyboardInterrupt):
            self.log("Postgresql password not supplied. Set the POSTGRES_PASSWORD environment variable, "
                     "or run the container interactively and provide the password via stdin.")
            sys.exit(1)

        if not self.PGPASS:
            self.elog("Password empty")
            sys.exit(1)

        if self.PGPASS != confirmation:
            self.elog("Password mistmach")
            sys.exit(1)

    # ------------------------------------------------------------------
    # copy defaults
    # ------------------------------------------------------------------
    def copy_defaults(self):
        default = "/opt/stellar-default"

        if os.path.isdir(f"{self.PGHOME}/etc"):
            self.log("postgres: config directory exists, skipping copy")
        else:
            self.copy_tree(f"{default}/common/postgresql/", self.PGHOME)

        if os.path.isdir(f"{self.SUPHOME}/etc"):
            self.log("supervisor: config directory exists, skipping copy")
        else:
            self.copy_tree(f"{default}/common/supervisor/", self.SUPHOME)
            dest = f"{self.SUPHOME}/etc/supervisord.conf.d"
            for conf in ("stellar-rpc.conf", "galexie.conf", "ledger-meta-store.conf",
                         "friendbot.conf", "history-archive.conf"):
                src = f"{default}/{self.NETWORK}/supervisor/etc/supervisord.conf.d/{conf}"
                if os.path.isfile(src):
                    shutil.copy(src, dest)

        if os.path.isdir(f"{self.COREHOME}/etc"):
            self.log("stellar-core: config directory exists, skipping copy")
        else:
            self.copy_tree(f"{default}/common/core/", self.COREHOME)
            self.copy_tree(f"{default}/{self.NETWORK}/core/", self.COREHOME)
            if self.NETWORK == "local":
                # If there are no config settings for the current network, use the
                # config settings from the most recent protocol.
                config_dir_base = f"{self.COREHOME}/etc/config-settings"
                config_dir = f"{config_dir_base}/p{self.PROTOCOL_VERSION}"
                if not os.path.isdir(config_dir):
                    # Symlink the config-dir from the most recent protocol
                    # version. For example, if PROTOCOL_VERSION is 25, and there
                    # is no config settings for p25, look for config settings for
                    # p24, p23, so on until the directory exists. Protocol 20 is
                    # the first protocol that has settings. Once the directory
                    # exists, create a symlink for p25 -> p23.
                    for v in range(int(self.PROTOCOL_VERSION) - 1, 19, -1):
                        v_dir = f"p{v}"
                        fallback_dir = f"{config_dir_base}/{v_dir}"
                        if os.path.isdir(fallback_dir):
                            self._force_symlink(v_dir, config_dir)
                            break

        self._copy_common_and_network("horizon", self.HZHOME)
        self._copy_common_and_network("stellar-rpc", self.STELLAR_RPC_HOME)
        self._copy_common_and_network("friendbot", self.FBHOME)
        self._copy_common_and_network("nginx", self.NXHOME)
        self._copy_common_and_network("galexie", self.GALEXIEHOME)

    def _copy_common_and_network(self, name, home):
        default = "/opt/stellar-default"
        if os.path.isdir(f"{home}/etc"):
            self.log(f"{name}: config directory exists, skipping copy")
        else:
            self.copy_tree(f"{default}/common/{name}/", home)
            network_dir = f"{default}/{self.NETWORK}/{name}/"
            if os.path.isdir(network_dir):
                self.copy_tree(network_dir, home)

    def _force_symlink(self, target, link_name):
        if os.path.islink(link_name) or os.path.exists(link_name):
            os.remove(link_name)
        os.symlink(target, link_name)

    def copy_pgpass(self):
        self.copy_tree("/opt/stellar/postgresql/.pgpass", "/root/")
        os.chmod("/root/.pgpass", 0o600)

        self.copy_tree("/opt/stellar/postgresql/.pgpass", "/var/lib/stellar")
        os.chmod("/var/lib/stellar/.pgpass", 0o600)
        self.run(["chown", "stellar:stellar", "/var/lib/stellar/.pgpass"])

    # ------------------------------------------------------------------
    # database
    # ------------------------------------------------------------------
    def init_db(self):
        # Need postgres if horizon is enabled, or if core is enabled and using postgres
        if self.ENABLE_HORIZON != "true" and (self.ENABLE_CORE != "true" or self.CORE_USE_POSTGRES != "true"):
            return
        if os.path.isfile(f"{self.PGHOME}/.quickstart-initialized"):
            self.log("postgres: already initialized")
            return

        with self.chdir(self.PGHOME):
            # workaround!!!! from: https://github.com/nimiq/docker-postgresql93/issues/2
            self.run(
                "mkdir /etc/ssl/private-copy; mv /etc/ssl/private/* /etc/ssl/private-copy/; "
                "rm -r /etc/ssl/private; mv /etc/ssl/private-copy /etc/ssl/private; "
                "chmod -R 0700 /etc/ssl/private; chown -R postgres /etc/ssl/private",
                shell=True,
            )
            # end workaround

            self.log(f"postgres user: {self.PGUSER}")

            self.set_pg_password()

            self.template("/opt/stellar/postgresql/.pgpass", {"__PGPASS__": self.PGPASS})
            self.log("finalize-pgpass: ok")

            os.makedirs(self.PGDATA, exist_ok=True)
            self.run(["chown", "postgres:postgres", self.PGDATA])
            os.chmod(self.PGDATA, 0o700)

            # Create /var/run/postgresql because we are starting postgres
            # manually, it is our responsibility to make sure the directory
            # exists for where the process files and unix socket will live.
            os.makedirs("/var/run/postgresql", exist_ok=True)
            self.run(["chown", "postgres:postgres", "/var/run/postgresql"])

            self.run_silent("init-postgres", ["sudo", "-u", "postgres", f"{self.PGBIN}/initdb", "-D", self.PGDATA])

            self.start_postgres()
            if self.ENABLE_HORIZON == "true":
                self.run_silent("create-horizon-db", ["sudo", "-u", "postgres", "createdb", "horizon"])
            if self.ENABLE_CORE == "true" and self.CORE_USE_POSTGRES == "true":
                self.run_silent("create-core-db", ["sudo", "-u", "postgres", "createdb", "core"])

            sql = [f"CREATE USER {self.PGUSER} WITH PASSWORD '{self.PGPASS}';"]
            if self.ENABLE_HORIZON == "true":
                sql.append(f"GRANT ALL PRIVILEGES ON DATABASE horizon to {self.PGUSER};")
            if self.ENABLE_CORE == "true" and self.CORE_USE_POSTGRES == "true":
                sql.append(f"GRANT ALL PRIVILEGES ON DATABASE core to {self.PGUSER};")
            self._run_silent_input("stellar-postgres-user", ["sudo", "-u", "postgres", "psql"], "\n".join(sql) + "\n")

            Path(".quickstart-initialized").touch()

    def _run_silent_input(self, label, args, stdin_text):
        result = subprocess.run(args, input=stdin_text, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True)
        if result.returncode == 0:
            self.log(f"{label}: ok")
        else:
            self.log(f"{label}: failed!")
            self.log("")
            self.log(result.stdout)
            sys.exit(1)

    # ------------------------------------------------------------------
    # stellar-core
    # ------------------------------------------------------------------
    def init_stellar_core(self):
        if self.ENABLE_CORE != "true":
            return

        self.run_silent("mkdir-core-log", ["mkdir", "-p", self.CORELOG])
        self.run_silent("chown-core-log", ["chown", "-R", "stellar:stellar", self.CORELOG])

        with self.chdir(self.COREHOME):
            self.run_silent("chown-core", ["chown", "-R", "stellar:stellar", "."])

            # Write core environment file for runtime configuration. This runs on
            # every startup to support changing settings on restart. Default to
            # "debug" for local network to maintain backward compatibility.
            core_log_level = self.CORE_LOG_LEVEL
            if not core_log_level and self.NETWORK == "local":
                core_log_level = "debug"
            Path(f"{self.COREHOME}/etc/env").write_text(
                f'CORE_LOG_LEVEL="{core_log_level}"\n'
                f'CORE_USE_POSTGRES="{self.CORE_USE_POSTGRES}"\n'
            )

            if os.path.isfile(f"{self.COREHOME}/.quickstart-initialized"):
                self.log("core: already initialized")
                if self.NETWORK == "local":
                    self.run_silent("init-core-scp", ["sudo", "-u", "stellar", "stellar-core",
                                                      "force-scp", "--conf", f"{self.COREHOME}/etc/stellar-core.cfg"])
                return

            self.template("etc/stellar-core.cfg", {"__NETWORK__": self.NETWORK_PASSPHRASE})

            self.template("etc/stellar-core.cfg", {"__MANUAL_CLOSE__": self.ENABLE_CORE_MANUAL_CLOSE})
            self.log("finalize-core-config-manual-close: ok")

            # Set database based on CORE_USE_POSTGRES environment variable
            if self.CORE_USE_POSTGRES == "true":
                database_url = f"postgresql://dbname=core host=localhost user=stellar password={self.PGPASS}"
                self.start_postgres()
            else:
                database_url = "sqlite3:///opt/stellar/core/stellar.db"
            self.template("etc/stellar-core.cfg", {"__DATABASE__": database_url})
            self.log("finalize-core-config-database: ok")

            self.run_silent("init-core-db", ["sudo", "-u", "stellar", "stellar-core", "new-db", "--conf", "etc/stellar-core.cfg"])

            if self.NETWORK == "local":
                self.run_silent("init-core-scp", ["sudo", "-u", "stellar", "stellar-core", "force-scp", "--conf", "etc/stellar-core.cfg"])

                self.run_silent("mkdir-history-archive", ["mkdir", "-p", f"{self.HISTORYARCHIVEHOME}/data"])
                self.run_silent("chown-history-archive", ["chown", "-R", "stellar:stellar", self.HISTORYARCHIVEHOME])
                self.run_silent("init-history", ["sudo", "-u", "stellar", "stellar-core", "new-hist", "vs", "--conf", f"{self.COREHOME}/etc/stellar-core.cfg"])

            Path(".quickstart-initialized").touch()

    # ------------------------------------------------------------------
    # friendbot
    # ------------------------------------------------------------------
    def init_friendbot(self):
        if os.path.isfile(f"{self.FBHOME}/.quickstart-initialized"):
            self.log("friendbot: already initialized")
            return

        with self.chdir(self.FBHOME):
            self.template("etc/friendbot.cfg", {
                "__NETWORK__": self.NETWORK_PASSPHRASE,
                "__NETWORK_ROOT_SECRET_KEY__": self.NETWORK_ROOT_SECRET_KEY,
            })

            if self.ENABLE_RPC == "true":
                with open("etc/friendbot.cfg", "a") as f:
                    f.write('rpc_url = "http://localhost:8003"\n')
                    f.write('fund_contract_addresses = true\n')
            elif self.ENABLE_HORIZON == "true":
                with open("etc/friendbot.cfg", "a") as f:
                    f.write('horizon_url = "http://localhost:8001"\n')

            Path(".quickstart-initialized").touch()

    # ------------------------------------------------------------------
    # horizon
    # ------------------------------------------------------------------
    def init_horizon(self):
        if self.ENABLE_HORIZON != "true":
            return

        if os.path.isfile(f"{self.HZHOME}/.quickstart-initialized"):
            self.log("horizon: already initialized")
            return

        with self.chdir(self.HZHOME):
            os.mkdir("./captive-core")
            self.template("etc/horizon.env", {
                "__PGPASS__": self.PGPASS,
                "__NETWORK__": self.NETWORK_PASSPHRASE,
                "__ARCHIVE__": self.HISTORY_ARCHIVE_URLS,
            })

            captive_core_cfg = f"{self.HZHOME}/etc/stellar-captive-core.cfg"
            self.template(captive_core_cfg, {"__DATABASE__": f"sqlite3://{self.HZHOME}/captive-core/stellar.db"})
            self.log("finalize-horizon-captivecore-db: ok")
            self.template(captive_core_cfg, {"__NETWORK__": self.NETWORK_PASSPHRASE})
            self.template(captive_core_cfg, {"__ENABLE_SOROBAN_DIAGNOSTIC_EVENTS__": self.ENABLE_SOROBAN_DIAGNOSTIC_EVENTS})
            self.log("finalize-horizon-captivecore-config-enable-soroban-diagnostic-events: ok")

            skip_check = "True" if self.image.get("config", {}).get("horizon_skip_protocol_version_check") is True else ""
            with open("etc/horizon.env", "a") as f:
                f.write(f"export CAPTIVE_CORE_CONFIG_PATH={captive_core_cfg}\n")
                f.write(f"export CAPTIVE_CORE_STORAGE_PATH={self.HZHOME}/captive-core\n")
                core_version = self.capture(["stellar-core", "version"], ignore_error=True).split("\n")[0]
                f.write(f'export STELLAR_CORE_VERSION="{core_version}"\n')
                f.write(f"export INGEST_SKIP_PROTOCOL_VERSION_CHECK={skip_check}\n")

            self.run_silent("chown-horizon", ["chown", "-R", "stellar:stellar", "."])

            self.start_postgres()
            self.run_silent("init-horizon-db", ["sudo", "-u", "stellar", "./bin/horizon", "db", "init"])
            Path(".quickstart-initialized").touch()

    # ------------------------------------------------------------------
    # stellar-rpc
    # ------------------------------------------------------------------
    def init_stellar_rpc(self):
        if self.ENABLE_RPC != "true":
            return

        if os.path.isfile(f"{self.STELLAR_RPC_HOME}/.quickstart-initialized"):
            self.log("stellar rpc: already initialized")
            return

        with self.chdir(self.STELLAR_RPC_HOME):
            os.mkdir("./captive-core")

            captive_core_cfg = f"{self.STELLAR_RPC_HOME}/etc/stellar-captive-core.cfg"
            self.template(captive_core_cfg, {"__DATABASE__": f"sqlite3://{self.STELLAR_RPC_HOME}/captive-core/stellar-rpc.db"})
            self.log("finalize-stellar-rpc-captivecore-db: ok")
            self.template(captive_core_cfg, {"__NETWORK__": self.NETWORK_PASSPHRASE})
            self.template(captive_core_cfg, {"__ENABLE_SOROBAN_DIAGNOSTIC_EVENTS__": self.ENABLE_SOROBAN_DIAGNOSTIC_EVENTS})
            self.log("finalize-stellar-rpc-captivecore-config-enable-soroban-diagnostic-events: ok")

            admin_endpoint = "0.0.0.0:6061"
            if self.ENABLE_RPC_ADMIN_ENDPOINT != "true":
                admin_endpoint = ""

            self.template("etc/stellar-rpc.cfg", {
                "__STELLAR_RPC_ADMIN_ENDPOINT__": admin_endpoint,
                "__NETWORK__": self.NETWORK_PASSPHRASE,
                "__ARCHIVE__": self.HISTORY_ARCHIVE_URLS,
            })

            self.run_silent("init-stellar-rpc", ["chown", "-R", "stellar:stellar", "."])

            Path(".quickstart-initialized").touch()

    # ------------------------------------------------------------------
    # galexie
    # ------------------------------------------------------------------
    def init_galexie(self):
        if self.ENABLE_GALEXIE != "true":
            return

        if os.path.isfile(f"{self.GALEXIEHOME}/.quickstart-initialized"):
            self.log("galexie: already initialized")
            return

        self.run_silent("mkdir-ledger-meta-store", ["mkdir", "-p", f"{self.LEDGERMETASTOREHOME}/data"])
        self.run_silent("chown-ledger-meta-store", ["chown", "-R", "stellar:stellar", self.LEDGERMETASTOREHOME])

        with self.chdir(self.GALEXIEHOME):
            os.mkdir("./captive-core")

            captive_core_cfg = f"{self.GALEXIEHOME}/etc/stellar-captive-core.cfg"
            self.template(captive_core_cfg, {"__DATABASE__": f"{self.GALEXIEHOME}/captive-core/galexie.db"})
            self.log("finalize-galexie-captivecore-db: ok")
            self.template("etc/galexie.toml", {"__NETWORK__": self.NETWORK_PASSPHRASE})
            self.template("etc/stellar-captive-core.cfg", {"__NETWORK__": self.NETWORK_PASSPHRASE})

            self.run_silent("init-galexie", ["chown", "-R", "stellar:stellar", "."])

            Path(".quickstart-initialized").touch()

    # ------------------------------------------------------------------
    # supervisor and runtime watchers
    # ------------------------------------------------------------------
    def kill_supervisor(self):
        pid = int(Path("/var/run/supervisord.pid").read_text().strip())
        os.kill(pid, signal.SIGQUIT)

    def fail_soroban_config_upgrade(self, message):
        self.log(f"!!!!! {message}. Stopping all services. !!!!!")
        self.kill_supervisor()
        raise RuntimeError(message)

    def get_ledger_transaction_count(self):
        body = self.http("http://localhost:11626/metrics", tolerate=True)
        try:
            return int(json.loads(body)["metrics"]["ledger.transaction.count"]["count"])
        except (ValueError, KeyError, TypeError):
            return 0

    def wait_for_ledger_transaction_count(self, target):
        while self.get_ledger_transaction_count() < target:
            time.sleep(1)

    def submit_soroban_config_tx(self, label, tx, txid):
        attempt = 1
        max_attempts = 30
        while True:
            query = urllib.parse.urlencode({"blob": tx})
            response = self.http(f"http://localhost:11626/tx?{query}", tolerate=True)
            try:
                status = json.loads(response).get("status")
            except ValueError:
                status = None

            self.log(f"upgrades: soroban config: {label}: {txid} .. {status}")

            if status in ("PENDING", "DUPLICATE"):
                return
            elif status == "TRY_AGAIN_LATER":
                if attempt >= max_attempts:
                    self.log(response)
                    self.fail_soroban_config_upgrade(
                        f"Unable to submit Soroban config transaction '{label}' after {attempt} attempts")
                attempt += 1
                time.sleep(1)
            elif status in ("ERROR", "FILTERED"):
                self.log(response)
                self.fail_soroban_config_upgrade(f"Unable to submit Soroban config transaction '{label}'")
            else:
                self.log(response)
                self.fail_soroban_config_upgrade(
                    f"Unexpected status '{status}' while submitting Soroban config transaction '{label}'")

    def apply_soroban_config_tx(self, label, tx, txid, expected_tx_count):
        self.submit_soroban_config_tx(label, tx, txid)
        self.wait_for_ledger_transaction_count(expected_tx_count)

    def set_soroban_config_upgrade(self, key):
        attempt = 1
        max_attempts = 10
        while True:
            query = urllib.parse.urlencode({
                "mode": "set",
                "upgradetime": "1970-01-01T00:00:00Z",
                "configupgradesetkey": key,
            })
            output = self.http(f"http://localhost:11626/upgrades?{query}", tolerate=True)
            self.log(output)

            if output != "Error setting configUpgradeSet":
                return

            if attempt >= max_attempts:
                self.fail_soroban_config_upgrade("Unable to upgrade Soroban Config Settings")

            attempt += 1
            time.sleep(1)

    def upgrade_soroban_config(self, config_file_path, seq_num):
        # Generate txs for installing, deploying and executing the contract that
        # uploads a new config. Use the network root account to submit the txs.
        xdr = self.capture(["stellar-xdr", "encode", "--type", "ConfigUpgradeSet"],
                           input=Path(config_file_path).read_text())
        upgrade_output = self.capture(
            ["stellar-core", "get-settings-upgrade-txs",
             self.NETWORK_ROOT_ACCOUNT_ID, str(seq_num), self.NETWORK_PASSPHRASE,
             "--xdr", xdr, "--signtxs"],
            input=self.NETWORK_ROOT_SECRET_KEY,
        )

        lines = upgrade_output.split("\n")
        # strip a single trailing empty line (output ends with a newline)
        if lines and lines[-1] == "":
            lines = lines[:-1]
        line_count = len(lines)

        if line_count not in (7, 9):
            self.log(upgrade_output)
            self.fail_soroban_config_upgrade("Unexpected output from stellar-core get-settings-upgrade-txs")

        it = iter(lines)
        expected_tx_count = self.get_ledger_transaction_count() + 1

        # If 9 lines are returned instead of 7, core included a restore transaction.
        if line_count == 9:
            tx = next(it)
            txid = next(it)
            self.apply_soroban_config_tx("restore contract", tx, txid, expected_tx_count)
            expected_tx_count += 1

        tx = next(it); txid = next(it)
        self.apply_soroban_config_tx("install contract", tx, txid, expected_tx_count)
        expected_tx_count += 1

        tx = next(it); txid = next(it)
        self.apply_soroban_config_tx("deploy contract", tx, txid, expected_tx_count)
        expected_tx_count += 1

        tx = next(it); txid = next(it)
        self.apply_soroban_config_tx("upload config", tx, txid, expected_tx_count)

        key = next(it)
        self.log(f"upgrades: soroban config: set config with key: {key}")
        self.set_soroban_config_upgrade(key)

        self.log("upgrades: soroban config done")

    def upgrade_local(self):
        if self.NETWORK != "local":
            return

        # Wait for server
        while not self._port_open("localhost", 11626):
            time.sleep(1)

        if self.PROTOCOL_VERSION == "none":
            return

        protocol_version = int(self.PROTOCOL_VERSION)

        # Upgrade local network's protocol version and base reserve to match pubnet/testnet
        if protocol_version > 0:
            self.log(f"upgrades: protocolversion={protocol_version}, basereserve=5000000")
            query = urllib.parse.urlencode({
                "mode": "set",
                "upgradetime": "1970-01-01T00:00:00Z",
                "protocolversion": protocol_version,
                "basereserve": 5000000,
            })
            self.http(f"http://localhost:11626/upgrades?{query}", tolerate=True)
            while True:
                info = self.http("http://localhost:11626/info", tolerate=True)
                try:
                    version = json.loads(info)["info"]["ledger"]["version"]
                except (ValueError, KeyError, TypeError):
                    version = None
                if str(version) == str(protocol_version):
                    break
                time.sleep(1)
            self.log("upgrades: protocolversion done")

        # Upgrade local network's soroban config to match testnet, unless the
        # limits have been configured with 'default', which will cause the limits
        # to be left in their default state.
        if protocol_version >= 20 and self.LIMITS != "default":
            # Skip if already upgraded because these commands can only be run at
            # the start of the network when the root account has sourced no other
            # transactions.
            if os.path.isfile(f"{self.COREHOME}/.upgrade-config-initialized"):
                self.log("upgrades: soroban config already applied, skipping")
            else:
                # First upgrade with the settings_enable_upgrades.json file to
                # enable the upcoming, larger upgrade.
                self.upgrade_soroban_config(f"{self.COREHOME}/etc/config-settings/settings_enable_upgrades.json", 0)

                self.log(f"upgrades: soroban config '{self.LIMITS}' limits")

                # Then upgrade with the existing protocol version specific file.
                # Pass the expected sequence number of the root account after the
                # first call to upgrade_soroban_config.
                self.upgrade_soroban_config(
                    f"{self.COREHOME}/etc/config-settings/p{self.PROTOCOL_VERSION}/{self.LIMITS}.json", 4)

                Path(f"{self.COREHOME}/.upgrade-config-initialized").touch()

        # Start friendbot once network upgrades are complete and network is ready.
        # Note that friendbot and the config upgrade txs above use the same
        # account to submit txs. while friendbot is not dependent on the config
        # upgrade txs, it must not be started until the config upgrades are
        # complete otherwise the txs sequence numbers will conflict.
        if self.ENABLE_HORIZON == "true" or self.ENABLE_RPC == "true":
            self.run(["supervisorctl", "start", "friendbot"])

    def _port_open(self, host, port):
        try:
            with socket.create_connection((host, port), timeout=1):
                return True
        except OSError:
            return False

    def start_optional_services(self):
        # supervisorctl exits 4 when it cannot connect to supervisord yet.
        while subprocess.run(["supervisorctl", "status"], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL).returncode == 4:
            time.sleep(1)

        if self.ENABLE_CORE == "true":
            if self.CORE_USE_POSTGRES == "true":
                self.run(["supervisorctl", "start", "postgresql"])
            self.run(["supervisorctl", "start", "stellar-core"])

        if self.ENABLE_HORIZON == "true":
            self.run(["supervisorctl", "start", "postgresql"])
            self.run(["supervisorctl", "start", "horizon"])

        if self.ENABLE_RPC == "true":
            self.run(["supervisorctl", "start", "stellar-rpc"])

        if self.ENABLE_LAB == "true":
            self.run(["supervisorctl", "start", "stellar-lab"])

        if self.ENABLE_GALEXIE == "true":
            self.run(["supervisorctl", "start", "ledger-meta-store"])
            self.run(["supervisorctl", "start", "galexie"])

    def _guard(self, fn):
        """Run a watcher; on failure tear down supervisord (bash trap ... ERR)."""
        def wrapper():
            try:
                fn()
            except Exception:
                try:
                    self.kill_supervisor()
                except Exception:
                    pass
        return wrapper

    def exec_supervisor(self):
        self.log("supervisor: starting")

        threading.Thread(target=self._guard(self.upgrade_local), daemon=True).start()
        threading.Thread(target=self.service_status, daemon=True).start()
        threading.Thread(target=self.start_optional_services, daemon=True).start()

        # Run supervisord in a new environment (empty env) because supervisord
        # inherits the env vars of its environment for all subprocesses that get
        # started. This is problematic for services that use the same environment
        # variable name for things that the start script does, like NETWORK.
        supervisord = shutil.which("supervisord")
        proc = subprocess.Popen(
            [supervisord, "-n", "-c", f"{self.SUPHOME}/etc/supervisord.conf"],
            env={},
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )

        def forward(signum, _frame):
            proc.send_signal(signum)

        for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGQUIT):
            signal.signal(sig, forward)

        out = threading.Thread(target=self._pump, args=(proc.stdout, sys.stdout, "supervisor: "), daemon=True)
        err = threading.Thread(target=self._pump, args=(proc.stderr, sys.stderr, "supervisor: "), daemon=True)
        out.start()
        err.start()

        returncode = proc.wait()
        out.join()
        err.join()
        sys.exit(returncode)

    def _pump(self, src, dst, inner_prefix):
        for line in iter(src.readline, ""):
            dst.write(f"{self.outer_prefix}{inner_prefix}{line.rstrip(chr(10))}\n")
            dst.flush()

    def print_service_logs(self):
        # Wait for supervisord to be up.
        while subprocess.run(["supervisorctl", "pid"], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL).returncode != 0:
            time.sleep(1)
        # Start tailing logs from notable services.
        if self.ENABLE_CORE == "true":
            self._tail_service("stellar-core", "stdout", PURPLE, "stellar-core | ", sys.stdout)
            self._tail_service("stellar-core", "stderr", PURPLE, "stellar-core | ", sys.stderr)
        if self.ENABLE_HORIZON == "true":
            self._tail_service("horizon", "stdout", GREEN, "horizon      | ", sys.stdout)
        if self.ENABLE_RPC == "true":
            self._tail_service("stellar-rpc", "stdout", BLUE, "stellar-rpc  | ", sys.stdout)

    def _tail_service(self, service, stream, color, label, dst):
        prefix = f"{color}{label}{CLEAR}"
        proc = subprocess.Popen(["supervisorctl", "tail", "-f", service, stream],
                                stdout=subprocess.PIPE, text=True, bufsize=1)

        def pump():
            for line in iter(proc.stdout.readline, ""):
                dst.write(f"{prefix}{line.rstrip(chr(10))}\n")
                dst.flush()

        threading.Thread(target=pump, daemon=True).start()

    # ------------------------------------------------------------------
    # postgres lifecycle
    # ------------------------------------------------------------------
    def start_postgres(self):
        if self.CURRENT_POSTGRES_PID is not None:
            return

        # Check that postgres can start and load the data successfully. If it
        # can't successfully do this, then something is in a bad state. For
        # example, a newer persistent volume may be mounted with postgres data
        # which is incompatible with the version of postgres in the container.
        # Log any errors from postgres to help the operator debug the situation.
        check = subprocess.run(
            ["sudo", "-u", "postgres", "sh", "-c",
             f"echo -n | {self.PGBIN}/postgres --single -E -D {self.PGDATA} "
             f"-c config_file={self.PGHOME}/etc/postgresql.conf"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        )
        if check.returncode != 0:
            for line in check.stdout.split("\n"):
                self.log(f"postgres: {line}")
            sys.exit(1)

        proc = subprocess.Popen(
            ["sudo", "-u", "postgres", f"{self.PGBIN}/postgres", "-D", self.PGDATA,
             "-c", f"config_file={self.PGHOME}/etc/postgresql.conf"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        self._postgres_proc = proc
        self.CURRENT_POSTGRES_PID = proc.pid

        while subprocess.run(["sudo", "-u", "postgres", "psql", "-c", "select 1"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
            self.log("Waiting for postgres to be available...")
            time.sleep(1)

        self.log("postgres: up")

    def stop_postgres(self):
        if self.CURRENT_POSTGRES_PID is None:
            return

        subprocess.run(["killall", "postgres"])
        # wait for postgres to die (poll() also reaps the child so it does not
        # linger as a zombie)
        while self._postgres_proc.poll() is None:
            time.sleep(0.5)
        self.log("postgres: down")

    # ------------------------------------------------------------------
    # service status watchers
    # ------------------------------------------------------------------
    def service_status(self):
        if self.ENABLE_CORE == "true":
            threading.Thread(target=self.stellar_core_status, args=("node", 11626), daemon=True).start()
        if self.ENABLE_HORIZON == "true":
            threading.Thread(target=self.stellar_core_status, args=("horizon", 11726), daemon=True).start()
            threading.Thread(target=self.horizon_status, daemon=True).start()
        if self.ENABLE_RPC == "true":
            threading.Thread(target=self.stellar_core_status, args=("rpc", 11826), daemon=True).start()
            threading.Thread(target=self.stellar_rpc_status, daemon=True).start()

    def stellar_core_status(self, name, port):
        last_status = ""
        while True:
            body = self.http(f"http://localhost:{port}/info", tolerate=True)
            try:
                info = json.loads(body)["info"]
                parts = [info["state"]] + (info.get("status") or [])
                status = "; ".join(parts)
            except (ValueError, KeyError, TypeError):
                status = ""
            if status != last_status:
                self.log(f"stellar-core({name}): {status}")
            last_status = status
            time.sleep(1)

    def stellar_rpc_status(self):
        self.log("stellar-rpc: waiting for ready state...")
        counter = 1
        while True:
            body = self.http(
                "http://localhost:8003",
                data=json.dumps({"jsonrpc": "2.0", "id": 10235, "method": "getHealth"}).encode(),
                headers={"Content-Type": "application/json"},
                method="POST",
                tolerate=True,
            )
            try:
                if json.loads(body).get("result", {}).get("status") == "healthy":
                    break
            except ValueError:
                pass
            if counter % 12 == 0:
                self.log(f"stellar-rpc: waiting for ready state, {counter // 12} minutes...")
            counter += 1
            time.sleep(5)
        self.log("stellar-rpc: up and ready")

    def horizon_status(self):
        counter = 1
        self.log("horizon: waiting for ingestion to catch up...")
        while True:
            body = self.http("http://localhost:8001", tolerate=True)
            try:
                data = json.loads(body)
                if data.get("core_latest_ledger", 0) > 5 and data.get("history_latest_ledger", 0) > 5:
                    break
            except ValueError:
                pass
            if counter % 12 == 0:
                self.log(f"horizon: waiting for ingestion to catch up, {counter // 12} minutes...")
            counter += 1
            time.sleep(5)
        self.log("horizon: ingestion caught up")


def main():
    try:
        Quickstart().main(sys.argv[1:])
    except subprocess.CalledProcessError as exc:
        sys.exit(exc.returncode or 1)


if __name__ == "__main__":
    main()
