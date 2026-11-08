"""Проверка Android DNS Bridge без телефона, ADB, DNS-запросов и записи в /etc."""
import base64
import importlib.util
import json
from pathlib import Path
import tempfile
import sys
import time
import unittest
from unittest.mock import patch

path = Path(__file__).resolve().parents[1] / "nix/launcher/dns-bridge/android_dns.py"
spec = importlib.util.spec_from_file_location("android_dns", path)
dns = importlib.util.module_from_spec(spec)
sys.dont_write_bytecode = True
spec.loader.exec_module(dns)


def snapshot(**values):
    return {"version": 1, "captured_at_ms": int(time.time() * 1000), "connected": True,
            "private_dns_active": False, "dns_servers": ["10.0.0.53", "2001:db8::53"],
            "domains": "corp.example,svc.example", **values}


def response(data):
    encoded = base64.b64encode(json.dumps(data).encode()).decode()
    return 'Broadcast completed: result=0, data="ANDROID_DNS_V1:' + encoded + '"'


class AndroidDnsChecks(unittest.TestCase):
    def test_decode_broadcast(self):
        self.assertEqual(dns.decode_response(response(snapshot()))["dns_servers"][0], "10.0.0.53")

    def test_bad_or_missing_responses(self):
        for text in ('Broadcast completed: result=-1', response([]), response(snapshot(version=2)),
                     response(snapshot(captured_at_ms=0)), response(snapshot(captured_at_ms=float("nan")))):
            with self.subTest(text=text), self.assertRaises(ValueError):
                dns.decode_response(text)

    def test_render_network_and_domains(self):
        text, warning = dns.render(snapshot())
        self.assertIsNone(warning)
        self.assertIn("search corp.example svc.example\n", text)
        self.assertIn("nameserver 10.0.0.53\nnameserver 2001:db8::53\n", text)
        self.assertNotIn("8.8.8.8", text)

    def test_vpn_dns_and_ipv6_scope(self):
        text, warning = dns.render(snapshot(vpn=True, dns_servers=["172.20.0.53", "fe80::1%tun0"]))
        self.assertIsNone(warning)
        self.assertIn("nameserver 172.20.0.53", text)
        self.assertIn("nameserver fe80::1%tun0", text)

    def test_invalid_addresses_and_injection(self):
        for addresses in ([], ["8.8.8.8\nsearch attacker"], ["0.0.0.0"], ["ff02::1"], ["bad"], [17]):
            with self.subTest(addresses=addresses), self.assertRaises(ValueError):
                dns.render(snapshot(dns_servers=addresses))

    def test_search_validation(self):
        for domains in (17, "a/../../etc", "-bad.example"):
            with self.subTest(domains=domains), self.assertRaises(ValueError):
                dns.render(snapshot(domains=domains))

    def test_offline_and_private_dns_block_external_dns(self):
        for data in (snapshot(connected=False), snapshot(private_dns_active=True)):
            text, warning = dns.render(data)
            self.assertEqual(text, dns.BLOCKED)
            self.assertIsNotNone(warning)
            self.assertNotIn("10.0.0.53", text)

    def test_deduplicate_and_limit_servers(self):
        text, _ = dns.render(snapshot(dns_servers=["10.0.0.1", "10.0.0.1", "10.0.0.2", "10.0.0.3", "10.0.0.4"]))
        self.assertEqual(text.count("nameserver "), 3)
        self.assertNotIn("10.0.0.4", text)

    def test_atomic_write_idempotence_and_no_symlinks(self):
        with tempfile.TemporaryDirectory(prefix="dns-test-") as directory:
            target = Path(directory) / "resolv.conf"
            dns.write_config(target, "nameserver 10.0.0.53\n")
            before = target.stat().st_ino
            dns.write_config(target, target.read_text())
            self.assertEqual(target.stat().st_ino, before)
            dns.write_config(target, "nameserver 10.0.0.54\n")
            self.assertEqual(target.read_text(), "nameserver 10.0.0.54\n")
            alias = Path(directory) / "link"
            alias.symlink_to(target)
            with self.assertRaises(ValueError):
                dns.write_config(alias, "bad")
            self.assertEqual(target.read_text(), "nameserver 10.0.0.54\n")

    def test_watch_mode_is_not_available(self):
        with patch.object(dns.sys, "argv", ["android-dns", "--watch"]), patch.object(dns.sys, "stderr"):
            with self.assertRaises(SystemExit) as result:
                dns.main()
            self.assertEqual(result.exception.code, 2)

    def test_query_uses_explicit_component_without_shell(self):
        with patch.object(dns.subprocess, "run") as run:
            run.return_value.stdout = response(snapshot())
            self.assertTrue(dns.query()["connected"])
            argv = run.call_args.args[0]
            self.assertIn(dns.COMPONENT, argv)
            self.assertNotIn("shell", run.call_args.kwargs)
            self.assertEqual(argv[0], "am")


if __name__ == "__main__":
    unittest.main()
