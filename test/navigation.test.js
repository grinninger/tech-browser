'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { findStartUrl, normalizeInput } = require('../src/navigation');

test('keeps explicit web URLs', () => {
  assert.equal(normalizeInput('https://example.com/a'), 'https://example.com/a');
  assert.equal(normalizeInput('http://router.local'), 'http://router.local');
});

test('uses HTTP for local device addresses', () => {
  assert.equal(normalizeInput('192.168.1.1'), 'http://192.168.1.1');
  assert.equal(normalizeInput('localhost:8080/status'), 'http://localhost:8080/status');
});

test('uses HTTPS for ordinary hostnames', () => {
  assert.equal(normalizeInput('example.com/path'), 'https://example.com/path');
});

test('turns free text into a search', () => {
  assert.equal(normalizeInput('drucker firmware'), 'https://www.google.com/search?q=drucker%20firmware');
});

test('finds a start URL in process arguments', () => {
  assert.equal(findStartUrl(['app.asar', '--flag', 'https://example.com']), 'https://example.com');
  assert.equal(findStartUrl(['app.asar']), 'about:blank');
});
