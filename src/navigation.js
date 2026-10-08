'use strict';

const SEARCH_URL = 'https://www.google.com/search?q=';

function normalizeInput(input) {
  const value = String(input ?? '').trim();
  if (!value) return 'about:blank';

  if (/^(https?|file):\/\//i.test(value) || value === 'about:blank') {
    return value;
  }

  if (/^(localhost|\[[0-9a-f:]+\]|\d{1,3}(?:\.\d{1,3}){3})(:\d+)?(?:\/.*)?$/i.test(value)) {
    return `http://${value}`;
  }

  if (/^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?(?::\d+)?(?:\/.*)?$/i.test(value) && value.includes('.')) {
    return `https://${value}`;
  }

  return `${SEARCH_URL}${encodeURIComponent(value)}`;
}

function findStartUrl(argv) {
  const candidate = argv.find((arg) => /^(https?|file):\/\//i.test(arg) || arg === 'about:blank');
  return candidate || 'about:blank';
}

module.exports = { findStartUrl, normalizeInput };
