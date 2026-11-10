#!/usr/bin/env python3
"""
Support CLI – Teamwork Desk ticket operations.

Commands:
  auth check    Verify credentials (optional API probe)
  scan          List tickets (filterable by inbox, status, days)
  read          Show ticket detail + message threads
  post-note     Post an internal HTML note on a ticket
  update        Update ticket fields (status, agent, priority, tags)
"""

import sys
import json
import re
import html as html_mod
import argparse
import os
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from dataclasses import dataclass

DESK_ENV_KEYS = ("TEAMWORK_DESK_DOMAIN", "TEAMWORK_DESK_API_KEY", "TEAMWORK_DESK_INBOX_ID")
_ENV_SEARCHED: List[str] = []
_ENV_LOADED_FROM: Optional[str] = None


def _parse_env_text(text: str) -> None:
    """Inject DESK_ENV_KEYS into os.environ when not already set."""
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        eq = line.find("=")
        if eq < 1:
            continue
        key = line[:eq].strip()
        if key not in DESK_ENV_KEYS or key in os.environ:
            continue
        val = line[eq + 1 :].strip()
        if val and val[0] in "\"'" and val[0] in val[1:]:
            q = val[0]
            end = val.find(q, 1)
            val = val[1:end] if end > 0 else val[1:]
        os.environ[key] = val


def _try_load_env_file(path: Path) -> bool:
    global _ENV_LOADED_FROM
    _ENV_SEARCHED.append(str(path))
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as e:
        if e.errno not in (2, 21, 20):  # ENOENT, EISDIR, ENOTDIR
            raise
        return False
    before = {k: os.environ.get(k) for k in DESK_ENV_KEYS}
    _parse_env_text(text)
    loaded_any = any(os.environ.get(k) != before.get(k) for k in DESK_ENV_KEYS)
    if loaded_any and _ENV_LOADED_FROM is None:
        _ENV_LOADED_FROM = str(path)
    return loaded_any


def _load_desk_env() -> None:
    """Load TEAMWORK_DESK_* from parent .env files and optional credentials file."""
    global _ENV_LOADED_FROM
    start = Path.cwd().resolve()
    for _ in range(6):
        _try_load_env_file(start / ".env")
        parent = start.parent
        if parent == start:
            break
        start = parent

    creds = Path.home() / ".config" / "teamwork-desk" / "credentials"
    _try_load_env_file(creds)


def _mask_api_key(key: str) -> str:
    if not key:
        return "(vide)"
    if len(key) <= 4:
        return "…" + key
    return "…" + key[-4:]


def _config_error_message() -> str:
    lines = [
        "ERREUR: TEAMWORK_DESK_DOMAIN et TEAMWORK_DESK_API_KEY requis.",
        "",
        "Sources consultées (l’environnement shell prime toujours) :",
    ]
    if _ENV_SEARCHED:
        for p in _ENV_SEARCHED:
            lines.append(f"  - {p}")
    else:
        lines.append("  - (aucun fichier .env / credentials testé)")
    if _ENV_LOADED_FROM:
        lines.append(f"Variables chargées depuis : {_ENV_LOADED_FROM}")
    lines.extend(
        [
            "",
            "Astuce : depuis un monorepo Foldio, exécuter le CLI depuis la racine où se trouve .env",
            "ou créer ~/.config/teamwork-desk/credentials avec TEAMWORK_DESK_DOMAIN=… et TEAMWORK_DESK_API_KEY=…",
        ]
    )
    return "\n".join(lines)


def _http_json(
    url: str,
    method: str,
    headers: Dict[str, str],
    *,
    params: Optional[Dict[str, Any]] = None,
    json_body: Optional[Dict[str, Any]] = None,
    timeout: int = 60,
) -> Dict[str, Any]:
    if params:
        query = urllib.parse.urlencode({k: str(v) for k, v in params.items() if v is not None})
        url = f"{url}?{query}" if query else url
    data: Optional[bytes] = None
    hdrs = dict(headers)
    if json_body is not None:
        data = json.dumps(json_body).encode("utf-8")
        hdrs.setdefault("Content-Type", "application/json")
    req = urllib.request.Request(url, data=data, headers=hdrs, method=method.upper())
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw.strip() else {}
    except urllib.error.HTTPError as e:
        detail = ""
        try:
            detail = e.read().decode("utf-8", errors="replace")[:500]
        except Exception:
            pass
        msg = f"HTTP {e.code} {e.reason}"
        if detail:
            msg += f": {detail}"
        raise RuntimeError(msg) from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"Connexion: {e.reason}") from e


@dataclass
class TeamworkConfig:
    domain: str
    api_key: str


class SupportCLI:
    THREAD_TYPES = {1: "message", 2: "forward", 3: "note", 4: "event"}

    def __init__(self) -> None:
        self.teamwork = self._get_teamwork_config()

    @staticmethod
    def _get_teamwork_config() -> TeamworkConfig:
        domain = os.getenv("TEAMWORK_DESK_DOMAIN")
        api_key = os.getenv("TEAMWORK_DESK_API_KEY")
        if not domain or not api_key:
            print(_config_error_message(), file=sys.stderr)
            sys.exit(1)
        return TeamworkConfig(domain=domain.strip(), api_key=api_key.strip())

    @staticmethod
    def peek_config() -> Tuple[Optional[str], Optional[str]]:
        domain = os.getenv("TEAMWORK_DESK_DOMAIN")
        api_key = os.getenv("TEAMWORK_DESK_API_KEY")
        return (
            domain.strip() if domain else None,
            api_key.strip() if api_key else None,
        )

    # -- helpers -------------------------------------------------------------

    def _url(self, path: str) -> str:
        return f"https://{self.teamwork.domain}/desk/api/v2/{path}"

    def _headers(self, post: bool = False) -> Dict[str, str]:
        h = {"Authorization": f"Bearer {self.teamwork.api_key}"}
        if post:
            h["Content-Type"] = "application/json"
        return h

    @staticmethod
    def _ref_id(ref: object) -> Optional[int]:
        if ref is None:
            return None
        if isinstance(ref, int):
            return ref
        if isinstance(ref, dict):
            return ref.get("id")
        return None

    @staticmethod
    def _truncate(text: str, max_len: int) -> str:
        text = (text or "").replace("\n", " ").strip()
        return text if len(text) <= max_len else text[: max_len - 1] + "…"

    @staticmethod
    def _strip_html(raw: str) -> str:
        text = re.sub(r"<br\s*/?>", "\n", raw or "")
        text = re.sub(r"</p>", "\n", text)
        text = re.sub(r"<li>", "  • ", text)
        text = re.sub(r"<[^>]+>", "", text)
        text = html_mod.unescape(text)
        lines = [l.rstrip() for l in text.splitlines()]
        while lines and not lines[-1]:
            lines.pop()
        return "\n".join(lines)

    @staticmethod
    def _fmt_date(iso: str) -> str:
        if not iso:
            return ""
        return iso.replace("T", " ").replace("Z", "").split("+")[0].split(".")[0]

    # -- lookup maps from included -------------------------------------------

    @staticmethod
    def _build_lookup(included: Optional[Dict[str, Any]]) -> Dict[str, Dict[int, str]]:
        if not included:
            return {}
        maps: Dict[str, Dict[int, str]] = {}
        for c in included.get("customers") or []:
            cid = c.get("id")
            if cid is None:
                continue
            name = f"{c.get('firstName') or ''} {c.get('lastName') or ''}".strip()
            maps.setdefault("customers", {})[int(cid)] = name or c.get("email", "") or str(cid)
        for u in included.get("users") or []:
            uid = u.get("id")
            if uid is None:
                continue
            name = f"{u.get('firstName') or ''} {u.get('lastName') or ''}".strip()
            maps.setdefault("users", {})[int(uid)] = name or u.get("email", "") or str(uid)
        for ib in included.get("inboxes") or []:
            iid = ib.get("id")
            if iid is not None:
                maps.setdefault("inboxes", {})[int(iid)] = ib.get("name") or str(iid)
        for st in included.get("ticketstatuses") or []:
            sid = st.get("id")
            if sid is not None:
                maps.setdefault("statuses", {})[int(sid)] = st.get("name") or str(sid)
        return maps

    # -----------------------------------------------------------------------
    # API: list tickets
    # -----------------------------------------------------------------------

    def list_tickets(
        self,
        inbox_id: Optional[int] = None,
        status_ids: Optional[List[int]] = None,
        days: Optional[int] = 14,
        page_size: int = 50,
    ) -> Optional[Dict[str, Any]]:
        params: Dict[str, Any] = {
            "orderBy": "createdAt",
            "orderMode": "desc",
            "pageSize": min(max(page_size, 1), 100),
            "includes": "inboxes,customers,users,ticketstatuses",
        }
        clauses: List[Dict[str, Any]] = []
        if inbox_id is not None:
            clauses.append({"inbox": {"$eq": inbox_id}})
        if status_ids:
            clauses.append({"status": {"$in": status_ids}} if len(status_ids) > 1 else {"status": {"$eq": status_ids[0]}})
        if days is not None and days > 0:
            cutoff = datetime.now(timezone.utc) - timedelta(days=days)
            clauses.append({"createdAt": {"$gte": cutoff.strftime("%Y-%m-%dT%H:%M:%SZ")}})
        if clauses:
            params["filter"] = json.dumps({"$and": clauses} if len(clauses) > 1 else clauses[0])
        try:
            return _http_json(self._url("tickets.json"), "GET", self._headers(), params=params)
        except Exception as e:
            print(f"Erreur list_tickets: {e}", file=sys.stderr)
            return None

    # -----------------------------------------------------------------------
    # API: get ticket detail (with included)
    # -----------------------------------------------------------------------

    def get_ticket(self, ticket_id: int) -> Optional[Dict[str, Any]]:
        try:
            return _http_json(
                self._url(f"tickets/{ticket_id}.json"),
                "GET",
                self._headers(),
                params={"includes": "customers,inboxes,users,tags,ticketstatuses"},
            )
        except Exception as e:
            print(f"Erreur get_ticket: {e}", file=sys.stderr)
            return None

    # -----------------------------------------------------------------------
    # API: get messages for a ticket
    # -----------------------------------------------------------------------

    def get_messages(self, ticket_id: int, thread_type: Optional[int] = None) -> Optional[Dict[str, Any]]:
        params: Dict[str, Any] = {
            "orderBy": "createdAt",
            "orderMode": "asc",
            "includes": "users,files",
            "pageSize": 100,
        }
        if thread_type is not None:
            params["filter"] = json.dumps({"threadType": thread_type})
        try:
            return _http_json(
                self._url(f"tickets/{ticket_id}/messages.json"),
                "GET",
                self._headers(),
                params=params,
            )
        except Exception as e:
            print(f"Erreur get_messages: {e}", file=sys.stderr)
            return None

    # -----------------------------------------------------------------------
    # API: post note / reply
    # -----------------------------------------------------------------------

    def post_note(self, ticket_id: int, html_body: str) -> Optional[Dict[str, Any]]:
        try:
            return _http_json(
                self._url(f"tickets/{ticket_id}/messages.json"),
                "POST",
                self._headers(post=True),
                json_body={"message": html_body, "threadType": "note"},
            )
        except Exception as e:
            print(f"Erreur post_note: {e}", file=sys.stderr)
            return None

    # -----------------------------------------------------------------------
    # API: update ticket
    # -----------------------------------------------------------------------

    def update_ticket(self, ticket_id: int, **fields: Any) -> Optional[Dict[str, Any]]:
        """PATCH a ticket. Accepted keys: status (int id), agent (int id), priority (str), tags (list of tag ids)."""
        ticket_body: Dict[str, Any] = {}
        if "status" in fields:
            ticket_body["status"] = {"id": int(fields["status"]), "type": "ticketstatuses"}
        if "agent" in fields:
            ticket_body["agent"] = {"id": int(fields["agent"]), "type": "users"}
        if "priority" in fields:
            ticket_body["priority"] = fields["priority"]
        if "tags" in fields:
            ticket_body["tags"] = [{"id": int(t), "type": "tags"} for t in fields["tags"]]
        if not ticket_body:
            print("Rien à mettre à jour.", file=sys.stderr)
            return None
        try:
            return _http_json(
                self._url(f"tickets/{ticket_id}.json"),
                "PATCH",
                self._headers(post=True),
                json_body={"ticket": ticket_body},
            )
        except Exception as e:
            print(f"Erreur update_ticket: {e}", file=sys.stderr)
            return None

    # -----------------------------------------------------------------------
    # Display helpers
    # -----------------------------------------------------------------------

    def print_scan_table(self, payload: Dict[str, Any], limit: Optional[int] = None) -> None:
        tickets = payload.get("tickets") or []
        if limit is not None:
            tickets = tickets[:limit]
        if not tickets:
            print("Aucun ticket trouvé.")
            return
        maps = self._build_lookup(payload.get("included"))
        cust_map = maps.get("customers", {})
        inbox_map = maps.get("inboxes", {})
        status_map = maps.get("statuses", {})

        headers = ("ID", "Sujet", "Statut", "Inbox", "Créé", "Client")
        rows: List[Tuple[str, ...]] = []
        for t in tickets:
            tid = str(t.get("id", ""))
            subj = self._truncate(str(t.get("subject") or ""), 52)
            st_id = self._ref_id(t.get("status"))
            status = status_map.get(int(st_id), t.get("state", "")) if st_id is not None else t.get("state", "")
            ib_id = self._ref_id(t.get("inbox"))
            inbox = inbox_map.get(int(ib_id), str(ib_id or "")) if ib_id is not None else ""
            created = self._fmt_date(str(t.get("createdAt") or ""))[:10]
            cu_id = self._ref_id(t.get("customer"))
            client = cust_map.get(int(cu_id), "") if cu_id is not None else ""
            rows.append((tid, subj, status, inbox, created, client))

        widths = [max(len(headers[i]), *(len(r[i]) for r in rows)) for i in range(len(headers))]
        sep = "  "
        fmt = lambda cells: sep.join(c.ljust(widths[i]) for i, c in enumerate(cells))
        print(fmt(headers))
        print(sep.join("-" * w for w in widths))
        for r in rows:
            print(fmt(r))

    def print_ticket_detail(self, payload: Dict[str, Any]) -> None:
        ticket = payload.get("ticket", {})
        maps = self._build_lookup(payload.get("included"))
        cust_map = maps.get("customers", {})
        status_map = maps.get("statuses", {})
        inbox_map = maps.get("inboxes", {})
        user_map = maps.get("users", {})

        st_id = self._ref_id(ticket.get("status"))
        status = status_map.get(int(st_id), ticket.get("state", "")) if st_id is not None else ticket.get("state", "")
        ib_id = self._ref_id(ticket.get("inbox"))
        inbox = inbox_map.get(int(ib_id), str(ib_id or "")) if ib_id is not None else ""
        cu_id = self._ref_id(ticket.get("customer"))
        customer = cust_map.get(int(cu_id), "") if cu_id is not None else ""
        ag_id = self._ref_id(ticket.get("agent"))
        agent = user_map.get(int(ag_id), "non assigné") if ag_id is not None else "non assigné"

        print(f"{'=' * 72}")
        print(f"Ticket #{ticket.get('id')}  —  {ticket.get('subject', '')}")
        print(f"{'=' * 72}")
        print(f"  Statut    : {status}")
        print(f"  Inbox     : {inbox}")
        print(f"  Client    : {customer}")
        print(f"  Agent     : {agent}")
        print(f"  Créé      : {self._fmt_date(ticket.get('createdAt', ''))}")
        print(f"  Mis à jour: {self._fmt_date(ticket.get('updatedAt', ''))}")
        print(f"  Source    : {ticket.get('source', '')}")
        print(f"  Messages  : {ticket.get('messageCount', '?')}")
        preview = self._truncate(ticket.get("previewText", ""), 200)
        if preview:
            print(f"\n  Aperçu: {preview}")
        print()

    def print_messages(self, payload: Dict[str, Any], max_body: int = 600) -> None:
        messages = payload.get("messages") or payload.get("threads") or []
        if not messages:
            print("Aucun message.")
            return
        maps = self._build_lookup(payload.get("included"))
        user_map = maps.get("users", {})

        for i, m in enumerate(messages):
            tt = m.get("threadType")
            if isinstance(tt, dict):
                tt = tt.get("id", tt)
            type_label = self.THREAD_TYPES.get(tt, str(tt))
            author_id = self._ref_id(m.get("createdBy") or m.get("author"))
            author = user_map.get(int(author_id), "?") if author_id is not None else "?"
            date = self._fmt_date(m.get("createdAt", ""))
            body_raw = m.get("body") or m.get("message") or m.get("htmlBody") or ""
            body = self._strip_html(body_raw)
            if len(body) > max_body:
                body = body[:max_body] + "\n  …[tronqué]"

            print(f"--- [{type_label}] #{i + 1}  |  {author}  |  {date} ---")
            if body.strip():
                for line in body.splitlines():
                    print(f"  {line}")
            print()


def _run_auth_check(probe: bool) -> int:
    domain, api_key = SupportCLI.peek_config()
    ok = bool(domain and api_key)
    print("Teamwork Desk — auth check")
    print(f"  domain   : {domain or '(manquant)'}")
    print(f"  api_key  : {_mask_api_key(api_key or '')}")
    inbox = os.getenv("TEAMWORK_DESK_INBOX_ID")
    if inbox:
        print(f"  inbox_id : {inbox} (défaut scan)")
    if _ENV_LOADED_FROM:
        print(f"  chargé   : {_ENV_LOADED_FROM}")
    elif _ENV_SEARCHED:
        print("  chargé   : (uniquement variables shell — aucun fichier n’a fourni de clés)")
    if not ok:
        print(_config_error_message(), file=sys.stderr)
        return 2
    if not probe:
        print("  statut   : OK (config présente)")
        return 0
    cli = SupportCLI()
    payload = cli.list_tickets(days=None, page_size=1)
    if payload is None:
        print("  statut   : ÉCHEC (appel API tickets)", file=sys.stderr)
        return 1
    print("  statut   : OK (API joignable)")
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

STATUS_NAMES = {"active": 1, "waiting": 3, "on-hold": 4, "solved": 5, "closed": 6, "spam": 7}


def _parse_status_list(raw: str) -> List[int]:
    result = []
    for token in raw.split(","):
        token = token.strip().lower()
        if token.isdigit():
            result.append(int(token))
        elif token in STATUS_NAMES:
            result.append(STATUS_NAMES[token])
        else:
            print(f"Statut inconnu: {token}  (valides: {', '.join(STATUS_NAMES.keys())})", file=sys.stderr)
            sys.exit(1)
    return result


def main():
    _load_desk_env()

    parser = argparse.ArgumentParser(
        description="Support CLI – Teamwork Desk ticket operations",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Status names: active(1), waiting(3), on-hold(4), solved(5), closed(6), spam(7)",
    )
    sub = parser.add_subparsers(dest="command")

    # -- auth ----------------------------------------------------------------
    p_auth = sub.add_parser("auth", help="Authentication / configuration")
    auth_sub = p_auth.add_subparsers(dest="auth_command")
    p_check = auth_sub.add_parser("check", help="Verify domain + API key (exit 0 = OK)")
    p_check.add_argument("--probe", action="store_true", help="Call tickets API to validate the token")

    # -- scan ----------------------------------------------------------------
    p_scan = sub.add_parser("scan", help="List tickets")
    p_scan.add_argument("--inbox-id", type=int, help="Inbox ID filter")
    p_scan.add_argument("--status", type=str, help="Status filter: name or id, comma-separated (e.g. active,waiting)")
    p_scan.add_argument("--days", type=int, default=14, help="Created within N days (0=no date filter)")
    p_scan.add_argument("--page-size", type=int, default=50, help="Results per page (1-100)")
    p_scan.add_argument("--limit", type=int, default=None, help="Max rows to display")

    # -- read ----------------------------------------------------------------
    p_read = sub.add_parser("read", help="Show ticket detail + messages")
    p_read.add_argument("ticket_id", type=int, help="Ticket ID")
    p_read.add_argument("--notes-only", action="store_true", help="Show only internal notes")
    p_read.add_argument("--no-messages", action="store_true", help="Skip messages, show only ticket header")
    p_read.add_argument("--max-body", type=int, default=600, help="Max chars per message body")

    # -- post-note -----------------------------------------------------------
    p_note = sub.add_parser("post-note", help="Post an internal note (HTML)")
    p_note.add_argument("ticket_id", type=int, help="Ticket ID")
    p_note.add_argument("--body", type=str, help="HTML body (or reads stdin if omitted)")

    # -- update --------------------------------------------------------------
    p_upd = sub.add_parser("update", help="Update ticket fields")
    p_upd.add_argument("ticket_id", type=int, help="Ticket ID")
    p_upd.add_argument("--status", type=str, help="New status (name or id)")
    p_upd.add_argument("--agent", type=int, help="Assign agent (user id)")
    p_upd.add_argument("--priority", type=str, help="Priority value")
    p_upd.add_argument("--tags", type=str, help="Comma-separated tag IDs")

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        return

    if args.command == "auth":
        if args.auth_command == "check":
            sys.exit(_run_auth_check(args.probe))
        p_auth.print_help()
        sys.exit(1)

    cli = SupportCLI()

    # -- scan ----------------------------------------------------------------
    if args.command == "scan":
        status_ids = _parse_status_list(args.status) if args.status else None
        days = args.days if args.days > 0 else None
        inbox_id = args.inbox_id
        if inbox_id is None:
            env_inbox = os.getenv("TEAMWORK_DESK_INBOX_ID")
            if env_inbox and env_inbox.strip().isdigit():
                inbox_id = int(env_inbox.strip())
        payload = cli.list_tickets(inbox_id, status_ids=status_ids, days=days, page_size=args.page_size)
        if not payload:
            sys.exit(1)
        tickets = payload.get("tickets") or []
        pag = (payload.get("included") or {}).get("pagination") or {}
        total = pag.get("records")
        info = f"{len(tickets)} ticket(s)"
        if total is not None:
            info += f" / {total} total"
            pages = pag.get("pages")
            if pages is not None:
                info += f" (page {pag.get('page', 1)}/{pages})"
        print(info + "\n")
        cli.print_scan_table(payload, limit=args.limit)

    # -- read ----------------------------------------------------------------
    elif args.command == "read":
        ticket_payload = cli.get_ticket(args.ticket_id)
        if not ticket_payload:
            sys.exit(1)
        cli.print_ticket_detail(ticket_payload)
        if not args.no_messages:
            thread_filter = 3 if args.notes_only else None
            msg_payload = cli.get_messages(args.ticket_id, thread_type=thread_filter)
            if msg_payload:
                cli.print_messages(msg_payload, max_body=args.max_body)

    # -- post-note -----------------------------------------------------------
    elif args.command == "post-note":
        body = args.body
        if not body:
            if sys.stdin.isatty():
                print("Entrez le HTML de la note (Ctrl-D pour terminer):", file=sys.stderr)
            body = sys.stdin.read().strip()
        if not body:
            print("Corps de la note vide, abandon.", file=sys.stderr)
            sys.exit(1)
        result = cli.post_note(args.ticket_id, body)
        if result:
            msg = (result.get("thread") or result.get("message") or {})
            print(f"Note créée (id={msg.get('id', '?')}) sur ticket {args.ticket_id}")
        else:
            sys.exit(1)

    # -- update --------------------------------------------------------------
    elif args.command == "update":
        fields: Dict[str, Any] = {}
        if args.status:
            parsed = _parse_status_list(args.status)
            fields["status"] = parsed[0]
        if args.agent:
            fields["agent"] = args.agent
        if args.priority:
            fields["priority"] = args.priority
        if args.tags:
            fields["tags"] = [int(t.strip()) for t in args.tags.split(",")]
        if not fields:
            print("Aucun champ à modifier. Utilisez --status, --agent, --priority, --tags", file=sys.stderr)
            sys.exit(1)
        result = cli.update_ticket(args.ticket_id, **fields)
        if result:
            print(f"Ticket {args.ticket_id} mis à jour: {', '.join(fields.keys())}")
        else:
            sys.exit(1)


if __name__ == "__main__":
    main()
