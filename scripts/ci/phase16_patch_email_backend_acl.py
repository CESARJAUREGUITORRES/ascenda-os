#!/usr/bin/env python3
"""F16 compatibility patch: legacy Email server data access must be server/service-role only.

The patch is intentionally narrow. Non-Email Supabase calls continue using the historical
server key so unrelated domains do not change semantics. Email table access fails closed
when SUPABASE_SERVICE_ROLE_KEY is absent, which is verified before production canary.
"""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SERVER = ROOT / "app/server.js"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise RuntimeError(f"{label}: expected 1 occurrence, found {n}")
    return text.replace(old, new, 1)


def main() -> int:
    text = SERVER.read_text(encoding="utf-8")
    before = text

    marker = "const VERIFY_TOKEN = 'ascendaos_zivital_2026'\n"
    insert = """const VERIFY_TOKEN = 'ascendaos_zivital_2026'
// F16: Email tables are backend-only. No service-role value is stored in source.
const EMAIL_SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ''
function f16DbKey(endpoint) {
  var e = String(endpoint || '')
  return /^\/rest\/v1\/aos_emails?_/.test(e) ? EMAIL_SB_KEY : SB_KEY
}
function f16RequireEmailBackend(endpoint) {
  if (/^\/rest\/v1\/aos_emails?_/.test(String(endpoint || '')) && !EMAIL_SB_KEY) {
    throw new Error('EMAIL_SERVICE_ROLE_NOT_CONFIGURED')
  }
}
"""
    if "function f16DbKey(endpoint)" not in text:
        text = replace_once(text, marker, insert, "insert Email backend key selector")

    old = """function sbPost(endpoint, body, method) {
  const url = new URL(SB_URL + endpoint)
  const httpMethod = String(method || 'POST').toUpperCase() === 'PATCH' ? 'PATCH' : 'POST'
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body)
    const req = https.request({
      hostname: url.hostname, path: url.pathname + url.search,
      method: httpMethod,
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(data) }
"""
    new = """function sbPost(endpoint, body, method) {
  f16RequireEmailBackend(endpoint)
  const url = new URL(SB_URL + endpoint)
  const httpMethod = String(method || 'POST').toUpperCase() === 'PATCH' ? 'PATCH' : 'POST'
  const dbKey = f16DbKey(endpoint)
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body)
    const req = https.request({
      hostname: url.hostname, path: url.pathname + url.search,
      method: httpMethod,
      headers: { 'apikey': dbKey, 'Authorization': 'Bearer ' + dbKey, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(data) }
"""
    text = replace_once(text, old, new, "sbPost Email key selection")

    old = """function sbGet(endpoint) {
  const url = new URL(SB_URL + endpoint)
  return new Promise(function(resolve, reject) {
    https.get({
      hostname: url.hostname, path: url.pathname + url.search,
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }
"""
    new = """function sbGet(endpoint) {
  try { f16RequireEmailBackend(endpoint) } catch (e) { return Promise.resolve([]) }
  const url = new URL(SB_URL + endpoint)
  const dbKey = f16DbKey(endpoint)
  return new Promise(function(resolve, reject) {
    https.get({
      hostname: url.hostname, path: url.pathname + url.search,
      headers: { 'apikey': dbKey, 'Authorization': 'Bearer ' + dbKey }
"""
    text = replace_once(text, old, new, "sbGet Email key selection")

    old = """function sbPatch(endpoint, body) {
  const url = new URL(SB_URL + endpoint)
  var data = JSON.stringify(body || {})
  return new Promise(function(resolve) {
    var req = https.request({
      hostname: url.hostname, path: url.pathname + url.search, method: 'PATCH',
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), 'Prefer': 'return=minimal' }
"""
    new = """function sbPatch(endpoint, body) {
  try { f16RequireEmailBackend(endpoint) } catch (e) { return Promise.resolve(false) }
  const url = new URL(SB_URL + endpoint)
  const dbKey = f16DbKey(endpoint)
  var data = JSON.stringify(body || {})
  return new Promise(function(resolve) {
    var req = https.request({
      hostname: url.hostname, path: url.pathname + url.search, method: 'PATCH',
      headers: { 'apikey': dbKey, 'Authorization': 'Bearer ' + dbKey, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), 'Prefer': 'return=minimal' }
"""
    text = replace_once(text, old, new, "sbPatch Email key selection")

    old = """function sbFetch(endpoint) {
  return new Promise(function(resolve, reject) {
    var url = new URL(SB_URL + endpoint)
    https.get({
      hostname: url.hostname, path: url.pathname + url.search,
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }
"""
    new = """function sbFetch(endpoint) {
  try { f16RequireEmailBackend(endpoint) } catch (e) { return Promise.reject(e) }
  return new Promise(function(resolve, reject) {
    var url = new URL(SB_URL + endpoint)
    var dbKey = f16DbKey(endpoint)
    https.get({
      hostname: url.hostname, path: url.pathname + url.search,
      headers: { 'apikey': dbKey, 'Authorization': 'Bearer ' + dbKey }
"""
    text = replace_once(text, old, new, "sbFetch Email key selection")

    old = """    var url = new URL(SB_URL + '/rest/v1/aos_email_alertas')
    var req = https.request({ hostname: url.hostname, path: url.pathname, method: 'POST',
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(body) }
"""
    new = """    if (!EMAIL_SB_KEY) return
    var url = new URL(SB_URL + '/rest/v1/aos_email_alertas')
    var req = https.request({ hostname: url.hostname, path: url.pathname, method: 'POST',
      headers: { 'apikey': EMAIL_SB_KEY, 'Authorization': 'Bearer ' + EMAIL_SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(body) }
"""
    text = replace_once(text, old, new, "saveEmailAlerta service-role boundary")

    if text == before:
        raise RuntimeError("no changes applied")
    if "SUPABASE_SERVICE_ROLE_KEY || ''" not in text:
        raise RuntimeError("service-role environment boundary missing")
    if "f16RequireEmailBackend(endpoint)" not in text:
        raise RuntimeError("Email fail-closed boundary missing")

    SERVER.write_text(text, encoding="utf-8")
    print("CIA_PHASE16_EMAIL_BACKEND_ACL_PATCH=PASS")
    print("EMAIL_SERVICE_ROLE_SOURCE_SECRET=0")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"CIA_PHASE16_EMAIL_BACKEND_ACL_PATCH=FAIL:{type(exc).__name__}:{exc}", file=sys.stderr)
        raise
